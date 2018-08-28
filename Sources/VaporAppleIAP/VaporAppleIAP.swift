import NIO
import HTTP

fileprivate let onDemandSharedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

public final class VaporAppleIAP {
    enum Environment: String {
        case Production = "Production"
        case Sandbox = "Sandbox"
    }
    static let UrlSandbox = URL(string: "https://sandbox.itunes.apple.com/verifyReceipt")!
    static let UrlProduction = URL(string: "https://buy.itunes.apple.com/verifyReceipt")!

    var url: URL {
        get {
            switch self.environment {
            case .Sandbox:
                return type(of: self).UrlSandbox
            case .Production:
                return type(of: self).UrlProduction
            }
        }
    }


    var retryCount: Int = 0
    let retryCountMax: Int = 10
    var retryCountWhenNIONetworkError: Int = 0
    let retryCountMaxWhenNIONetworkError: Int = 10
    var retryCountWhenNIOUnknownError: Int = 0
    let retryCountMaxWhenNIOUnknownError: Int = 10


    let eventLoopGroup: EventLoopGroup
    let password: String
    var environment = Environment.Production

    public init(eventLoopGroup: EventLoopGroup? = nil, password: String = "") {
        self.eventLoopGroup = eventLoopGroup
            ?? MultiThreadedEventLoopGroup.currentEventLoop
            ?? onDemandSharedEventLoopGroup

        self.password = password
    }

    public func fetch(receiptStr: String) throws -> Future<AppleIAPReceipt> {
        return try self.request(receiptStr: receiptStr).flatMap { res in
            let resStatusCode = res.status.code
            let resBodyData = res.body.data ?? Data()

            let receipt = AppleIAPReceipt.make(
                resStatusCode: resStatusCode,
                resBodyData: resBodyData,
                environmentReqStr: self.environment.rawValue,
                receiptReqStr: receiptStr
            )

            switch receipt.status {
            case 21007:
                self.environment = .Sandbox
                return try self.fetch(receiptStr: receiptStr)
            case 21008:
                self.environment = .Production
                return try self.fetch(receiptStr: receiptStr)
            case 21100...21199:
                self.retryCount += 1
                return try self.fetch(receiptStr: receiptStr)
            default:
                // Nothing
                break
            }

            return Future.map(on: self.eventLoopGroup){ receipt }
        }
    }



    struct MockResponseBody: Codable {
        enum Status: Int {
            case RetryReachMaxError = 81
            case NIONetworkError = 82
            case NIOUnknownError = 83
        }

        let status: Int
        let latest_receipt: String
    }

    func request(receiptStr: String) throws -> Future<HTTPResponse> {
        let hostname = self.url.host!
        let port = self.url.port ?? 443

        guard self.retryCount < self.retryCountMax else {
            return Future.map(on: self.eventLoopGroup){
                let mockResponseBody = MockResponseBody(status: MockResponseBody.Status.RetryReachMaxError.rawValue, latest_receipt: receiptStr)
                return HTTPResponse(
                    status: HTTPResponseStatus(statusCode: 481, reasonPhrase: "retry reach max"),
                    body: HTTPBody(data: try! JSONEncoder().encode(mockResponseBody))
                )
            }
        }

        return HTTPClient.connect(scheme: .https, hostname: hostname, port: port, on: self.eventLoopGroup).flatMap { client in
            var requestBodyDict = [String:String]()
            requestBodyDict["password"] = self.password
            requestBodyDict["receipt-data"] = receiptStr
            let requestBodyData = try JSONSerialization.data(withJSONObject: requestBodyDict, options: .prettyPrinted)

            var req = HTTPRequest(method: .POST, url: self.url, body: HTTPBody(data: requestBodyData))
            req.headers.replaceOrAdd(name: .host, value: hostname)
            req.headers.replaceOrAdd(name: .userAgent, value: "vapor/engine")
            req.headers.replaceOrAdd(name: .accept, value: "application/json")
            req.headers.replaceOrAdd(name: .contentType, value: "application/json")
            return client.send(req).always {
                client.close().do { _ in
                }.catch{ error in
                }
            }
            }.catchFlatMap { error in
                switch error {
                case is ChannelError:
                    guard self.retryCountWhenNIONetworkError < self.retryCountMaxWhenNIONetworkError else {
                        return Future.map(on: self.eventLoopGroup){
                            let mockResponseBody = MockResponseBody(status: MockResponseBody.Status.NIONetworkError.rawValue, latest_receipt: receiptStr)
                            return HTTPResponse(
                                status: HTTPResponseStatus(statusCode: 482, reasonPhrase: "\(error)"),
                                body: HTTPBody(data: try! JSONEncoder().encode(mockResponseBody))
                            )
                        }
                    }

                    self.retryCountWhenNIONetworkError += 1
                    return try self.request(receiptStr: receiptStr)
                default:
                    guard self.retryCountWhenNIOUnknownError < self.retryCountMaxWhenNIOUnknownError else {
                        return Future.map(on: self.eventLoopGroup){
                            let mockResponseBody = MockResponseBody(status: MockResponseBody.Status.NIOUnknownError.rawValue, latest_receipt: receiptStr)
                            return HTTPResponse(
                                status: HTTPResponseStatus(statusCode: 483, reasonPhrase: "\(error)"),
                                body: HTTPBody(data: try! JSONEncoder().encode(mockResponseBody))
                            )
                        }
                    }
                    self.retryCountWhenNIOUnknownError += 1
                    return try self.request(receiptStr: receiptStr)
                }
        }
    }
}

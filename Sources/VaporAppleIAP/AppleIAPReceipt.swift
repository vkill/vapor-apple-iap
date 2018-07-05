import struct Foundation.Date
import struct Foundation.TimeInterval
import struct Foundation.Data
import class Foundation.JSONDecoder

public struct AppleIAPReceiptForVerifyStatus: Codable {
    let status: Int
}

enum AppleIAPReceiptErrorCode: Int {
    case ResStatusCodeInvalid = 91
    case ResBodyDataEmpty = 92

    case ResBodyDataInvalidForVerifyStatus = 93
    case StatusInvalid = 94
    case ResBodyDataInvalidForVerifyAll = 95
}

public struct AppleIAPReceipt: Codable {
    public let status: Int

    public let environment: String
    public var environmentInt: Int {
        get {
            switch self.environment {
            case "Production":
                return 1
            case "Sandbox":
                return 2
            default:
                return 0
            }
        }
    }

    public struct ReceiptInfo: Codable {
        public let quantity: Int

        public let product_id: String

        public let transaction_id: String
        public let original_transaction_id: String

        public let purchase_date_ms: Int
        public let original_purchase_date_ms: Int
        public let expires_date_ms: Int

        public let web_order_line_item_id: Int

        public let is_trial_period: Int

        public var cancellation_date_ms: Int
        public var cancellation_reason: String

        public var purchase_date: Date {
            get {
                return Date(timeIntervalSince1970: TimeInterval(purchase_date_ms / 1000))
            }
        }

        public var original_purchase_date: Date {
            get {
                return Date(timeIntervalSince1970: TimeInterval(original_purchase_date_ms / 1000))
            }
        }

        public var expires_date: Date {
            get {
                return Date(timeIntervalSince1970: TimeInterval(expires_date_ms / 1000))
            }
        }

        public var cancellation_date: Date {
            get {
                return Date(timeIntervalSince1970: TimeInterval(cancellation_date_ms / 1000))
            }
        }

        public var is_cancelled: Bool {
            get {
                return cancellation_date_ms != 0
            }
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            self.quantity = try Int(values.decode(String.self, forKey: .quantity))!

            self.product_id = try values.decode(String.self, forKey: .product_id)

            self.transaction_id = try values.decode(String.self, forKey: .transaction_id)
            self.original_transaction_id = try values.decode(String.self, forKey: .original_transaction_id)

            self.purchase_date_ms = try Int(values.decode(String.self, forKey: .purchase_date_ms))!
            self.original_purchase_date_ms = try Int(values.decode(String.self, forKey: .original_purchase_date_ms))!
            self.expires_date_ms = try Int(values.decode(String.self, forKey: .expires_date_ms))!

            if let web_order_line_item_id = try values.decodeIfPresent(String.self, forKey: .web_order_line_item_id) {
                self.web_order_line_item_id = Int(web_order_line_item_id)!
            } else {
                self.web_order_line_item_id = 0
            }

            if let is_trial_period = try values.decodeIfPresent(String.self, forKey: .is_trial_period) {
                self.is_trial_period = Bool(is_trial_period)! ? 1 : 0
            } else {
                self.is_trial_period = 9
            }

            self.cancellation_date_ms = try Int(values.decodeIfPresent(String.self, forKey: .cancellation_date_ms) ?? "0")!
            self.cancellation_reason = try values.decodeIfPresent(String.self, forKey: .cancellation_reason) ?? ""
        }

        public init(
            quantity: Int,
            product_id: String,
            transaction_id: String,
            original_transaction_id: String,
            purchase_date_ms: Int,
            original_purchase_date_ms: Int,
            expires_date_ms: Int,
            web_order_line_item_id: Int = 0,
            is_trial_period: Int,
            cancellation_date_ms: Int = 0,
            cancellation_reason: String = ""
        ) {
            self.quantity = quantity
            self.product_id = product_id
            self.transaction_id = transaction_id
            self.original_transaction_id = original_transaction_id
            self.purchase_date_ms = purchase_date_ms
            self.original_purchase_date_ms = original_purchase_date_ms
            self.expires_date_ms = expires_date_ms
            self.web_order_line_item_id = web_order_line_item_id
            self.is_trial_period = is_trial_period
            self.cancellation_date_ms = cancellation_date_ms
            self.cancellation_reason = cancellation_reason
        }
    }

    public var receipt: Receipt
    // https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html
    public struct Receipt: Codable {
        // NOTE: The receipt_type is ProductionSandbox when from production to sandbox
        public let receipt_type: String

        public let app_item_id: Int
        public let bundle_id: String
        public let application_version: String
        public let download_id: Int

        public let receipt_creation_date_ms: Int
        public let request_date_ms: Int

        public var in_app: [AppleIAPReceipt.ReceiptInfo]

        public var receipt_creation_date: Date {
            get {
                return Date(timeIntervalSince1970: TimeInterval(receipt_creation_date_ms / 1000))
            }
        }
        public var request_date: Date {
            get {
                return Date(timeIntervalSince1970: TimeInterval(request_date_ms / 1000))
            }
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            self.receipt_type = try values.decode(String.self, forKey: .receipt_type)

            self.app_item_id = try values.decode(Int.self, forKey: .app_item_id)
            self.bundle_id = try values.decode(String.self, forKey: .bundle_id)
            self.application_version = try values.decode(String.self, forKey: .application_version)
            self.download_id = try values.decode(Int.self, forKey: .download_id)

            self.receipt_creation_date_ms = try Int(values.decode(String.self, forKey: .receipt_creation_date_ms))!
            self.request_date_ms = try Int(values.decode(String.self, forKey: .request_date_ms))!

            self.in_app = try values.decodeIfPresent([AppleIAPReceipt.ReceiptInfo].self, forKey: .in_app) ?? []
        }

        public init(receipt_type: String, app_item_id: Int, bundle_id: String, application_version: String, download_id: Int, receipt_creation_date_ms: Int, request_date_ms: Int) {
            self.receipt_type = receipt_type
            self.app_item_id = app_item_id
            self.bundle_id = bundle_id
            self.application_version = application_version
            self.download_id = download_id
            self.receipt_creation_date_ms = receipt_creation_date_ms
            self.request_date_ms = request_date_ms
            self.in_app = []
        }
    }

    // NOTE: The reponse latest_receipt not eq request receipt-data
    public var latest_receipt: String
    public var latest_receipt_info: [AppleIAPReceipt.ReceiptInfo]

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        self.status = try values.decode(Int.self, forKey: .status)
        self.environment = try values.decode(String.self, forKey: .environment)

        self.receipt = try values.decode(Receipt.self, forKey: .receipt)

        self.latest_receipt = try values.decodeIfPresent(String.self, forKey: .latest_receipt) ?? ""
        self.latest_receipt_info = try values.decodeIfPresent([AppleIAPReceipt.ReceiptInfo].self, forKey: .latest_receipt_info) ?? []
    }

    public init(_ status: Int, _ environment: String, _ latest_receipt: String) {
        self.status = status
        self.environment = environment
        self.latest_receipt = latest_receipt

        self.receipt = Receipt(receipt_type: environment, app_item_id: 0, bundle_id: "", application_version: "", download_id: 0, receipt_creation_date_ms: 0, request_date_ms: 0)

        self.latest_receipt = ""
        self.latest_receipt_info = []
    }

    static func make(resStatusCode: UInt, resBodyData: Data, environmentReqStr: String, receiptReqStr: String) -> AppleIAPReceipt {
        let _environment = environmentReqStr
        let _latest_receipt = receiptReqStr

        guard resStatusCode == 200 else {
            return AppleIAPReceipt(AppleIAPReceiptErrorCode.ResStatusCodeInvalid.rawValue, _environment, _latest_receipt)
        }

        guard !resBodyData.isEmpty else {
            return AppleIAPReceipt(AppleIAPReceiptErrorCode.ResBodyDataEmpty.rawValue, _environment, _latest_receipt)
        }

        let jsonDecoder = JSONDecoder()

        let receiptForVerifyStatus: AppleIAPReceiptForVerifyStatus
        do {
            receiptForVerifyStatus = try jsonDecoder.decode(AppleIAPReceiptForVerifyStatus.self, from: resBodyData)
        } catch {
            return AppleIAPReceipt(AppleIAPReceiptErrorCode.ResBodyDataInvalidForVerifyStatus.rawValue, _environment, _latest_receipt)
        }

        let status = receiptForVerifyStatus.status
        // https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateRemotely.html
        switch status {
        case 0:
            // Nothing
            break
        case 21000:
            return AppleIAPReceipt(status, _environment, _latest_receipt)
        case 21002:
            return AppleIAPReceipt(status, _environment, _latest_receipt)
        case 21003:
            return AppleIAPReceipt(status, _environment, _latest_receipt)
        case 21004:
            return AppleIAPReceipt(status, _environment, _latest_receipt)
        case 21005:
            return AppleIAPReceipt(status, _environment, _latest_receipt)
        case 21006:
            return AppleIAPReceipt(status, _environment, _latest_receipt)
        case 21007:
            return AppleIAPReceipt(status, _environment, _latest_receipt)
        case 21008:
            return AppleIAPReceipt(status, _environment, _latest_receipt)
        case 210010:
            return AppleIAPReceipt(status, _environment, _latest_receipt)
        case 21100...21199:
            return AppleIAPReceipt(status, _environment, _latest_receipt)
        default:
            return AppleIAPReceipt(AppleIAPReceiptErrorCode.StatusInvalid.rawValue, _environment, _latest_receipt)
        }

        var receipt: AppleIAPReceipt
        do {
            receipt = try jsonDecoder.decode(AppleIAPReceipt.self, from: resBodyData)
        } catch {
            return AppleIAPReceipt(AppleIAPReceiptErrorCode.ResBodyDataInvalidForVerifyAll.rawValue, _environment, _latest_receipt)
        }

        //
        if receipt.latest_receipt.isEmpty {
            receipt.latest_receipt = _latest_receipt
        }

        return receipt
    }

    public func result() -> (isValid: Bool, isExpired: Bool, expiredTS: Int, hasFreeTrial: Bool) {
        var isValid = false
        var isExpired = true
        var expiredTS = 0
        var hasFreeTrial = false

        guard status == 0 else {
            return (isValid, isExpired, expiredTS, hasFreeTrial)
        }
        isValid = true

        let now = Date()

        for receiptInfo in latest_receipt_info {
            let beginDate = receiptInfo.purchase_date
            let endDate = receiptInfo.is_cancelled ? receiptInfo.cancellation_date : receiptInfo.expires_date

            if beginDate <= now && now > endDate {
                isExpired = false
                expiredTS = Int(endDate.timeIntervalSince1970)
            }

            if receiptInfo.is_trial_period == 1 {
                hasFreeTrial = true
            }
        }

        return (isValid, isExpired, expiredTS, hasFreeTrial)
    }
}

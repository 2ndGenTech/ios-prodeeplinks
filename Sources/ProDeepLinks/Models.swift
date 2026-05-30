import Foundation

// MARK: - Configuration

public struct InitConfig: Sendable {
    public let licenseKey: String
    public let apiBaseUrl: String?
    public let apiPrefix: String?
    public let domain: String?

    public init(
        licenseKey: String,
        apiBaseUrl: String? = nil,
        apiPrefix: String? = nil,
        domain: String? = nil
    ) {
        self.licenseKey = licenseKey
        self.apiBaseUrl = apiBaseUrl
        self.apiPrefix = apiPrefix
        self.domain = domain
    }
}

// MARK: - Responses

public struct InitResult: Sendable {
    public let success: Bool
    public let error: String?

    public init(success: Bool, error: String? = nil) {
        self.success = success
        self.error = error
    }
}

public struct DeepLinkResponse: Sendable {
    public let success: Bool
    public let url: String?
    public let message: String?
    public let error: String?

    public init(success: Bool, url: String? = nil, message: String? = nil, error: String? = nil) {
        self.success = success
        self.url = url
        self.message = message
        self.error = error
    }
}

public struct LicenseValidationResult: Sendable {
    public let isValid: Bool
    public let message: String?

    public init(isValid: Bool, message: String? = nil) {
        self.isValid = isValid
        self.message = message
    }
}

// MARK: - Device Fingerprint

public struct DeviceFingerprint: Sendable, Codable {
    public let platform: String
    public let osVersion: String
    public let deviceId: String
    public let deviceModel: String
    public let manufacturer: String?
    public let screenResolution: String
    public let screenWidth: Double
    public let screenHeight: Double
    public let timezone: String?
    public let language: String?
    public let locale: String?
    public let appVersion: String
    public let carrier: String?
    public let connectionType: String?
    public let isSimulator: Bool?
    public let isRooted: Bool?
    public let ipAddress: String?
}

// MARK: - API Payloads

struct FingerprintBasicPayload: Codable {
    let userAgent: String
    let language: String
    let platform: String
    let screenResolution: String
    let timezone: String
    let timezoneOffset: Int
}

struct FingerprintNetworkPayload: Codable {
    let ipAddress: String
    let connectionType: String
}

struct FingerprintDevicePayload: Codable {
    let deviceModel: String
    let osVersion: String
    let appVersion: String
}

struct FingerprintMatchPayload: Codable {
    let basic: FingerprintBasicPayload
    let network: FingerprintNetworkPayload
    let device: FingerprintDevicePayload
    let userId: String?
}

public struct CustomDeepLinkAnalyticsEvent: Codable, Sendable {
    public var eventType: String
    public var eventName: String
    public var category: String?
    public var action: String?
    public var label: String?
    public var value: Double?
    public var properties: [String: AnyCodable]?
    public var sessionId: String?
    public var userId: String?
    public var pageUrl: String?
    public var pageTitle: String?

    public init(
        eventType: String,
        eventName: String,
        category: String? = nil,
        action: String? = nil,
        label: String? = nil,
        value: Double? = nil,
        properties: [String: AnyCodable]? = nil,
        sessionId: String? = nil,
        userId: String? = nil,
        pageUrl: String? = nil,
        pageTitle: String? = nil
    ) {
        self.eventType = eventType
        self.eventName = eventName
        self.category = category
        self.action = action
        self.label = label
        self.value = value
        self.properties = properties
        self.sessionId = sessionId
        self.userId = userId
        self.pageUrl = pageUrl
        self.pageTitle = pageTitle
    }
}

// MARK: - API Responses

struct LicenseValidationAPIResponse: Decodable {
    let success: Bool?
    let valid: Bool?
    let message: String?
    let error: String?
}

struct FingerprintMatchResponse: Decodable {
    let matched: Bool?
    let matchConfidence: Double?
    let url: String?
    let message: String?
    let error: String?

    init(
        matched: Bool? = nil,
        matchConfidence: Double? = nil,
        url: String? = nil,
        message: String? = nil,
        error: String? = nil
    ) {
        self.matched = matched
        self.matchConfidence = matchConfidence
        self.url = url
        self.message = message
        self.error = error
    }
}

struct AnalyticsAPIResponse: Decodable {
    let success: Bool?
    let error: String?
}

// MARK: - AnyCodable helper for analytics properties

public struct AnyCodable: Codable, Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else {
            value = NSNull()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

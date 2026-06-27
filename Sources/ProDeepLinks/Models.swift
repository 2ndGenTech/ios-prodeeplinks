import Foundation

// MARK: - Configuration

public struct InitConfig: Sendable {
    /// Preferred — publishable API key (`pdl_live_pk_*` / `pdl_test_pk_*`)
    public let apiKey: String?
    /// Deprecated alias for `apiKey`
    public let licenseKey: String?
    public let apiBaseUrl: String?
    public let apiPrefix: String?
    public let domain: String?

    public init(
        apiKey: String,
        apiBaseUrl: String? = nil,
        apiPrefix: String? = nil,
        domain: String? = nil
    ) {
        self.apiKey = apiKey
        self.licenseKey = nil
        self.apiBaseUrl = apiBaseUrl
        self.apiPrefix = apiPrefix
        self.domain = domain
    }

    /// Deprecated — use `init(apiKey:)` instead.
    public init(
        licenseKey: String,
        apiBaseUrl: String? = nil,
        apiPrefix: String? = nil,
        domain: String? = nil
    ) {
        self.apiKey = nil
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

public struct AnalyticsTrackResult: Sendable {
    public let success: Bool
    public let queued: Bool?
    public let error: String?

    public init(success: Bool, queued: Bool? = nil, error: String? = nil) {
        self.success = success
        self.queued = queued
        self.error = error
    }
}

public struct FlushResult: Sendable {
    public let success: Bool
    public let count: Int?
    public let sessionId: String?
    public let error: String?

    public init(success: Bool, count: Int? = nil, sessionId: String? = nil, error: String? = nil) {
        self.success = success
        self.count = count
        self.sessionId = sessionId
        self.error = error
    }
}

public struct TrackPurchaseResult: Sendable {
    public let success: Bool
    public let event: MmpEventResponse?
    public let conversion: MmpConversionResponse?
    public let error: String?

    public init(
        success: Bool,
        event: MmpEventResponse? = nil,
        conversion: MmpConversionResponse? = nil,
        error: String? = nil
    ) {
        self.success = success
        self.event = event
        self.conversion = conversion
        self.error = error
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

// MARK: - Attribution

public struct DeepLinkAttributionParams: Sendable {
    public var clickId: String?
    public var pdlSessionId: String?
    public var shortCode: String?
    public var utmSource: String?
    public var utmMedium: String?
    public var utmCampaign: String?
    public var utmContent: String?
    public var utmTerm: String?

    public init(
        clickId: String? = nil,
        pdlSessionId: String? = nil,
        shortCode: String? = nil,
        utmSource: String? = nil,
        utmMedium: String? = nil,
        utmCampaign: String? = nil,
        utmContent: String? = nil,
        utmTerm: String? = nil
    ) {
        self.clickId = clickId
        self.pdlSessionId = pdlSessionId
        self.shortCode = shortCode
        self.utmSource = utmSource
        self.utmMedium = utmMedium
        self.utmCampaign = utmCampaign
        self.utmContent = utmContent
        self.utmTerm = utmTerm
    }
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
    let customerUserId: String?
    let userId: String?

    init(
        basic: FingerprintBasicPayload,
        network: FingerprintNetworkPayload,
        device: FingerprintDevicePayload,
        customerUserId: String? = nil,
        userId: String? = nil
    ) {
        self.basic = basic
        self.network = network
        self.device = device
        self.customerUserId = customerUserId
        self.userId = userId
    }
}

public struct MmpEventPayload: Codable, Sendable {
    public var eventType: String
    public var deviceId: String
    public var platform: String
    public var sessionId: String?
    public var userId: String?
    public var customerUserId: String?
    public var clickId: String?
    public var pdlSessionId: String?
    public var source: String?
    public var medium: String?
    public var campaign: String?
    public var utmSource: String?
    public var utmMedium: String?
    public var utmCampaign: String?
    public var utmContent: String?
    public var utmTerm: String?
    public var osVersion: String?
    public var deviceModel: String?
    public var screenSize: String?
    public var carrier: String?
    public var networkType: String?
    public var language: String?
    public var timezone: String?
    public var appVersion: String?
    public var sdkVersion: String?
    public var revenue: Double?
    public var currency: String?
    public var shortCode: String?
    public var properties: [String: AnyCodable]?
    public var timestamp: String?
}

public struct MmpConversionPayload: Codable, Sendable {
    public var conversionType: String
    public var deviceId: String
    public var platform: String
    public var sessionId: String?
    public var userId: String?
    public var timestamp: String?
    public var revenue: Double?
    public var currency: String?
    public var orderId: String?
    public var productId: String?
    public var productName: String?
    public var category: String?
    public var quantity: Int?
    public var properties: [String: AnyCodable]?
}

public struct TrackPurchasePayload: Sendable {
    public let conversionType: String?
    public let revenue: Double
    public let currency: String?
    public let orderId: String?
    public let productId: String?
    public let productName: String?
    public let category: String?
    public let quantity: Int?
    public let properties: [String: AnyCodable]?

    public init(
        revenue: Double,
        currency: String? = nil,
        orderId: String? = nil,
        productId: String? = nil,
        productName: String? = nil,
        category: String? = nil,
        quantity: Int? = nil,
        conversionType: String? = nil,
        properties: [String: AnyCodable]? = nil
    ) {
        self.revenue = revenue
        self.currency = currency
        self.orderId = orderId
        self.productId = productId
        self.productName = productName
        self.category = category
        self.quantity = quantity
        self.conversionType = conversionType
        self.properties = properties
    }
}

public struct CustomDeepLinkAnalyticsEvent: Codable, Sendable {
    public var eventType: String
    public var eventName: String?
    public var category: String?
    public var action: String?
    public var label: String?
    public var value: Double?
    public var properties: [String: AnyCodable]?
    public var sessionId: String?
    public var customerUserId: String?
    public var userId: String?
    public var revenue: Double?
    public var currency: String?
    public var pageUrl: String?
    public var pageTitle: String?

    public init(
        eventType: String,
        eventName: String? = nil,
        category: String? = nil,
        action: String? = nil,
        label: String? = nil,
        value: Double? = nil,
        properties: [String: AnyCodable]? = nil,
        sessionId: String? = nil,
        customerUserId: String? = nil,
        userId: String? = nil,
        revenue: Double? = nil,
        currency: String? = nil,
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
        self.customerUserId = customerUserId
        self.userId = userId
        self.revenue = revenue
        self.currency = currency
        self.pageUrl = pageUrl
        self.pageTitle = pageTitle
    }
}

// MARK: - API Responses

struct FingerprintMatchResponse: Decodable {
    let matched: Bool?
    let matchConfidence: Double?
    let clickId: String?
    let pdlSessionId: String?
    let url: String?
    let message: String?
    let error: String?

    init(
        matched: Bool? = nil,
        matchConfidence: Double? = nil,
        clickId: String? = nil,
        pdlSessionId: String? = nil,
        url: String? = nil,
        message: String? = nil,
        error: String? = nil
    ) {
        self.matched = matched
        self.matchConfidence = matchConfidence
        self.clickId = clickId
        self.pdlSessionId = pdlSessionId
        self.url = url
        self.message = message
        self.error = error
    }
}

public struct MmpEventResponse: Sendable {
    public let success: Bool
    public let eventId: String?
    public let sessionId: String?
    public let resolvedEventType: String?
    public let attributionType: String?
    public let source: String?
    public let campaign: String?
    public let error: String?

    public init(
        success: Bool,
        eventId: String? = nil,
        sessionId: String? = nil,
        resolvedEventType: String? = nil,
        attributionType: String? = nil,
        source: String? = nil,
        campaign: String? = nil,
        error: String? = nil
    ) {
        self.success = success
        self.eventId = eventId
        self.sessionId = sessionId
        self.resolvedEventType = resolvedEventType
        self.attributionType = attributionType
        self.source = source
        self.campaign = campaign
        self.error = error
    }
}

struct MmpBatchResponse: Decodable {
    let success: Bool?
    let count: Int?
    let sessionId: String?
    let resolvedEventType: String?
    let attributionType: String?
    let source: String?
    let campaign: String?
    let eventIds: [String]?
    let message: String?
    let error: String?

    init(
        success: Bool? = nil,
        count: Int? = nil,
        sessionId: String? = nil,
        resolvedEventType: String? = nil,
        attributionType: String? = nil,
        source: String? = nil,
        campaign: String? = nil,
        eventIds: [String]? = nil,
        message: String? = nil,
        error: String? = nil
    ) {
        self.success = success
        self.count = count
        self.sessionId = sessionId
        self.resolvedEventType = resolvedEventType
        self.attributionType = attributionType
        self.source = source
        self.campaign = campaign
        self.eventIds = eventIds
        self.message = message
        self.error = error
    }
}

struct MmpEventAPIResponse: Decodable {
    let success: Bool?
    let eventId: String?
    let sessionId: String?
    let resolvedEventType: String?
    let attributionType: String?
    let source: String?
    let campaign: String?
    let message: String?
    let error: String?
}

public struct MmpAttributionTouchpoint: Sendable, Codable {
    public let source: String
    public let campaign: String?
    public let timestamp: String
    public let weight: Double
}

public struct MmpAttributionResult: Sendable, Codable {
    public let conversionId: String
    public let attributedSource: String?
    public let attributedCampaign: String?
    public let attributedRevenue: Double?
    public let model: String?
    public let touchpoints: [MmpAttributionTouchpoint]?
}

public struct MmpConversionResponse: Sendable {
    public let success: Bool
    public let conversionId: String?
    public let attribution: MmpAttributionResult?
    public let error: String?

    public init(
        success: Bool,
        conversionId: String? = nil,
        attribution: MmpAttributionResult? = nil,
        error: String? = nil
    ) {
        self.success = success
        self.conversionId = conversionId
        self.attribution = attribution
        self.error = error
    }
}

public struct MmpAttributionResponse: Sendable {
    public let success: Bool
    public let attributions: MmpAttributionResult?
    public let error: String?

    public init(success: Bool, attributions: MmpAttributionResult? = nil, error: String? = nil) {
        self.success = success
        self.attributions = attributions
        self.error = error
    }
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

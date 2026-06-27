import Foundation

enum EventPayload {
    static let sdkVersion = "0.2.0"

    static func mapLegacyEventType(_ eventType: String) -> String {
        switch eventType {
        case "identify": return "login"
        case "pro_track": return "custom"
        case "deeplink": return "app_open"
        default: return eventType
        }
    }

    static func buildMmpEvent(
        from fingerprint: DeviceFingerprint,
        overrides: [String: Any] = [:]
    ) -> MmpEventPayload {
        var payload = MmpEventPayload(
            eventType: "custom",
            deviceId: fingerprint.deviceId,
            platform: fingerprint.platform
        )
        payload.osVersion = fingerprint.osVersion
        payload.deviceModel = fingerprint.deviceModel
        payload.screenSize = fingerprint.screenResolution
        payload.carrier = fingerprint.carrier
        payload.networkType = fingerprint.connectionType
        payload.language = fingerprint.language
        payload.timezone = fingerprint.timezone
        payload.appVersion = fingerprint.appVersion
        payload.sdkVersion = sdkVersion

        if let eventType = overrides["eventType"] as? String { payload.eventType = eventType }
        if let sessionId = overrides["sessionId"] as? String { payload.sessionId = sessionId }
        if let userId = overrides["userId"] as? String {
            payload.userId = userId
            payload.customerUserId = userId
        }
        if let clickId = overrides["clickId"] as? String { payload.clickId = clickId }
        if let pdlSessionId = overrides["pdlSessionId"] as? String { payload.pdlSessionId = pdlSessionId }
        if let shortCode = overrides["shortCode"] as? String { payload.shortCode = shortCode }
        if let utmSource = overrides["utmSource"] as? String { payload.utmSource = utmSource }
        if let utmMedium = overrides["utmMedium"] as? String { payload.utmMedium = utmMedium }
        if let utmCampaign = overrides["utmCampaign"] as? String { payload.utmCampaign = utmCampaign }
        if let utmContent = overrides["utmContent"] as? String { payload.utmContent = utmContent }
        if let utmTerm = overrides["utmTerm"] as? String { payload.utmTerm = utmTerm }
        if let revenue = overrides["revenue"] as? Double { payload.revenue = revenue }
        if let currency = overrides["currency"] as? String { payload.currency = currency }
        if let properties = overrides["properties"] as? [String: AnyCodable] { payload.properties = properties }

        return payload
    }

    static func buildEventPayload(
        fingerprint: DeviceFingerprint,
        eventType: String,
        sessionId: String?,
        userId: String?,
        attribution: DeepLinkAttributionParams,
        revenue: Double? = nil,
        currency: String? = nil,
        properties: [String: AnyCodable]? = nil
    ) -> MmpEventPayload {
        var overrides: [String: Any] = ["eventType": eventType]
        if let sessionId { overrides["sessionId"] = sessionId }
        if let userId { overrides["userId"] = userId }
        if let clickId = attribution.clickId { overrides["clickId"] = clickId }
        if let pdlSessionId = attribution.pdlSessionId { overrides["pdlSessionId"] = pdlSessionId }
        if let shortCode = attribution.shortCode { overrides["shortCode"] = shortCode }
        if let utmSource = attribution.utmSource { overrides["utmSource"] = utmSource }
        if let utmMedium = attribution.utmMedium { overrides["utmMedium"] = utmMedium }
        if let utmCampaign = attribution.utmCampaign { overrides["utmCampaign"] = utmCampaign }
        if let utmContent = attribution.utmContent { overrides["utmContent"] = utmContent }
        if let utmTerm = attribution.utmTerm { overrides["utmTerm"] = utmTerm }
        if let revenue { overrides["revenue"] = revenue }
        if let currency { overrides["currency"] = currency }
        if let properties, !properties.isEmpty { overrides["properties"] = properties }
        return buildMmpEvent(from: fingerprint, overrides: overrides)
    }
}

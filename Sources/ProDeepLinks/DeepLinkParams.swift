import Foundation

enum DeepLinkParams {
    static func parse(_ url: String) -> DeepLinkAttributionParams {
        guard let components = URLComponents(string: url),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else {
            return DeepLinkAttributionParams()
        }

        func pick(_ name: String) -> String? {
            queryItems.first(where: { $0.name == name })?.value
        }

        return DeepLinkAttributionParams(
            clickId: pick("clickId"),
            pdlSessionId: pick("pdlSessionId"),
            shortCode: pick("shortCode"),
            utmSource: pick("utm_source"),
            utmMedium: pick("utm_medium"),
            utmCampaign: pick("utm_campaign"),
            utmContent: pick("utm_content"),
            utmTerm: pick("utm_term")
        )
    }

    static func merge(into target: DeepLinkAttributionParams, from source: DeepLinkAttributionParams) -> DeepLinkAttributionParams {
        DeepLinkAttributionParams(
            clickId: source.clickId ?? target.clickId,
            pdlSessionId: source.pdlSessionId ?? target.pdlSessionId,
            shortCode: source.shortCode ?? target.shortCode,
            utmSource: source.utmSource ?? target.utmSource,
            utmMedium: source.utmMedium ?? target.utmMedium,
            utmCampaign: source.utmCampaign ?? target.utmCampaign,
            utmContent: source.utmContent ?? target.utmContent,
            utmTerm: source.utmTerm ?? target.utmTerm
        )
    }
}

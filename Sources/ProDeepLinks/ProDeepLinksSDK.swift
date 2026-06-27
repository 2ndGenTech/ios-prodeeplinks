import Foundation

/// Native iOS SDK for **ProDeepLinks** — deferred deep linking, attribution, and MMP event tracking.
///
/// Mirror of the [rn-prodeeplinks](https://github.com/2ndGenTech/rn-prodeeplinks) React Native package.
public enum ProDeepLinksSDK {
    private static let state = SDKState()

    // MARK: - Launch URL (Universal Links / custom scheme)

    /// Call from `AppDelegate` or `SceneDelegate` when the app opens via a deep link.
    /// Equivalent to React Native's `Linking.getInitialURL()` / warm-start listener.
    public static func setLaunchURL(_ url: URL?) {
        Task { await storeDeepLinkUrl(url?.absoluteString) }
    }

    /// String convenience for `setLaunchURL`.
    public static func setLaunchURLString(_ urlString: String?) {
        Task { await storeDeepLinkUrl(urlString) }
    }

    // MARK: - Initialization

    /// Initialize the SDK with your publishable API key.
    /// Parses deep link params on launch and runs deferred fingerprint match in parallel.
    /// App launch `app_open` events are handled by the backend layer — not sent from this SDK.
    public static func initialize(config: InitConfig) async -> InitResult {
        let apiKey = LicenseValidator.resolveApiKey(from: config)
        if config.licenseKey != nil, config.apiKey == nil {
            #if DEBUG
            print("[ProDeepLink] `licenseKey` is deprecated — use `apiKey` instead.")
            #endif
        }

        let validation = LicenseValidator.validateApiKeyFormat(apiKey)
        if !validation.isValid {
            return InitResult(success: false, error: validation.message ?? "Invalid API key")
        }

        if let baseURL = config.apiBaseUrl {
            await state.setBaseURL(baseURL)
            APIClient.setBaseURL(baseURL)
        }

        let fingerprint = await FingerprintCollector.generate()
        await state.storeApiKey(apiKey)
        await state.setCachedFingerprint(fingerprint)
        await state.setInitialized(true)

        if let launchURL = await state.launchURL {
            await storeDeepLinkUrl(launchURL)
        }

        Task { await runDeferredFingerprintMatch() }

        return InitResult(success: true)
    }

    /// Convenience initializer with API key.
    public static func initialize(apiKey: String) async -> InitResult {
        await initialize(config: InitConfig(apiKey: apiKey))
    }

    /// Deprecated — use `initialize(apiKey:)` or `initialize(config: InitConfig(apiKey:))`.
    public static func initialize(licenseKey: String) async -> InitResult {
        await initialize(config: InitConfig(licenseKey: licenseKey))
    }

    // MARK: - Session & identity

    /// Set the active MMP session ID returned by the backend `app_open` layer.
    public static func updateSessionId(_ sessionId: String?) async {
        await state.setSessionId(sessionId)
    }

    /// Set your internal user id after login/signup. Automatically sends a `login` event.
    public static func setCustomerUserId(_ customerUserId: String?) async -> InitResult {
        guard let ready = await requireInitialized() else {
            return InitResult(success: false, error: "Please call initialize() first with your API key")
        }

        let userId = customerUserId
        await state.setCustomerUserId(userId)

        guard let userId else {
            return InitResult(success: true)
        }

        guard let fingerprint = await state.cachedFingerprint else {
            return InitResult(success: false, error: "Device fingerprint not ready")
        }

        let loginEvent = EventPayload.buildEventPayload(
            fingerprint: fingerprint,
            eventType: "login",
            sessionId: await state.sessionId,
            userId: userId,
            attribution: await state.attributionParams
        )

        let response = await APIClient.postMmpEvent(
            apiKey: ready,
            event: loginEvent,
            baseURL: await state.baseURL
        )
        await applySessionFromResponse(response.sessionId)

        if response.success {
            return InitResult(success: true)
        }
        return InitResult(success: false, error: response.error)
    }

    // MARK: - Deep Link Resolution

    /// Resolves a deep link URL: cached/OS link first, then deferred fingerprint match.
    public static func getDeepLink() async -> DeepLinkResponse {
        await getDeepLink(onURL: nil)
    }

    /// Resolves a deep link and optionally invokes a callback when a URL is found.
    public static func getDeepLink(onURL: ((String) -> Void)?) async -> DeepLinkResponse {
        guard await requireInitialized() != nil else {
            return DeepLinkResponse(
                success: false,
                error: "Please call initialize() first with your API key"
            )
        }

        if let cached = await state.resolvedDeepLinkUrl {
            onURL?(cached)
            return DeepLinkResponse(success: true, url: cached)
        }

        if let launchURL = await state.launchURL, !launchURL.isEmpty {
            await storeDeepLinkUrl(launchURL)
            onURL?(launchURL)
            return DeepLinkResponse(success: true, url: launchURL)
        }

        guard let fingerprint = await state.cachedFingerprint else {
            return DeepLinkResponse(success: false, error: "Device fingerprint not ready")
        }

        let match = await APIClient.matchFingerprint(
            payload: FingerprintCollector.buildMatchPayload(
                from: fingerprint,
                customerUserId: await state.customerUserId
            ),
            baseURL: await state.baseURL
        )

        if match.matched == true, let url = match.url, !url.isEmpty {
            await state.setResolvedDeepLinkUrl(url)
            if match.clickId != nil || match.pdlSessionId != nil {
                await state.mergeAttributionParams(DeepLinkAttributionParams(
                    clickId: match.clickId,
                    pdlSessionId: match.pdlSessionId
                ))
            }
            onURL?(url)
            return DeepLinkResponse(success: true, url: url, message: match.message)
        }

        if let error = match.error {
            return DeepLinkResponse(success: false, error: error)
        }

        return DeepLinkResponse(success: true, url: nil, message: "No deep link available")
    }

    // MARK: - Analytics & MMP

    public static func trackAnalyticsEvent(_ event: CustomDeepLinkAnalyticsEvent) async -> AnalyticsTrackResult {
        guard let apiKey = await requireInitialized() else {
            return AnalyticsTrackResult(success: false, error: "Please call initialize() first with your API key")
        }

        guard let fingerprint = await state.cachedFingerprint else {
            return AnalyticsTrackResult(success: false, error: "Device fingerprint not ready")
        }

        let eventType = EventPayload.mapLegacyEventType(event.eventType)
        var properties = event.properties ?? [:]
        if let eventName = event.eventName {
            properties["name"] = AnyCodable(eventName)
        }

        let storedCustomerUserId = await state.customerUserId
        let storedSessionId = await state.sessionId
        let attribution = await state.attributionParams

        let resolvedUserId = event.customerUserId ?? storedCustomerUserId ?? event.userId

        let payload = EventPayload.buildEventPayload(
            fingerprint: fingerprint,
            eventType: eventType,
            sessionId: event.sessionId ?? storedSessionId,
            userId: resolvedUserId,
            attribution: attribution,
            revenue: event.revenue,
            currency: event.currency,
            properties: properties.isEmpty ? nil : properties
        )

        if eventType == "login" || eventType == "purchase" || eventType == "app_open" {
            let response = await APIClient.postMmpEvent(
                apiKey: apiKey,
                event: payload,
                baseURL: await state.baseURL
            )
            await applySessionFromResponse(response.sessionId)
            if response.success, payload.clickId != nil || payload.pdlSessionId != nil {
                await state.clearAttributionParams()
            }
            return AnalyticsTrackResult(success: response.success, error: response.error)
        }

        APIClient.enqueueMmpEvent(payload, apiKey: apiKey)
        return AnalyticsTrackResult(success: true, queued: true)
    }

    public static func trackConversion(
        _ payload: MmpConversionPayload
    ) async -> MmpConversionResponse {
        guard let apiKey = await requireInitialized() else {
            return MmpConversionResponse(success: false, error: "Please call initialize() first with your API key")
        }

        if let orderId = payload.orderId, await state.hasSentOrderId(orderId) {
            return MmpConversionResponse(success: true)
        }

        guard let fingerprint = await state.cachedFingerprint else {
            return MmpConversionResponse(success: false, error: "Device fingerprint not ready")
        }

        var fullPayload = payload
        fullPayload.deviceId = fingerprint.deviceId
        fullPayload.platform = fingerprint.platform
        if let sessionId = await state.sessionId { fullPayload.sessionId = sessionId }
        if let userId = await state.customerUserId { fullPayload.userId = userId }

        let response = await APIClient.postConversion(
            apiKey: apiKey,
            payload: fullPayload,
            baseURL: await state.baseURL
        )

        if response.success, let orderId = payload.orderId {
            await state.markOrderIdSent(orderId)
        }

        if response.success, response.attribution == nil, let conversionId = response.conversionId {
            let attribution = await APIClient.fetchAttributionWithRetry(
                apiKey: apiKey,
                conversionId: conversionId,
                baseURL: await state.baseURL
            )
            if attribution.success, let attributions = attribution.attributions {
                return MmpConversionResponse(
                    success: true,
                    conversionId: conversionId,
                    attribution: attributions
                )
            }
        }

        return response
    }

    /// Track a purchase per the integration guide: purchase event + conversion in parallel.
    public static func trackPurchase(_ payload: TrackPurchasePayload) async -> TrackPurchaseResult {
        guard let apiKey = await requireInitialized() else {
            return TrackPurchaseResult(success: false, error: "Please call initialize() first with your API key")
        }

        guard let fingerprint = await state.cachedFingerprint else {
            return TrackPurchaseResult(success: false, error: "Device fingerprint not ready")
        }

        let conversionType = payload.conversionType ?? "purchase"

        let purchaseEvent = EventPayload.buildEventPayload(
            fingerprint: fingerprint,
            eventType: "purchase",
            sessionId: await state.sessionId,
            userId: await state.customerUserId,
            attribution: await state.attributionParams,
            revenue: payload.revenue,
            currency: payload.currency
        )

        var conversionPayload = MmpConversionPayload(
            conversionType: conversionType,
            deviceId: fingerprint.deviceId,
            platform: fingerprint.platform,
            revenue: payload.revenue,
            currency: payload.currency,
            orderId: payload.orderId,
            productId: payload.productId,
            productName: payload.productName,
            category: payload.category,
            quantity: payload.quantity,
            properties: payload.properties
        )
        if let sessionId = await state.sessionId { conversionPayload.sessionId = sessionId }
        if let userId = await state.customerUserId { conversionPayload.userId = userId }

        async let eventResult = APIClient.postMmpEvent(
            apiKey: apiKey,
            event: purchaseEvent,
            baseURL: await state.baseURL
        )
        async let conversionResult = trackConversion(conversionPayload)

        let event = await eventResult
        let conversion = await conversionResult
        await applySessionFromResponse(event.sessionId)

        let success = event.success && conversion.success
        return TrackPurchaseResult(
            success: success,
            event: event,
            conversion: conversion,
            error: event.error ?? conversion.error
        )
    }

    public static func getAttribution(conversionId: String) async -> MmpAttributionResponse {
        guard let apiKey = await requireInitialized() else {
            return MmpAttributionResponse(success: false, error: "Please call initialize() first with your API key")
        }

        return await APIClient.fetchAttributionWithRetry(
            apiKey: apiKey,
            conversionId: conversionId,
            baseURL: await state.baseURL
        )
    }

    public static func flush() async -> FlushResult {
        guard await requireInitialized() != nil else {
            return FlushResult(success: false, count: 0)
        }

        let result = await APIClient.flushMmpEvents(baseURL: await state.baseURL)
        await applySessionFromResponse(result.sessionId)
        return result
    }

    // MARK: - State

    public static func isReady() async -> Bool {
        await state.isReady()
    }

    public static func reset() async {
        APIClient.resetQueue()
        await state.reset()
    }

    // MARK: - Internal helpers

    private static func requireInitialized() async -> String? {
        guard await state.isReady(), let apiKey = await state.apiKey else { return nil }
        return apiKey
    }

    private static func storeDeepLinkUrl(_ url: String?) async {
        guard let url, !url.isEmpty else { return }
        await state.mergeAttributionParams(DeepLinkParams.parse(url))
        await state.setResolvedDeepLinkUrl(url)
        await state.setLaunchURL(url)
    }

    private static func applySessionFromResponse(_ sessionId: String?) async {
        if let sessionId {
            await state.setSessionId(sessionId)
        }
    }

    private static func runDeferredFingerprintMatch() async {
        if await state.resolvedDeepLinkUrl != nil { return }
        guard let fingerprint = await state.cachedFingerprint else { return }

        let match = await APIClient.matchFingerprint(
            payload: FingerprintCollector.buildMatchPayload(
                from: fingerprint,
                customerUserId: await state.customerUserId
            ),
            baseURL: await state.baseURL
        )

        guard match.matched == true else { return }

        if let url = match.url {
            await state.setResolvedDeepLinkUrl(url)
        }

        if match.clickId != nil || match.pdlSessionId != nil {
            await state.mergeAttributionParams(DeepLinkAttributionParams(
                clickId: match.clickId,
                pdlSessionId: match.pdlSessionId
            ))
        }
    }
}

// MARK: - Advanced class-based API

public final class ProDeepLink: @unchecked Sendable {
    private let apiKey: String
    private let apiBaseUrl: String?

    public init(config: InitConfig) throws {
        let key = LicenseValidator.resolveApiKey(from: config)
        let validation = LicenseValidator.validateApiKeyFormat(key)
        if !validation.isValid {
            throw ProDeepLinkError.invalidApiKey(validation.message ?? "Invalid API key")
        }
        self.apiKey = key
        self.apiBaseUrl = config.apiBaseUrl
    }

    public func initialize() async -> InitResult {
        await ProDeepLinksSDK.initialize(config: InitConfig(
            apiKey: apiKey,
            apiBaseUrl: apiBaseUrl
        ))
    }

    public func getDeepLinkURL() async -> DeepLinkResponse {
        await ProDeepLinksSDK.getDeepLink()
    }
}

public enum ProDeepLinkError: Error, LocalizedError {
    case invalidApiKey(String)

    public var errorDescription: String? {
        switch self {
        case .invalidApiKey(let message):
            return message
        }
    }
}

// MARK: - Thread-safe state

private actor SDKState {
    private(set) var apiKey: String?
    private(set) var baseURL = APIClient.defaultBaseURL
    private(set) var isInitialized = false
    private(set) var sessionId: String?
    private(set) var customerUserId: String?
    private(set) var cachedFingerprint: DeviceFingerprint?
    private(set) var attributionParams = DeepLinkAttributionParams()
    private(set) var resolvedDeepLinkUrl: String?
    private(set) var launchURL: String?
    private var sentOrderIds = Set<String>()

    func storeApiKey(_ key: String) {
        apiKey = key
    }

    func setBaseURL(_ url: String) {
        baseURL = APIClient.baseURL(from: url)
    }

    func setInitialized(_ value: Bool) {
        isInitialized = value
    }

    func setSessionId(_ value: String?) {
        sessionId = value
    }

    func setCustomerUserId(_ value: String?) {
        customerUserId = value
    }

    func setCachedFingerprint(_ value: DeviceFingerprint?) {
        cachedFingerprint = value
    }

    func mergeAttributionParams(_ params: DeepLinkAttributionParams) {
        attributionParams = DeepLinkParams.merge(into: attributionParams, from: params)
    }

    func clearAttributionParams() {
        attributionParams = DeepLinkAttributionParams()
    }

    func setResolvedDeepLinkUrl(_ url: String?) {
        resolvedDeepLinkUrl = url
    }

    func setLaunchURL(_ url: String?) {
        launchURL = url
    }

    func hasSentOrderId(_ orderId: String) -> Bool {
        sentOrderIds.contains(orderId)
    }

    func markOrderIdSent(_ orderId: String) {
        sentOrderIds.insert(orderId)
    }

    func isReady() -> Bool {
        isInitialized && apiKey != nil
    }

    func reset() {
        apiKey = nil
        baseURL = APIClient.defaultBaseURL
        isInitialized = false
        sessionId = nil
        customerUserId = nil
        cachedFingerprint = nil
        attributionParams = DeepLinkAttributionParams()
        resolvedDeepLinkUrl = nil
        launchURL = nil
        sentOrderIds.removeAll()
    }
}

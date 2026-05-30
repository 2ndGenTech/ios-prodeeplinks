import Foundation

/// Secure deep linking SDK with license validation and device fingerprinting.
///
/// Mirror of the `rn-prodeeplinks` React Native package for native iOS apps.
public enum ProDeepLinksSDK {
    private static let defaultAPIEndpoint = "https://api.prodeeplinks.com/"
    private static let state = SDKState()

    // MARK: - Launch URL (Universal Links / custom scheme)

    /// Call from `AppDelegate` or `SceneDelegate` when the app opens via a deep link.
    /// Equivalent to React Native's `Linking.getInitialURL()` fallback.
    public static func setLaunchURL(_ url: URL?) {
        Task { await state.setLaunchURL(url?.absoluteString) }
    }

    /// String convenience for `setLaunchURL`.
    public static func setLaunchURLString(_ urlString: String?) {
        Task { await state.setLaunchURL(urlString) }
    }

    // MARK: - Initialization

    /// Initialize the SDK with your license key. Must be called before `getDeepLink()`.
    public static func initialize(config: InitConfig) async -> InitResult {
        let validation = LicenseValidator.validateFormat(config.licenseKey)
        if !validation.isValid {
            return InitResult(success: false, error: validation.message ?? "Invalid license key")
        }

        let remoteValidation = await APIClient.validateLicenseInit(licenseKey: config.licenseKey)
        if !remoteValidation.success {
            return InitResult(success: false, error: remoteValidation.error ?? "License validation failed")
        }

        await state.storeLicenseKey(config.licenseKey)
        return InitResult(success: true)
    }

    /// Convenience initializer matching the RN `init({ licenseKey })` API.
    public static func initialize(licenseKey: String) async -> InitResult {
        await initialize(config: InitConfig(licenseKey: licenseKey))
    }

    // MARK: - Deep Link Resolution

    /// Resolves a deep link via fingerprint API, then falls back to the stored launch URL.
    public static func getDeepLink() async -> DeepLinkResponse {
        await getDeepLink(onURL: nil)
    }

    /// Resolves a deep link and optionally invokes a callback when a URL is found.
    public static func getDeepLink(onURL: ((String) -> Void)?) async -> DeepLinkResponse {
        guard await state.isReady(), let licenseKey = await state.licenseKey else {
            return DeepLinkResponse(
                success: false,
                error: "Please call initialize() first with your license key"
            )
        }

        do {
            let fingerprint = await FingerprintCollector.generate()
            let matchPayload = FingerprintCollector.buildMatchPayload(from: fingerprint)
            var apiError: String?

            let matchResult = await APIClient.matchFingerprint(
                payload: matchPayload,
                baseURL: defaultAPIEndpoint,
                licenseKey: licenseKey
            )

            if let apiURL = matchResult.url, !apiURL.isEmpty {
                await trackDeepLinkResolved(url: apiURL, source: "api", fingerprint: fingerprint)
                onURL?(apiURL)
                return DeepLinkResponse(
                    success: true,
                    url: apiURL,
                    message: matchResult.message
                )
            }

            if let error = matchResult.error {
                apiError = error
            }

            if let launchURL = await state.launchURL, !launchURL.isEmpty {
                await trackDeepLinkResolved(url: launchURL, source: "linking", fingerprint: fingerprint)
                onURL?(launchURL)
                return DeepLinkResponse(success: true, url: launchURL)
            }

            if let apiError {
                return DeepLinkResponse(success: false, error: apiError)
            }

            return DeepLinkResponse(success: true, url: nil, message: "No deep link available")
        } catch {
            return DeepLinkResponse(success: false, error: error.localizedDescription)
        }
    }

    // MARK: - Analytics

    public static func trackAnalyticsEvent(_ event: CustomDeepLinkAnalyticsEvent) async -> [String: Any] {
        guard await state.isReady(), let licenseKey = await state.licenseKey else {
            return ["success": false, "error": "Please call initialize() first with your license key"]
        }
        return await APIClient.trackCustomDeepLinkEvent(event: event, licenseKey: licenseKey)
    }

    // MARK: - State

    public static func isReady() async -> Bool {
        await state.isReady()
    }

    public static func reset() async {
        await state.reset()
    }

    // MARK: - Internal tracking

    private static func trackDeepLinkResolved(
        url: String,
        source: String,
        fingerprint: DeviceFingerprint
    ) async {
        var properties: [String: AnyCodable] = [
            "shortUrl": AnyCodable(url),
            "source": AnyCodable(source),
        ]

        if let data = try? JSONEncoder().encode(fingerprint),
           let fingerprintDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            properties["fingerprint"] = AnyCodable(fingerprintDict)
        }

        let event = CustomDeepLinkAnalyticsEvent(
            eventType: "deeplink",
            eventName: "pro_track",
            category: source,
            action: "open",
            label: url,
            properties: properties
        )

        _ = await trackAnalyticsEvent(event)
    }
}

// MARK: - Advanced class-based API

public final class ProDeepLink: @unchecked Sendable {
    private let licenseKey: String
    private let apiEndpoint: String?

    public init(config: InitConfig) throws {
        let validation = LicenseValidator.validateFormat(config.licenseKey)
        if !validation.isValid {
            throw ProDeepLinkError.invalidLicenseKey(validation.message ?? "Invalid license key")
        }
        self.licenseKey = config.licenseKey
        self.apiEndpoint = config.apiBaseUrl
    }

    public func getDeepLinkURL() async -> DeepLinkResponse {
        let remoteValidation = await APIClient.validateLicenseInit(licenseKey: licenseKey)
        if !remoteValidation.success {
            return DeepLinkResponse(
                success: false,
                error: remoteValidation.error ?? "License validation failed"
            )
        }

        let fingerprint = await FingerprintCollector.generate()
        let result = await APIClient.fetchDeepLinkURLWithRetry(
            licenseKey: licenseKey,
            fingerprint: fingerprint,
            retryAttempts: 3,
            apiEndpoint: apiEndpoint
        )

        if result.success, let url = result.url {
            _ = await APIClient.trackCustomDeepLinkEvent(
                event: CustomDeepLinkAnalyticsEvent(
                    eventType: "deeplink",
                    eventName: "pro_track",
                    category: "api",
                    action: "open",
                    label: url,
                    properties: ["shortUrl": AnyCodable(url), "source": AnyCodable("api")]
                ),
                licenseKey: licenseKey
            )
        }

        return result
    }
}

public enum ProDeepLinkError: Error, LocalizedError {
    case invalidLicenseKey(String)

    public var errorDescription: String? {
        switch self {
        case .invalidLicenseKey(let message):
            return message
        }
    }
}

// MARK: - Thread-safe state

private actor SDKState {
    private(set) var licenseKey: String?
    private(set) var launchURL: String?

    func storeLicenseKey(_ key: String) {
        licenseKey = key
    }

    func setLaunchURL(_ url: String?) {
        launchURL = url
    }

    func isReady() -> Bool {
        licenseKey != nil
    }

    func reset() {
        licenseKey = nil
        launchURL = nil
    }
}

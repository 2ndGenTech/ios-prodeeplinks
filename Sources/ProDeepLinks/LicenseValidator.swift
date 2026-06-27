import Foundation

enum LicenseValidator {
    static func resolveApiKey(from config: InitConfig) -> String {
        let apiKey = (config.apiKey ?? config.licenseKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return apiKey
    }

    static func validateApiKeyFormat(_ apiKey: String) -> LicenseValidationResult {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if key.isEmpty {
            return LicenseValidationResult(isValid: false, message: "API key is required")
        }

        let isCanonicalPk = key.hasPrefix("pdl_live_pk_") || key.hasPrefix("pdl_test_pk_")
        let isLegacyPub = key.hasPrefix("cdl_pub_live_") || key.hasPrefix("cdl_pub_test_")
        let isLegacy =
            key.hasPrefix("pdl_live_") ||
            key.hasPrefix("pdl_test_") ||
            key.hasPrefix("ak_app_") ||
            key.hasPrefix("CDL-V1-") ||
            key.contains("live") ||
            key.contains("test")

        if !isCanonicalPk, !isLegacyPub, !isLegacy {
            return LicenseValidationResult(
                isValid: false,
                message: "Invalid API key format. Expected pdl_live_pk_* or pdl_test_pk_*"
            )
        }

        if key.hasPrefix("pdl_live_sk_") || key.hasPrefix("pdl_test_sk_") {
            return LicenseValidationResult(
                isValid: false,
                message: "Secret keys (sk) must not be embedded in mobile apps. Use publishable keys (pk)."
            )
        }

        return LicenseValidationResult(isValid: true)
    }

    /// @deprecated Use `validateApiKeyFormat`
    static func validateFormat(_ licenseKey: String) -> LicenseValidationResult {
        validateApiKeyFormat(licenseKey)
    }
}

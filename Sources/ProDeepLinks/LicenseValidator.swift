import Foundation

enum LicenseValidator {
    static func validateFormat(_ licenseKey: String) -> LicenseValidationResult {
        if licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return LicenseValidationResult(isValid: false, message: "License key is required")
        }
        return LicenseValidationResult(isValid: true)
    }
}

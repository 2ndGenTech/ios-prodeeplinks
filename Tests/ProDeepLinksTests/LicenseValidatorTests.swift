import XCTest
@testable import ProDeepLinks

final class LicenseValidatorTests: XCTestCase {
    func testRejectsEmptyApiKey() {
        let result = LicenseValidator.validateApiKeyFormat("")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.message, "API key is required")
    }

    func testAcceptsCanonicalPublishableKey() {
        let result = LicenseValidator.validateApiKeyFormat("pdl_live_pk_abc123")
        XCTAssertTrue(result.isValid)
    }

    func testRejectsSecretKey() {
        let result = LicenseValidator.validateApiKeyFormat("pdl_live_sk_secret")
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message?.contains("Secret keys") == true)
    }

    func testRejectsInvalidFormat() {
        let result = LicenseValidator.validateApiKeyFormat("not-a-valid-key")
        XCTAssertFalse(result.isValid)
    }

    func testResolvesApiKeyFromConfig() {
        let config = InitConfig(apiKey: "pdl_test_pk_xyz")
        XCTAssertEqual(LicenseValidator.resolveApiKey(from: config), "pdl_test_pk_xyz")
    }

    func testResolvesDeprecatedLicenseKeyFromConfig() {
        let config = InitConfig(licenseKey: "pdl_test_pk_legacy")
        XCTAssertEqual(LicenseValidator.resolveApiKey(from: config), "pdl_test_pk_legacy")
    }
}

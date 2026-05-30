import XCTest
@testable import ProDeepLinks

final class LicenseValidatorTests: XCTestCase {
    func testRejectsEmptyLicenseKey() {
        let result = LicenseValidator.validateFormat("")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.message, "License key is required")
    }

    func testAcceptsNonEmptyLicenseKey() {
        let result = LicenseValidator.validateFormat("test-license-key-123")
        XCTAssertTrue(result.isValid)
    }

    func testRejectsWhitespaceOnlyLicenseKey() {
        let result = LicenseValidator.validateFormat("   ")
        XCTAssertFalse(result.isValid)
    }
}

import XCTest
@testable import Puerto

final class UpdateCheckerTests: XCTestCase {
    func testNewerPatchVersion() {
        XCTAssertTrue(UpdateChecker.isNewer("0.0.16", than: "0.0.15"))
    }

    func testSameVersionIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer("0.0.15", than: "0.0.15"))
    }

    func testOlderVersionIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer("0.0.15", than: "0.0.16"))
    }

    func testComparisonIsNumericNotLexical() {
        XCTAssertTrue(UpdateChecker.isNewer("0.0.10", than: "0.0.9"))
        XCTAssertFalse(UpdateChecker.isNewer("0.0.9", than: "0.0.10"))
    }

    func testMajorVersionBump() {
        XCTAssertTrue(UpdateChecker.isNewer("1.0.0", than: "0.0.99"))
    }

    func testLeadingVIgnored() {
        XCTAssertTrue(UpdateChecker.isNewer("v0.0.16", than: "0.0.15"))
    }

    func testCommitSuffixIgnored() {
        XCTAssertTrue(UpdateChecker.isNewer("0.0.16-abc1234", than: "0.0.15-def5678"))
        XCTAssertFalse(UpdateChecker.isNewer("0.0.15-abc1234", than: "0.0.15-def5678"))
    }

    func testPrereleaseSuffixIgnored() {
        XCTAssertTrue(UpdateChecker.isNewer("1.2.3-beta", than: "1.2.2"))
        XCTAssertFalse(UpdateChecker.isNewer("1.2.3-beta", than: "1.2.3"))
    }

    func testLaunchAtLoginSupportedOnModernSystems() {
        // The CI and dev machines run macOS 13+; this guards the availability check.
        if #available(macOS 13.0, *) {
            XCTAssertTrue(LaunchAtLogin.isSupported)
        } else {
            XCTAssertFalse(LaunchAtLogin.isSupported)
        }
    }
}
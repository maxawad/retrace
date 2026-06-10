import XCTest
import CoreGraphics
@testable import Capture

final class CaptureBlockDetectionTests: XCTestCase {
    func testCaptureBlockReasonDetectsLoginWindowOwner() {
        let reason = CGWindowListCapture.captureBlockReason(ownerName: "loginwindow", bundleID: nil)
        XCTAssertEqual(reason, "loginwindow-visible")
    }

    func testCaptureBlockReasonDetectsLoginWindowBundle() {
        let reason = CGWindowListCapture.captureBlockReason(ownerName: "Window Server", bundleID: "com.apple.loginwindow")
        XCTAssertEqual(reason, "loginwindow-visible")
    }

    func testCaptureBlockReasonDetectsScreenSaverOwner() {
        let reason = CGWindowListCapture.captureBlockReason(ownerName: "ScreenSaverEngine", bundleID: nil)
        XCTAssertEqual(reason, "screensaver-visible")
    }

    func testCaptureBlockReasonDetectsScreenSaverBundle() {
        let reason = CGWindowListCapture.captureBlockReason(
            ownerName: "Window Server",
            bundleID: "com.apple.ScreenSaver.Engine"
        )
        XCTAssertEqual(reason, "screensaver-visible")
    }

    func testCaptureBlockReasonIgnoresNormalApplications() {
        let reason = CGWindowListCapture.captureBlockReason(ownerName: "Brave Browser", bundleID: "com.brave.Browser")
        XCTAssertNil(reason)
    }

    func testExcludedAppBlockReasonDetectsFullscreenWindow() {
        let reason = CGWindowListCapture.excludedAppCaptureBlockReason(
            bundleID: "com.example.TuningBack",
            windowBounds: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
            displayBounds: CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
        )

        XCTAssertEqual(reason, "excluded-app-visible:com.example.TuningBack")
    }

    func testExcludedAppBlockReasonIgnoresSmallWindows() {
        let reason = CGWindowListCapture.excludedAppCaptureBlockReason(
            bundleID: "com.example.PasswordApp",
            windowBounds: CGRect(x: 100, y: 100, width: 400, height: 300),
            displayBounds: CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
        )

        XCTAssertNil(reason)
    }

    func testExcludedAppBlockReasonUsesDisplayIntersection() {
        let reason = CGWindowListCapture.excludedAppCaptureBlockReason(
            bundleID: "com.example.TuningBack",
            windowBounds: CGRect(x: 1_920, y: 0, width: 1_920, height: 1_080),
            displayBounds: CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
        )

        XCTAssertNil(reason)
    }
}

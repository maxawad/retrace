import XCTest
import AppKit
import Combine
import Shared
import App
@testable import Retrace

final class TimelineCoordinatorVisibilityDecisionTests: XCTestCase {
    func testRejectsStaleVisibleUpdateAfterHideAdvancesGeneration() {
        XCTAssertFalse(
            TimelineWindowController.shouldApplyDeferredCoordinatorTimelineVisible(
                requestedVisible: true,
                requestGeneration: 3,
                currentGeneration: 4,
                isTimelineVisibleToClients: false,
                windowExists: false,
                windowVisible: false,
                windowMiniaturized: false,
                appHidden: false
            )
        )
    }

    func testRejectsVisibleUpdateWhenWindowIsHidden() {
        XCTAssertFalse(
            TimelineWindowController.shouldApplyDeferredCoordinatorTimelineVisible(
                requestedVisible: true,
                requestGeneration: 4,
                currentGeneration: 4,
                isTimelineVisibleToClients: true,
                windowExists: true,
                windowVisible: false,
                windowMiniaturized: false,
                appHidden: false
            )
        )
    }

    func testAppliesVisibleUpdateOnlyForCurrentVisibleWindow() {
        XCTAssertTrue(
            TimelineWindowController.shouldApplyDeferredCoordinatorTimelineVisible(
                requestedVisible: true,
                requestGeneration: 4,
                currentGeneration: 4,
                isTimelineVisibleToClients: true,
                windowExists: true,
                windowVisible: true,
                windowMiniaturized: false,
                appHidden: false
            )
        )
    }

    func testAppliesHiddenUpdateWhenCurrentWindowIsNotVisible() {
        XCTAssertTrue(
            TimelineWindowController.shouldApplyDeferredCoordinatorTimelineVisible(
                requestedVisible: false,
                requestGeneration: 4,
                currentGeneration: 4,
                isTimelineVisibleToClients: true,
                windowExists: true,
                windowVisible: false,
                windowMiniaturized: false,
                appHidden: false
            )
        )
    }

    func testRejectsStaleHiddenUpdateAfterShowAdvancesGeneration() {
        XCTAssertFalse(
            TimelineWindowController.shouldApplyDeferredCoordinatorTimelineVisible(
                requestedVisible: false,
                requestGeneration: 3,
                currentGeneration: 4,
                isTimelineVisibleToClients: true,
                windowExists: true,
                windowVisible: true,
                windowMiniaturized: false,
                appHidden: false
            )
        )
    }

    func testMovesPreparedTimelineForDisplayChangeOnlyWhenHidden() {
        XCTAssertTrue(
            TimelineWindowController.shouldMovePreparedTimelineForActiveDisplayChange(
                presentationState: .hidden,
                windowExists: true,
                windowVisible: false,
                windowMiniaturized: false,
                windowAlphaValue: 0,
                appHidden: false,
                isHiding: false
            )
        )
    }

    func testDoesNotMoveVisibleTimelineForActiveDisplayChange() {
        XCTAssertFalse(
            TimelineWindowController.shouldMovePreparedTimelineForActiveDisplayChange(
                presentationState: .visible,
                windowExists: true,
                windowVisible: true,
                windowMiniaturized: false,
                windowAlphaValue: 1,
                appHidden: false,
                isHiding: false
            )
        )
    }

    func testDoesNotMoveActuallyVisibleTimelineEvenIfStateIsStaleHidden() {
        XCTAssertFalse(
            TimelineWindowController.shouldMovePreparedTimelineForActiveDisplayChange(
                presentationState: .hidden,
                windowExists: true,
                windowVisible: true,
                windowMiniaturized: false,
                windowAlphaValue: 1,
                appHidden: false,
                isHiding: false
            )
        )
    }
}

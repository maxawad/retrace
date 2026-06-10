import XCTest
import AppKit
import Combine
import Shared
import App
@testable import Retrace

@MainActor
final class TimelineRefreshTrimRegressionTests: XCTestCase {
    func testRefreshFrameDataTrimPreservesNewestIndexAfterAppend() async {
        let viewModel = SimpleTimelineViewModel(coordinator: AppCoordinator())
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

        viewModel.frames = (0..<100).map { offset in
            makeTimelineFrame(
                id: Int64(offset + 1),
                timestamp: baseDate.addingTimeInterval(TimeInterval(offset)),
                frameIndex: offset,
                processingStatus: 4
            )
        }
        viewModel.currentIndex = 95

        viewModel.test_refreshFrameDataHooks.getMostRecentFramesWithVideoInfo = { limit, _ in
            XCTAssertEqual(limit, 50)
            return (100..<112).reversed().map { offset in
                let timestamp = baseDate.addingTimeInterval(TimeInterval(offset))
                return self.makeFrameWithVideoInfo(
                    id: Int64(offset + 1),
                    timestamp: timestamp,
                    frameIndex: offset,
                    processingStatus: 4
                )
            }
        }

        await viewModel.refreshFrameData(navigateToNewest: true)

        XCTAssertEqual(viewModel.frames.count, 100)
        XCTAssertEqual(viewModel.currentIndex, 99)
        XCTAssertEqual(
            viewModel.currentTimelineFrame?.frame.timestamp,
            baseDate.addingTimeInterval(111)
        )
    }

    func testRefreshFrameDataDefersTrimWhileActivelyScrollingAndAnchorsAfterScrollEnds() async {
        let viewModel = SimpleTimelineViewModel(coordinator: AppCoordinator())
        let baseDate = Date(timeIntervalSince1970: 1_700_020_000)

        viewModel.frames = (0..<100).map { offset in
            makeTimelineFrame(
                id: Int64(offset + 1),
                timestamp: baseDate.addingTimeInterval(TimeInterval(offset)),
                frameIndex: offset,
                processingStatus: 4
            )
        }
        viewModel.currentIndex = 95
        viewModel.isActivelyScrolling = true

        viewModel.test_refreshFrameDataHooks.getMostRecentFramesWithVideoInfo = { limit, _ in
            XCTAssertEqual(limit, 50)
            return (100..<112).reversed().map { offset in
                let timestamp = baseDate.addingTimeInterval(TimeInterval(offset))
                return self.makeFrameWithVideoInfo(
                    id: Int64(offset + 1),
                    timestamp: timestamp,
                    frameIndex: offset,
                    processingStatus: 4
                )
            }
        }

        await viewModel.refreshFrameData(navigateToNewest: true)

        // While scrubbing, trim should be deferred (window can exceed max in-memory size).
        XCTAssertEqual(viewModel.frames.count, 112)
        XCTAssertEqual(viewModel.currentIndex, 111)
        XCTAssertEqual(viewModel.currentTimelineFrame?.frame.id.value, 112)

        // Scroll end should apply deferred trim and keep playhead anchored to the same frame.
        viewModel.isActivelyScrolling = false

        XCTAssertEqual(viewModel.frames.count, 100)
        XCTAssertEqual(viewModel.currentIndex, 99)
        XCTAssertEqual(viewModel.currentTimelineFrame?.frame.id.value, 112)
        XCTAssertEqual(
            viewModel.currentTimelineFrame?.frame.timestamp,
            baseDate.addingTimeInterval(111)
        )
    }

    func testDeferredTrimTracksLatestScrubbedFrameBeforeScrollEnds() async {
        let viewModel = SimpleTimelineViewModel(coordinator: AppCoordinator())
        let baseDate = Date(timeIntervalSince1970: 1_700_030_000)

        viewModel.frames = (0..<100).map { offset in
            makeTimelineFrame(
                id: Int64(offset + 1),
                timestamp: baseDate.addingTimeInterval(TimeInterval(offset)),
                frameIndex: offset,
                processingStatus: 4
            )
        }
        viewModel.currentIndex = 95
        viewModel.isActivelyScrolling = true

        viewModel.test_refreshFrameDataHooks.getMostRecentFramesWithVideoInfo = { limit, _ in
            XCTAssertEqual(limit, 50)
            return (100..<112).reversed().map { offset in
                let timestamp = baseDate.addingTimeInterval(TimeInterval(offset))
                return self.makeFrameWithVideoInfo(
                    id: Int64(offset + 1),
                    timestamp: timestamp,
                    frameIndex: offset,
                    processingStatus: 4
                )
            }
        }

        await viewModel.refreshFrameData(navigateToNewest: true)

        XCTAssertEqual(viewModel.frames.count, 112)
        XCTAssertEqual(viewModel.currentIndex, 111)
        XCTAssertEqual(viewModel.currentTimelineFrame?.frame.id.value, 112)

        // Simulate the user continuing to scrub after the trim was deferred.
        viewModel.currentIndex = 95
        XCTAssertEqual(viewModel.currentTimelineFrame?.frame.id.value, 96)

        viewModel.isActivelyScrolling = false

        XCTAssertEqual(viewModel.frames.count, 100)
        XCTAssertEqual(viewModel.currentIndex, 83)
        XCTAssertEqual(viewModel.currentTimelineFrame?.frame.id.value, 96)
        XCTAssertEqual(
            viewModel.currentTimelineFrame?.frame.timestamp,
            baseDate.addingTimeInterval(95)
        )
    }

    func testRefreshFrameDataDoesNotAutoAdvanceToNewestAfterVisibleSessionScrubStartsDuringFetch() async {
        let viewModel = SimpleTimelineViewModel(coordinator: AppCoordinator())
        let baseDate = Date(timeIntervalSince1970: 1_700_035_000)
        let fetchStarted = expectation(description: "fetch started")
        var releaseFetchContinuation: CheckedContinuation<Void, Never>?

        viewModel.frames = (0..<100).map { offset in
            makeTimelineFrame(
                id: Int64(offset + 1),
                timestamp: baseDate.addingTimeInterval(TimeInterval(offset)),
                frameIndex: offset,
                processingStatus: 4
            )
        }
        viewModel.currentIndex = 76
        viewModel.isActivelyScrolling = true
        viewModel.resetVisibleSessionScrubTracking(reason: "unit-test")

        viewModel.test_refreshFrameDataHooks.getMostRecentFramesWithVideoInfo = { limit, _ in
            XCTAssertEqual(limit, 50)
            fetchStarted.fulfill()
            await withCheckedContinuation { continuation in
                releaseFetchContinuation = continuation
            }
            return (100..<103).reversed().map { offset in
                let timestamp = baseDate.addingTimeInterval(TimeInterval(offset))
                return self.makeFrameWithVideoInfo(
                    id: Int64(offset + 1),
                    timestamp: timestamp,
                    frameIndex: offset,
                    processingStatus: 4
                )
            }
        }

        let refreshTask = Task {
            await viewModel.refreshFrameData(navigateToNewest: true)
        }

        await fulfillment(of: [fetchStarted], timeout: 1.0)
        viewModel.markVisibleSessionScrubStarted(source: "unit-test")
        releaseFetchContinuation?.resume()
        await refreshTask.value

        XCTAssertEqual(viewModel.frames.count, 103)
        XCTAssertEqual(viewModel.currentIndex, 76)
        XCTAssertEqual(viewModel.currentTimelineFrame?.frame.id.value, 77)

        viewModel.isActivelyScrolling = false

        XCTAssertEqual(viewModel.frames.count, 100)
        XCTAssertEqual(viewModel.currentIndex, 73)
        XCTAssertEqual(viewModel.currentTimelineFrame?.frame.id.value, 77)
    }

    func testRefreshFrameDataDoesNotForceNewestReloadWhenNavigateToNewestIsFalseAndWindowIsStale() async {
        let viewModel = SimpleTimelineViewModel(coordinator: AppCoordinator())
        let baseDate = Date(timeIntervalSince1970: 1_700_100_000)

        viewModel.filterCriteria = FilterCriteria(selectedApps: ["com.google.Chrome"])
        viewModel.frames = (0..<100).map { offset in
            makeTimelineFrame(
                id: Int64(offset + 1),
                timestamp: baseDate.addingTimeInterval(TimeInterval(offset)),
                frameIndex: offset,
                processingStatus: 2
            )
        }
        viewModel.currentIndex = 10

        let originalFrameIDs = viewModel.frames.map(\.frame.id.value)
        let originalNewestTimestamp = viewModel.frames.last?.frame.timestamp

        viewModel.test_refreshFrameDataHooks.getMostRecentFramesWithVideoInfo = { limit, filters in
            XCTAssertEqual(limit, 50)
            XCTAssertTrue(filters.hasActiveFilters)
            return (200..<250).reversed().map { offset in
                let timestamp = baseDate.addingTimeInterval(TimeInterval(offset))
                return self.makeFrameWithVideoInfo(
                    id: Int64(offset + 1),
                    timestamp: timestamp,
                    frameIndex: offset,
                    processingStatus: 2
                )
            }
        }

        await viewModel.refreshFrameData(navigateToNewest: false, allowNearLiveAutoAdvance: false)

        XCTAssertEqual(viewModel.currentIndex, 10)
        XCTAssertEqual(viewModel.frames.count, 100)
        XCTAssertEqual(viewModel.frames.map(\.frame.id.value), originalFrameIDs)
        XCTAssertEqual(viewModel.frames.last?.frame.timestamp, originalNewestTimestamp)
    }

    func testRefreshFrameDataTreatsStaleLoadedTapeAsHistoricalEvenNearLoadedEdge() async {
        let viewModel = SimpleTimelineViewModel(coordinator: AppCoordinator())
        let baseDate = Date(timeIntervalSince1970: 1_700_200_000)

        viewModel.frames = (0..<100).map { offset in
            makeTimelineFrame(
                id: Int64(offset + 1),
                timestamp: baseDate.addingTimeInterval(TimeInterval(offset)),
                frameIndex: offset,
                processingStatus: 2
            )
        }
        viewModel.currentIndex = 95

        let originalFrameIDs = viewModel.frames.map(\.frame.id.value)
        let originalNewestTimestamp = viewModel.frames.last?.frame.timestamp
        var fetchInvocationCount = 0

        viewModel.test_refreshFrameDataHooks.now = {
            baseDate.addingTimeInterval(10 * 24 * 60 * 60)
        }
        viewModel.test_refreshFrameDataHooks.getMostRecentFramesWithVideoInfo = { _, _ in
            fetchInvocationCount += 1
            return []
        }

        await viewModel.refreshFrameData(
            navigateToNewest: false,
            allowNearLiveAutoAdvance: true,
            refreshPresentation: false
        )

        XCTAssertEqual(fetchInvocationCount, 0)
        XCTAssertEqual(viewModel.currentIndex, 95)
        XCTAssertEqual(viewModel.frames.map(\.frame.id.value), originalFrameIDs)
        XCTAssertEqual(viewModel.frames.last?.frame.timestamp, originalNewestTimestamp)
    }

    func testRefreshFrameDataHonorsPendingDisplayScopeReloadBeforeHistoricalFastPath() async {
        let viewModel = SimpleTimelineViewModel(coordinator: AppCoordinator())
        let baseDate = Date(timeIntervalSince1970: 1_700_300_000)
        let targetTimestamp = baseDate.addingTimeInterval(10)
        var windowFetchCount = 0

        viewModel.frames = (0..<100).map { offset in
            makeTimelineFrame(
                id: Int64(offset + 1),
                timestamp: baseDate.addingTimeInterval(TimeInterval(offset)),
                frameIndex: offset,
                processingStatus: 2,
                displayStableID: "display:main"
            )
        }
        viewModel.currentIndex = 10

        viewModel.applyDisplayScope(stableID: "display:secondary")
        viewModel.test_refreshFrameDataHooks.now = {
            baseDate.addingTimeInterval(10 * 24 * 60 * 60)
        }
        viewModel.test_windowFetchHooks.getFramesWithVideoInfo = { startDate, endDate, limit, filters, reason in
            windowFetchCount += 1
            XCTAssertEqual(reason, "reloadFramesAroundTimestamp")
            XCTAssertEqual(limit, 1000)
            XCTAssertLessThanOrEqual(startDate, targetTimestamp)
            XCTAssertGreaterThanOrEqual(endDate, targetTimestamp)
            XCTAssertEqual(filters.selectedDisplayStableIDs, ["display:secondary"])

            return (0..<100).map { offset in
                let timestamp = baseDate.addingTimeInterval(TimeInterval(offset))
                return self.makeFrameWithVideoInfo(
                    id: Int64(1_000 + offset),
                    timestamp: timestamp,
                    frameIndex: offset,
                    processingStatus: 4,
                    displayStableID: "display:secondary"
                )
            }
        }
        viewModel.test_refreshFrameDataHooks.getMostRecentFramesWithVideoInfo = { _, _ in
            XCTFail("display-scope refresh should reload around the existing timestamp")
            return []
        }

        await viewModel.refreshFrameData(
            navigateToNewest: false,
            allowNearLiveAutoAdvance: false,
            refreshPresentation: false
        )

        XCTAssertEqual(windowFetchCount, 1)
        XCTAssertEqual(viewModel.currentTimelineFrame?.frame.timestamp, targetTimestamp)
        XCTAssertEqual(viewModel.currentTimelineFrame?.frame.metadata.displayStableID, "display:secondary")
        XCTAssertTrue(viewModel.frames.allSatisfy { $0.frame.metadata.displayStableID == "display:secondary" })
    }

    func testInvalidateCachesAndReloadPreservesDisplayScope() async {
        let viewModel = SimpleTimelineViewModel(coordinator: AppCoordinator())
        let baseDate = Date(timeIntervalSince1970: 1_700_400_000)
        let reloadStarted = expectation(description: "scoped reload started")

        viewModel.frames = (0..<100).map { offset in
            makeTimelineFrame(
                id: Int64(offset + 1),
                timestamp: baseDate.addingTimeInterval(TimeInterval(offset)),
                frameIndex: offset,
                processingStatus: 2,
                displayStableID: "display:main"
            )
        }
        viewModel.currentIndex = 10
        viewModel.applyDisplayScope(stableID: "display:secondary")

        viewModel.test_windowFetchHooks.getFramesWithVideoInfo = { _, _, _, filters, reason in
            XCTAssertEqual(reason, "reloadFramesAroundTimestamp")
            XCTAssertEqual(filters.selectedDisplayStableIDs, ["display:secondary"])
            reloadStarted.fulfill()
            return (0..<100).map { offset in
                self.makeFrameWithVideoInfo(
                    id: Int64(2_000 + offset),
                    timestamp: baseDate.addingTimeInterval(TimeInterval(offset)),
                    frameIndex: offset,
                    processingStatus: 4,
                    displayStableID: "display:secondary"
                )
            }
        }

        viewModel.invalidateCachesAndReload()

        await fulfillment(of: [reloadStarted], timeout: 1.0)
        XCTAssertEqual(viewModel.filterCriteria.selectedDisplayStableIDs, ["display:secondary"])
        XCTAssertEqual(viewModel.pendingFilterCriteria.selectedDisplayStableIDs, ["display:secondary"])
    }

    private func makeTimelineFrame(
        id: Int64,
        timestamp: Date,
        frameIndex: Int,
        processingStatus: Int,
        displayStableID: String? = nil
    ) -> TimelineFrame {
        let frame = FrameReference(
            id: FrameID(value: id),
            timestamp: timestamp,
            segmentID: AppSegmentID(value: id),
            frameIndexInSegment: frameIndex,
            metadata: FrameMetadata(
                appBundleID: "test.app",
                appName: "Test App",
                displayID: 1,
                displayStableID: displayStableID
            )
        )

        return TimelineFrame(frame: frame, videoInfo: nil, processingStatus: processingStatus)
    }

    private func makeFrameWithVideoInfo(
        id: Int64,
        timestamp: Date,
        frameIndex: Int,
        processingStatus: Int,
        displayStableID: String? = nil
    ) -> FrameWithVideoInfo {
        let frame = FrameReference(
            id: FrameID(value: id),
            timestamp: timestamp,
            segmentID: AppSegmentID(value: id),
            frameIndexInSegment: frameIndex,
            metadata: FrameMetadata(
                appBundleID: "test.app",
                appName: "Test App",
                displayID: 1,
                displayStableID: displayStableID
            )
        )

        return FrameWithVideoInfo(frame: frame, videoInfo: nil, processingStatus: processingStatus)
    }
}

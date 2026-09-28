@testable import NestedPageViewController
import UIKit
import XCTest

@MainActor
final class NestedPageLayoutPositionTests: XCTestCase {
    func testTopRemainsExpandedWhenHeaderGrows() {
        let fixture = ScrollBehaviorFixture()
        fixture.coverHeight = 304
        fixture.host.updateLayouts()

        XCTAssertEqual(fixture.headerY, 0, accuracy: 0.001)
        XCTAssertEqual(fixture.pages.map { $0.scrollView.contentOffset.y }, [-348, -348])
        fixture.scroll(to: -328)
        XCTAssertEqual(fixture.headerY, -20, accuracy: 0.001)
        XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -328)
    }

    func testPinnedReadingPositionSurvivesGrowthAndShrink() {
        let fixture = ScrollBehaviorFixture()
        fixture.scroll(to: 140)
        for height: CGFloat in [304, 104, 204] {
            fixture.coverHeight = height
            fixture.host.updateLayouts()
            XCTAssertEqual(fixture.headerY, -height, accuracy: 0.001)
            XCTAssertEqual(fixture.pages.map { $0.scrollView.contentOffset.y }, [140, -44])
            XCTAssertTrue(fixture.host.isSticked)
            XCTAssertFalse(fixture.isHeaderAttachedToCurrentPage)
        }
        fixture.scroll(to: 141)
        XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -44)
    }

    func testPartiallyCollapsedHeaderKeepsCollapsedDistance() {
        let fixture = ScrollBehaviorFixture(contentTop: 32)
        fixture.scroll(to: -168)
        fixture.coverHeight = 304
        fixture.host.updateLayouts()

        XCTAssertEqual(fixture.headerY, -48, accuracy: 0.001)
        XCTAssertEqual(fixture.pages.map { $0.scrollView.contentOffset.y }, [-268, -268])
        fixture.scroll(to: -267)
        XCTAssertEqual(fixture.headerY, -49, accuracy: 0.001)
        XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -267)
    }

    func testHoverAndIndividualPagePositionsSurviveResizeAndSwitching() {
        let fixture = ScrollBehaviorFixture()
        fixture.enterHover()
        fixture.coverHeight = 304
        fixture.host.updateLayouts()

        XCTAssertEqual(fixture.headerY, -104, accuracy: 0.001)
        XCTAssertEqual(fixture.pages.map { $0.scrollView.contentOffset.y }, [-100, -244])
        fixture.host.scrollToPage(at: 1, animated: false)
        XCTAssertEqual(fixture.headerY, -104, accuracy: 0.001)
        fixture.host.scrollToPage(at: 0, animated: false)
        XCTAssertEqual(fixture.headerY, -104, accuracy: 0.001)
        fixture.scroll(to: -120)
        XCTAssertEqual(fixture.headerY, -104, accuracy: 0.001)
        fixture.scroll(to: -90)
        XCTAssertEqual(fixture.headerY, -134, accuracy: 0.001)
    }

    func testTabHeightChangeKeepsContentRelativeToTabBottom() {
        let fixture = ScrollBehaviorFixture()
        fixture.scroll(to: 140)
        fixture.tabHeight = 64
        fixture.host.updateLayouts()

        XCTAssertEqual(fixture.headerY, -204, accuracy: 0.001)
        XCTAssertEqual(fixture.pages.map { $0.scrollView.contentOffset.y }, [120, -64])
        // 内容坐标为 200 的点，更新前后距离 tabStrip 底部都为 16 点。
        XCTAssertEqual(200 - fixture.pages[0].scrollView.contentOffset.y - 64, 16)
    }

    func testDisablingPositionKeepingResetsAllPages() {
        let fixture = ScrollBehaviorFixture()
        fixture.enterHover()
        fixture.coverHeight = 304
        fixture.host.keepsContentScrollPosition = false
        fixture.host.updateLayouts()
        XCTAssertEqual(fixture.pages.map { $0.scrollView.contentOffset.y }, [-348, -348])
    }

    func testStickyOffsetAndContentOriginRemainSupported() {
        let fixture = ScrollBehaviorFixture(contentTop: 32, stickyOffset: 36)
        fixture.scroll(to: 100)
        fixture.coverHeight = 304
        fixture.host.updateLayouts()

        XCTAssertEqual(fixture.headerY, -236, accuracy: 0.001)
        XCTAssertEqual(fixture.pages.map { $0.scrollView.contentOffset.y }, [100, -80])
        XCTAssertFalse(fixture.host.isSticked) // 保留既有公开状态语义。
        fixture.scroll(to: 99)
        XCTAssertEqual(fixture.headerY, -236, accuracy: 0.001)
    }

    func testUnpaddedShortContentExpandsHeaderWhenOldPositionIsUnreachable() {
        let fixture = ScrollBehaviorFixture()
        fixture.coverHeight = 800
        fixture.host.updateLayouts()
        fixture.host.autoAdjustsContentSizeMinimumHeight = false
        fixture.pages.forEach { $0.scrollView.contentSize.height = 100 }
        fixture.scroll(to: -644)
        XCTAssertEqual(fixture.headerY, -200, accuracy: 0.001)

        fixture.coverHeight = 100
        fixture.host.updateLayouts()
        XCTAssertEqual(fixture.headerY, 0, accuracy: 0.001)
        XCTAssertEqual(fixture.pages.map { $0.scrollView.contentOffset.y }, [-144, -144])
        fixture.host.scrollToPage(at: 1, animated: false)
        XCTAssertEqual(fixture.headerY, 0, accuracy: 0.001)
    }

    func testPaddedShortContentKeepsPinnedPosition() {
        let fixture = ScrollBehaviorFixture()
        fixture.pages.forEach { $0.scrollView.contentSize.height = 100 }
        fixture.scroll(to: -44)
        fixture.coverHeight = 304
        fixture.host.updateLayouts()

        XCTAssertEqual(fixture.headerY, -304, accuracy: 0.001)
        XCTAssertEqual(fixture.pages.map { $0.scrollView.contentOffset.y }, [-44, -44])
        fixture.host.scrollToPage(at: 1, animated: false)
        XCTAssertEqual(fixture.headerY, -304, accuracy: 0.001)
    }

    func testShrinkingBelowPreviousCollapsePinsAtNewBoundary() {
        let fixture = ScrollBehaviorFixture()
        fixture.scroll(to: -68)
        fixture.coverHeight = 100
        fixture.host.updateLayouts()
        XCTAssertEqual(fixture.headerY, -100, accuracy: 0.001)
        XCTAssertEqual(fixture.pages.map { $0.scrollView.contentOffset.y }, [-44, -44])
    }

    func testLazyPageStartsAtRestoredHeaderPosition() {
        let fixture = ScrollBehaviorFixture(preloadsPages: false)
        fixture.scroll(to: 140)
        fixture.coverHeight = 304
        fixture.host.updateLayouts()
        XCTAssertFalse(fixture.pages[1].isViewLoaded)
        XCTAssertTrue(fixture.host.loadViewController(at: 1))
        XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -44)
    }

    func testFixedHeaderPreservesContentRelativeToItsBottom() {
        let fixture = ScrollBehaviorFixture()
        fixture.host.headerAlwaysFixed = true
        fixture.scroll(to: 100)
        fixture.coverHeight = 304
        fixture.host.updateLayouts()

        XCTAssertEqual(fixture.headerY, 0, accuracy: 0.001)
        XCTAssertEqual(fixture.pages.map { $0.scrollView.contentOffset.y }, [0, -348])
        fixture.scroll(to: 1)
        XCTAssertEqual(fixture.headerY, 0, accuracy: 0.001)
    }

    func testAddingCoverDistinguishesTopFromScrolledContent() {
        for readsContent in [false, true] {
            let fixture = ScrollBehaviorFixture()
            fixture.coverHeight = 0
            fixture.host.updateLayouts()
            if readsContent { fixture.scroll(to: 100) }
            fixture.coverHeight = 204
            fixture.host.updateLayouts()
            XCTAssertEqual(fixture.headerY, readsContent ? -204 : 0, accuracy: 0.001)
            XCTAssertEqual(fixture.pages[0].scrollView.contentOffset.y, readsContent ? 100 : -248)
        }
    }

    func testBottomClampsToReachableRange() {
        let fixture = ScrollBehaviorFixture()
        fixture.scroll(to: 1299)
        fixture.tabHeight = 4
        fixture.host.updateLayouts()
        XCTAssertEqual(fixture.pages[0].scrollView.contentOffset.y, 1300)
        XCTAssertEqual(fixture.headerY, -204, accuracy: 0.001)
    }

    func testPreservationStillCallsExistingOverrideWithoutExtraScrollCallbacks() {
        let host = LayoutCountingController()
        let fixture = ScrollBehaviorFixture(host: host)
        fixture.scroll(to: 140)
        fixture.coverHeight = 304
        let count = host.layoutCount
        fixture.events.removeAll()
        host.updateLayouts()

        XCTAssertEqual(host.layoutCount, count + 1)
        XCTAssertTrue(fixture.events.isEmpty)
        XCTAssertEqual(fixture.pages[0].scrollView.contentOffset.y, 140)
    }

    func testEnablingPositionKeepingControlsBothLayoutAndPageSwitching() {
        let fixture = ScrollBehaviorFixture(keepsPosition: false)
        fixture.scroll(to: 140)
        fixture.coverHeight = 304
        fixture.host.updateLayouts()
        XCTAssertEqual(fixture.pages.map { $0.scrollView.contentOffset.y }, [-348, -348])

        fixture.host.keepsContentScrollPosition = true
        fixture.enterHover()
        fixture.coverHeight = 204
        fixture.host.updateLayouts()
        XCTAssertEqual(fixture.pages.map { $0.scrollView.contentOffset.y }, [100, -44])
        fixture.host.scrollToPage(at: 1, animated: false)
        fixture.scroll(to: -144)
        fixture.host.scrollToPage(at: 0, animated: false)
        XCTAssertEqual(fixture.pages[0].scrollView.contentOffset.y, 0)
        XCTAssertEqual(fixture.headerY, -104, accuracy: 0.001)
    }

    func testRepeatedFractionalHeightUpdatesDoNotDrift() {
        let fixture = ScrollBehaviorFixture(stickyOffset: 35.1)
        fixture.coverHeight = 203.3
        fixture.tabHeight = 43.7
        fixture.host.updateLayouts()
        fixture.scroll(to: 140.2)
        let originalOffset = fixture.pages[0].scrollView.contentOffset.y
        for _ in 0..<10 {
            for height: CGFloat in [303.7, 103.1, 203.3] {
                fixture.coverHeight = height
                fixture.host.updateLayouts()
                XCTAssertEqual(fixture.pages[0].scrollView.contentOffset.y, originalOffset, accuracy: 0.001)
                XCTAssertEqual(fixture.headerY, -(height - 35.1), accuracy: 0.001)
            }
        }
    }

    func testAnimatedUpdateKeepsHoverAfterAnimationCompletes() {
        let fixture = ScrollBehaviorFixture()
        fixture.enterHover()
        fixture.coverHeight = 304
        let finished = expectation(description: "height update completed")
        UIView.animate(withDuration: 0.25) {
            fixture.host.updateLayouts()
        } completion: { _ in
            XCTAssertEqual(fixture.headerY, -104, accuracy: 0.001)
            XCTAssertEqual(fixture.pages[0].scrollView.contentOffset.y, -100)
            fixture.scroll(to: -90)
            XCTAssertEqual(fixture.headerY, -114, accuracy: 0.001)
            finished.fulfill()
        }
        wait(for: [finished], timeout: 2)
    }

    func testUpdateDuringHorizontalTransitionFinishesAtCurrentPage() {
        let fixture = ScrollBehaviorFixture()
        fixture.scroll(to: 140)
        fixture.host.containerScrollView.contentOffset.x = 195
        fixture.coverHeight = 304
        fixture.host.updateLayouts()
        XCTAssertEqual(fixture.host.containerScrollView.contentOffset.x, 0)
        XCTAssertEqual(fixture.headerY, -304, accuracy: 0.001)
        fixture.scroll(to: -144)
        XCTAssertEqual(fixture.headerY, -204, accuracy: 0.001)
    }
}

private final class LayoutCountingController: NestedPageViewController {
    var layoutCount = 0

    override func updateLayouts() {
        layoutCount += 1
        super.updateLayouts()
    }
}

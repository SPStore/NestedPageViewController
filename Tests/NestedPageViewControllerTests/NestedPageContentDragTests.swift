@testable import NestedPageViewController
import UIKit
import XCTest

@MainActor
final class NestedPageContentDragTests: XCTestCase {
    func testDisabledByDefaultKeepsContinuousScrolling() {
        let f = ScrollBehaviorFixture()
        XCTAssertFalse(f.host.requiresNewDragToExpandHeader)
        f.scroll(to: 100)
        f.pages[0].scrollView.simulatedPan.send(.began)
        f.scroll(to: -144)
        XCTAssertEqual(f.headerY, -104, accuracy: 0.001)
    }

    func testFirstDragStopsAtTopAndNextDragExpandsWithoutTransientCallbacks() {
        let f = ScrollBehaviorFixture()
        f.host.requiresNewDragToExpandHeader = true
        f.scroll(to: 100)
        let pan = f.pages[0].scrollView.simulatedPan
        pan.send(.began)
        pan.send(.changed)
        f.events.removeAll()
        for y: CGFloat in [-84, -160, -300] {
            f.scroll(to: y)
            XCTAssertEqual(f.pages[0].scrollView.contentOffset.y, -44, accuracy: 0.001)
            XCTAssertEqual(f.headerY, -204, accuracy: 0.001)
            XCTAssertEqual(f.pages[1].scrollView.contentOffset.y, -44, accuracy: 0.001)
        }
        XCTAssertFalse(f.events.isEmpty)
        XCTAssertTrue(f.events.allSatisfy { $0.headerOffset == 204 && $0.pageOffsets == [-44, -44] })
        // 同一手势到顶后反向上滑应立即响应，再次下拉仍停在原边界。
        f.scroll(to: 20)
        XCTAssertEqual(f.pages[0].scrollView.contentOffset.y, 20)
        f.scroll(to: -144)
        XCTAssertEqual(f.headerY, -204, accuracy: 0.001)
        pan.send(.ended)
        pan.send(.began)
        f.scroll(to: -144)
        XCTAssertEqual(f.headerY, -104, accuracy: 0.001)
    }

    func testDecelerationCannotExpandUntilAnotherDrag() {
        let f = ScrollBehaviorFixture()
        f.host.requiresNewDragToExpandHeader = true
        f.scroll(to: 100)
        let scroll = f.pages[0].scrollView
        scroll.simulatedPan.send(.began)
        f.scroll(to: 10)
        scroll.simulatedPan.send(.ended)
        scroll.simulatesDeceleration = true
        scroll.simulatedPan.send(.possible) // UIKit 可能在减速时已重置 pan。
        f.scroll(to: -300)
        XCTAssertEqual(scroll.contentOffset.y, -44, accuracy: 0.001)
        XCTAssertEqual(f.headerY, -204, accuracy: 0.001)
        scroll.simulatesDeceleration = false
        scroll.simulatedPan.send(.began)
        f.scroll(to: -144)
        XCTAssertEqual(f.headerY, -104, accuracy: 0.001)
    }

    func testDragStartingAtTopOrBeforePinningCanExpandContinuously() {
        for initial: CGFloat in [-44, -144] {
            let f = ScrollBehaviorFixture()
            f.host.requiresNewDragToExpandHeader = true
            f.scroll(to: initial)
            f.pages[0].scrollView.simulatedPan.send(.began)
            f.scroll(to: 100) // 本轮中途上滑吸顶也不重新锁定。
            f.scroll(to: -248)
            XCTAssertEqual(f.headerY, 0, accuracy: 0.001)
        }
    }

    func testStickyOffsetAndInsetContentOriginUseVisualPinning() {
        let f = ScrollBehaviorFixture(contentTop: 32, stickyOffset: 36)
        f.host.requiresNewDragToExpandHeader = true
        f.scroll(to: 100)
        XCTAssertFalse(f.host.isSticked) // 既有公开标记不代表带 stickyOffset 的视觉吸顶。
        f.pages[0].scrollView.simulatedPan.send(.began)
        f.scroll(to: -200)
        XCTAssertEqual(f.pages[0].scrollView.contentOffset.y, -80, accuracy: 0.001)
        XCTAssertEqual(f.headerY, -136, accuracy: 0.001)
    }

    func testOptionalContentStartKeepsSharedContentCollapsed() {
        let f = ScrollBehaviorFixture()
        f.pages[0].nestedPageContentStartY = 144
        f.host.requiresNewDragToExpandHeader = true
        f.scroll(to: 300)
        let pan = f.pages[0].scrollView.simulatedPan
        pan.send(.began)
        f.scroll(to: -144)
        XCTAssertEqual(f.pages[0].scrollView.contentOffset.y, 100, accuracy: 0.001)
        pan.send(.ended)
        pan.send(.began)
        f.scroll(to: 60)
        XCTAssertEqual(f.pages[0].scrollView.contentOffset.y, 60, accuracy: 0.001)
        f.scroll(to: -144)
        XCTAssertEqual(f.headerY, -104, accuracy: 0.001)
    }

    func testEachPageUsesItsOwnBoundaryAndPagingClearsPreviousDrag() {
        let f = ScrollBehaviorFixture()
        f.host.requiresNewDragToExpandHeader = true
        f.pages[0].nestedPageContentStartY = 144
        f.scroll(to: 300)
        f.pages[0].scrollView.simulatedPan.send(.began)
        f.host.scrollToPage(at: 1, animated: false)
        f.scroll(to: 100)
        f.pages[1].scrollView.simulatedPan.send(.began)
        f.scroll(to: -144)
        XCTAssertEqual(f.pages[1].scrollView.contentOffset.y, -44, accuracy: 0.001)
        f.pages[1].scrollView.simulatedPan.send(.ended)
        f.pages[1].scrollView.simulatedPan.send(.began)
        f.scroll(to: -144)
        XCTAssertEqual(f.headerY, -104, accuracy: 0.001)
        f.host.scrollToPage(at: 0, animated: false)
        f.pages[0].scrollView.contentOffset.y = -248
        XCTAssertEqual(f.headerY, 0, accuracy: 0.001)
    }

    func testProgrammaticExpansionAndLayoutDoNotInheritDragBoundary() {
        for operation in 0..<3 {
            let f = ScrollBehaviorFixture()
            f.host.requiresNewDragToExpandHeader = true
            f.scroll(to: 100)
            f.pages[0].scrollView.simulatedPan.send(.began)
            switch operation {
            case 0: f.host.scrollToTop(animated: false)
            case 1: f.host.setHeaderExpansionProgress(1)
            default:
                f.host.keepsContentScrollPosition = false
                f.host.updateLayouts()
            }
            XCTAssertEqual(f.headerY, 0, accuracy: 0.001)
        }
    }

    func testDisablingOrCancellingReleasesBoundary() {
        for disable in [false, true] {
            let f = ScrollBehaviorFixture()
            f.host.requiresNewDragToExpandHeader = true
            f.scroll(to: 100)
            f.pages[0].scrollView.simulatedPan.send(.began)
            if disable { f.host.requiresNewDragToExpandHeader = false }
            else { f.pages[0].scrollView.simulatedPan.send(.cancelled) }
            f.scroll(to: -144)
            XCTAssertEqual(f.headerY, -104, accuracy: 0.001)
        }
    }

    func testFixedOrAbsentCoverDoesNotAddArtificialStop() {
        for fixed in [false, true] {
            let f = ScrollBehaviorFixture()
            f.host.requiresNewDragToExpandHeader = true
            if fixed { f.host.headerAlwaysFixed = true }
            else { f.coverHeight = 0 }
            f.host.updateLayouts()
            f.scroll(to: 100)
            f.pages[0].scrollView.simulatedPan.send(.began)
            f.scroll(to: -f.host.headerHeight - 40)
            XCTAssertEqual(f.pages[0].scrollView.contentOffset.y, -f.host.headerHeight - 40, accuracy: 0.001)
        }
    }

    func testUnloadingAndRebuildingRemovesOldPanTargets() {
        let f = ScrollBehaviorFixture()
        let pan = f.pages[1].scrollView.simulatedPan
        XCTAssertTrue(pan.hasTarget)
        XCTAssertTrue(f.host.unloadViewController(at: 1))
        XCTAssertFalse(pan.hasTarget)
        XCTAssertTrue(f.host.loadViewController(at: 1))
        XCTAssertTrue(pan.hasTarget)
        f.host.rebuildPages()
        XCTAssertTrue(pan.hasTarget)
    }
}

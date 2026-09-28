@testable import NestedPageViewController
import UIKit
import XCTest

/// 记录重构前的行为，包括已有的状态回报语义，不在结构调整中顺手修正。
@MainActor
final class NestedPageScrollBehaviorTests: XCTestCase {
    func testNormalScrollSynchronizesHeaderAndOtherPages() {
        let fixture = ScrollBehaviorFixture()
        fixture.scroll(to: -168)

        XCTAssertEqual(fixture.headerY, -80, accuracy: 0.001)
        XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -168)
        XCTAssertFalse(fixture.host.isSticked)
        XCTAssertTrue(fixture.isHeaderAttachedToCurrentPage)
    }

    func testPinnedContentScrollDoesNotMoveOtherPages() {
        let fixture = ScrollBehaviorFixture()
        fixture.scroll(to: -44)
        fixture.scroll(to: 140)

        XCTAssertEqual(fixture.headerY, -204, accuracy: 0.001)
        XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -44)
        XCTAssertTrue(fixture.host.isSticked)
        XCTAssertFalse(fixture.isHeaderAttachedToCurrentPage)
    }

    func testPageSwitchPreservesPartiallyExpandedHeaderAndListPosition() {
        let fixture = ScrollBehaviorFixture()
        fixture.enterHover()

        XCTAssertEqual(fixture.host.currentIndex, 0)
        XCTAssertEqual(fixture.headerY, -104, accuracy: 0.001)
        XCTAssertEqual(fixture.pages[0].scrollView.contentOffset.y, 0)
        XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -144)
        XCTAssertTrue(fixture.isHeaderAttachedToCurrentPage)
        XCTAssertFalse(fixture.host.isSticked)

        fixture.scroll(to: -20)
        XCTAssertEqual(fixture.headerY, -104, accuracy: 0.001)
        fixture.scroll(to: 10)
        XCTAssertEqual(fixture.headerY, -134, accuracy: 0.001)
        XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -114)
    }

    func testDisablingPositionKeepingAlignsInactivePageWithHeader() {
        let fixture = ScrollBehaviorFixture(keepsPosition: false)
        fixture.enterHover()

        XCTAssertEqual(fixture.pages[0].scrollView.contentOffset.y, -144)
        XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -144)
        XCTAssertEqual(fixture.headerY, -104, accuracy: 0.001)
    }

    func testHoverCanRequireTouchingHeaderBeforeMovingUp() {
        let fixture = ScrollBehaviorFixture()
        fixture.host.headerMovesOnlyWhenTouchingHeaderDuringHover = true
        fixture.enterHover()
        fixture.scroll(to: 10)
        XCTAssertEqual(fixture.headerY, -104, accuracy: 0.001)

        let pageHeader = fixture.header.superview as? NestedPageHeaderView
        XCTAssertNotNil(pageHeader)
        pageHeader?.isHitted = true
        fixture.scroll(to: 30)
        XCTAssertEqual(fixture.headerY, -124, accuracy: 0.001)
    }

    func testTopBounceDoesNotTranslateInactivePages() {
        for bounces in [false, true] {
            let fixture = ScrollBehaviorFixture(headerBounces: bounces)
            fixture.scroll(to: -288)
            XCTAssertEqual(fixture.headerY, bounces ? 40 : 0, accuracy: 0.001)
            XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -248)
            fixture.scroll(to: -248)
            XCTAssertEqual(fixture.headerY, 0, accuracy: 0.001)
            XCTAssertTrue(fixture.isHeaderAttachedToCurrentPage)
        }
    }

    func testFixedHeaderDoesNotEmitNormalScrollCallbacks() {
        let fixture = ScrollBehaviorFixture()
        fixture.host.headerAlwaysFixed = true
        fixture.events.removeAll()
        fixture.scroll(to: 100)

        XCTAssertEqual(fixture.headerY, 0, accuracy: 0.001)
        XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -248)
        XCTAssertTrue(fixture.events.isEmpty)
    }

    func testStickyOffsetPreservesExistingReportedStickSemantics() {
        let fixture = ScrollBehaviorFixture(stickyOffset: 36)
        fixture.scroll(to: -80)

        XCTAssertEqual(fixture.headerY, -168, accuracy: 0.001)
        XCTAssertFalse(fixture.isHeaderAttachedToCurrentPage)
        // 既有公开状态使用 pinY <= -coverHeight，与视觉吸顶判定并不完全相同。
        XCTAssertFalse(fixture.host.isSticked)
        XCTAssertEqual(fixture.events.last?.isSticked, false)
    }

    func testInsetContentOriginPreservesExistingCoordinatesAndReportedState() {
        let fixture = ScrollBehaviorFixture(contentTop: 32)
        fixture.scroll(to: -44)

        XCTAssertEqual(fixture.headerY, -172, accuracy: 0.001)
        XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -44)
        XCTAssertFalse(fixture.host.isSticked)
        XCTAssertEqual(fixture.events.last?.headerOffset ?? 0, 204, accuracy: 0.001)
    }

    func testLazyPageStartsAtLastSynchronizedPinPosition() {
        for contentTop: CGFloat in [0, 32] {
            let fixture = ScrollBehaviorFixture(preloadsPages: false, contentTop: contentTop)
            XCTAssertFalse(fixture.pages[1].isViewLoaded)
            fixture.scroll(to: -168)
            XCTAssertTrue(fixture.host.loadViewController(at: 1))
            XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -168)
        }
    }

    func testLayoutResetClearsHoverHistoryAndResetsAllOffsets() {
        let fixture = ScrollBehaviorFixture()
        fixture.enterHover()
        fixture.coverHeight = 120
        fixture.host.updateLayouts()

        XCTAssertEqual(fixture.pages[0].scrollView.contentOffset.y, -164)
        XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -164)
        fixture.scroll(to: -124)
        XCTAssertEqual(fixture.headerY, -40, accuracy: 0.001)
        XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -124)
        fixture.host.scrollToPage(at: 1, animated: false)
        XCTAssertEqual(fixture.headerY, -40, accuracy: 0.001)
    }

    func testLayoutResetDoesNotEagerlyRecomputeReportedStickFlag() {
        let fixture = ScrollBehaviorFixture()
        fixture.scroll(to: 100)
        XCTAssertTrue(fixture.host.isSticked)
        fixture.host.updateLayouts()
        // 保持旧实现的通知时机：布局重置本身不发布新的纵向滚动状态。
        XCTAssertTrue(fixture.host.isSticked)
        fixture.scroll(to: -247)
        XCTAssertFalse(fixture.host.isSticked)
    }

    func testLayoutTransactionSuppressesVerticalCoordination() {
        let fixture = ScrollBehaviorFixture()
        fixture.events.removeAll()
        fixture.host.isUpdatingLayouts = true
        fixture.scroll(to: 100)
        // 协调器不介入时，仍挂在列表里的头部会随 UIKit 的 contentOffset 自然移动。
        XCTAssertEqual(fixture.headerY, -348, accuracy: 0.001)
        XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -248)
        XCTAssertTrue(fixture.events.isEmpty)

        fixture.host.isUpdatingLayouts = false
        fixture.scroll(to: 101)
        XCTAssertTrue(fixture.host.isSticked)
        XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -44)
    }

    func testHorizontalTransitionSuppressesVerticalCoordinationUntilPageArrival() {
        let fixture = ScrollBehaviorFixture()
        fixture.host.containerScrollView.contentOffset.x = 195
        fixture.events.removeAll()
        fixture.scroll(to: 100)
        XCTAssertEqual(fixture.headerY, 0, accuracy: 0.001)
        XCTAssertTrue(fixture.events.isEmpty)

        fixture.host.scrollToPage(at: 1, animated: false)
        XCTAssertEqual(fixture.host.currentIndex, 1)
        XCTAssertEqual(fixture.headerY, 0, accuracy: 0.001)
        fixture.scroll(to: -168)
        XCTAssertEqual(fixture.headerY, -80, accuracy: 0.001)
    }

    func testDelegateObservesAlreadySynchronizedPageOffsets() {
        let fixture = ScrollBehaviorFixture()
        fixture.events.removeAll()
        fixture.scroll(to: -168)

        XCTAssertEqual(fixture.events.count, 1)
        XCTAssertEqual(fixture.events.last?.pageOffsets, [-168, -168])
        XCTAssertEqual(fixture.events.last?.headerOffset, 80)
        XCTAssertEqual(fixture.events.last?.isSticked, false)
    }

    func testDecelerationCanBeInterruptedAtOriginalTabOffset() {
        let fixture = ScrollBehaviorFixture(stickyOffset: 36)
        fixture.host.interruptsScrollingWhenTransitioningToFullStick = true
        fixture.pages[0].scrollView.simulatesDeceleration = true
        fixture.scroll(to: 100)

        // 保留原来的中断目标 -tabHeight，而非 -tabHeight - stickyOffset。
        XCTAssertEqual(fixture.pages[0].scrollView.contentOffset.y, -44)
        XCTAssertEqual(fixture.headerY, -168, accuracy: 0.001)
    }

    func testDeceleratingHoverReturnsHeaderToCurrentPageOnNextTurn() {
        let fixture = ScrollBehaviorFixture()
        fixture.enterHover()
        fixture.pages[0].scrollView.simulatesDeceleration = true
        fixture.scroll(to: -20)
        XCTAssertFalse(fixture.isHeaderAttachedToCurrentPage)
        fixture.pages[0].scrollView.simulatesDeceleration = false

        let returned = expectation(description: "header returned to current page")
        DispatchQueue.main.async {
            XCTAssertTrue(fixture.isHeaderAttachedToCurrentPage)
            XCTAssertEqual(fixture.headerY, -104, accuracy: 0.001)
            returned.fulfill()
        }
        wait(for: [returned], timeout: 2)
    }

    func testRepeatedSelectionStyleHeaderLayoutsDoNotRetainHoverState() {
        let fixture = ScrollBehaviorFixture()
        for _ in 0..<3 {
            fixture.enterHover()
            fixture.coverHeight = 0
            fixture.tabHeight = 0
            fixture.host.updateLayouts()
            fixture.coverHeight = 204
            fixture.tabHeight = 44
            fixture.host.updateLayouts()
            fixture.scroll(to: -44)
            fixture.host.scrollToPage(at: 1, animated: false)
            XCTAssertEqual(fixture.headerY, -204, accuracy: 0.001)
            XCTAssertEqual(fixture.pages[1].scrollView.contentOffset.y, -44)
            fixture.host.scrollToPage(at: 0, animated: false)
        }
    }
}

private final class ScrollBehaviorFixture: NestedPageViewControllerDataSource, NestedPageViewControllerDelegate {
    struct Event {
        let pageOffsets: [CGFloat]
        let headerOffset: CGFloat
        let isSticked: Bool
    }

    let host = NestedPageViewController()
    let pages: [ScrollBehaviorPage]
    let cover = UIView()
    let tab = UIView()
    let preloadsPages: Bool
    var coverHeight: CGFloat = 204
    var tabHeight: CGFloat = 44
    var events: [Event] = []

    init(
        keepsPosition: Bool = true,
        preloadsPages: Bool = true,
        contentTop: CGFloat = 0,
        stickyOffset: CGFloat = 0,
        headerBounces: Bool = true
    ) {
        self.preloadsPages = preloadsPages
        pages = [ScrollBehaviorPage(contentTop: contentTop), ScrollBehaviorPage(contentTop: contentTop)]
        host.dataSource = self
        host.delegate = self
        host.keepsContentScrollPosition = keepsPosition
        host.stickyOffset = stickyOffset
        host.headerBounces = headerBounces
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        host.view.layoutIfNeeded()
    }

    var header: UIView { cover.superview! }

    var headerY: CGFloat {
        header.convert(header.bounds, to: host.containerView).minY
    }

    var isHeaderAttachedToCurrentPage: Bool {
        header.superview?.superview === host.currentContentScrollView
    }

    func scroll(to offset: CGFloat) {
        pages[host.currentIndex].scrollView.contentOffset.y = offset
    }

    func enterHover() {
        host.scrollToPage(at: 0, animated: false)
        scroll(to: 100)
        host.scrollToPage(at: 1, animated: false)
        scroll(to: -144)
        host.scrollToPage(at: 0, animated: false)
    }

    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int { pages.count }
    func pageViewController(
        _ pageViewController: NestedPageViewController,
        viewControllerAt index: Int
    ) -> NestedPageScrollable? {
        pages[index]
    }
    func pageViewController(
        _ pageViewController: NestedPageViewController,
        shouldPreloadViewControllerAt index: Int
    ) -> Bool {
        preloadsPages
    }
    func coverView(in pageViewController: NestedPageViewController) -> UIView? { cover }
    func tabStrip(in pageViewController: NestedPageViewController) -> UIView? { tab }
    func heightForCoverView(in pageViewController: NestedPageViewController) -> CGFloat { coverHeight }
    func heightForTabStrip(in pageViewController: NestedPageViewController) -> CGFloat { tabHeight }
    func pageViewController(
        _ pageViewController: NestedPageViewController,
        contentScrollViewDidScroll scrollView: UIScrollView,
        headerOffset: CGFloat,
        isSticked: Bool
    ) {
        events.append(Event(
            pageOffsets: pages.map { $0.scrollView.contentOffset.y },
            headerOffset: headerOffset,
            isSticked: isSticked
        ))
    }
}

private final class ScrollBehaviorPage: UIViewController, NestedPageScrollable {
    let scrollView = BehaviorScrollView()
    let contentTop: CGFloat
    var nestedPageContentScrollView: UIScrollView { scrollView }

    init(contentTop: CGFloat) {
        self.contentTop = contentTop
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.frame = CGRect(
            x: 0, y: contentTop, width: view.bounds.width, height: view.bounds.height - contentTop
        )
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.contentSize = CGSize(width: view.bounds.width, height: 2000)
        view.addSubview(scrollView)
    }
}

private final class BehaviorScrollView: UIScrollView {
    var simulatesDeceleration = false
    override var isDecelerating: Bool { simulatesDeceleration || super.isDecelerating }
}

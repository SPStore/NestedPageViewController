import XCTest
import UIKit
import NestedPageViewController
@testable import NestedPageExample

/// 不使用 Food 页面、商品布局或轮播子类，验证业务协调器可独立复用。
@MainActor
final class NestedPageDualScrollCoordinatorTests: XCTestCase {
    func testNavigationHeightChangesKeepSharedCollapseAndExpansionAligned() {
        let f = DualScrollFixture()
        f.pager.keepsContentScrollPosition = true
        for navigationHeight: CGFloat in [80, 30, 0] {
            f.pager.stickyOffset = navigationHeight
            f.page.coordinator.updatePinnedHeaderHeight(37 + navigationHeight)
            f.pager.updateLayouts()
            f.pager.scrollToTop(animated: false)
            f.synchronizeHeader()
            XCTAssertEqual(f.page.coordinator.visibleSharedHeight, 280, accuracy: 0.1)
            // 短副列表也必须能完整收起共享区，并停在导航栏和 Tab 之后。
            f.moveSecondary(by: 243 - navigationHeight)
            XCTAssertEqual(f.page.coordinator.visibleSharedHeight, 37 + navigationHeight, accuracy: 0.1)
            XCTAssertEqual(f.tab.convert(f.tab.bounds, to: f.page.view).maxY, 37 + navigationHeight, accuracy: 0.1)
            XCTAssertEqual(f.page.primary.contentOffset.y, 46 - navigationHeight, accuracy: 0.1)
            XCTAssertEqual(f.secondaryDepth, 0, accuracy: 0.1)
            f.page.coordinator.expandSharedHeader()
            f.synchronizeHeader()
            XCTAssertEqual(f.page.coordinator.visibleSharedHeight, 280, accuracy: 0.1)
            XCTAssertEqual(f.page.primary.contentOffset.y, -197, accuracy: 0.1)
            XCTAssertEqual(f.secondaryDepth, 0, accuracy: 0.1)
        }
    }

    func testTouchWithoutDraggingDoesNotCancelExpansionWithContentAtTop() {
        let f = DualScrollFixture()
        f.page.primary.contentOffset.y = 83 - 37
        f.page.secondary.simulatesTracking = true
        let finished = expectation(description: "普通点击不打断动画")
        f.page.coordinator.expandSharedHeader(animated: true) {
            XCTAssertEqual(f.page.primary.contentOffset.y + f.page.coordinator.visibleSharedHeight - 83, 0, accuracy: 0.1)
            XCTAssertEqual(f.secondaryDepth, 0, accuracy: 0.1)
            if !f.page.coordinator.isAnimatingSharedHeader { finished.fulfill() }
        }
        wait(for: [finished], timeout: 2)
        XCTAssertEqual(f.page.coordinator.visibleSharedHeight, 280, accuracy: 0.1)
    }

    func testReleasingPageCancelsDisplayLinkWithoutRetainingCoordinator() {
        for animated in [false, true] {
            weak var coordinator: NestedPageDualScrollCoordinator?
            weak var pager: NestedPageViewController?
            // UIKit getter / 层级操作产生的 autorelease 引用不应跨过下面的释放断言。
            autoreleasepool {
                let f = DualScrollFixture()
                f.page.primary.contentOffset.y = 600
                coordinator = f.page.coordinator
                pager = f.pager
                f.page.coordinator.expandSharedHeader(animated: animated)
                XCTAssertEqual(coordinator?.isAnimatingSharedHeader, animated)
                f.pager.willMove(toParent: nil)
                f.pager.view.removeFromSuperview()
                f.pager.removeFromParent()
                f.window.rootViewController = nil
            }
            let released = expectation(description: "窗口离屏事务完成")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { released.fulfill() }
            wait(for: [released], timeout: 1)
            XCTAssertNil(coordinator, "animated = \(animated)")
            XCTAssertNil(pager, "animated = \(animated)")
        }
    }

    func testAnimatedExpansionPreservesBothReadingPositionsOnEveryFrame() {
        let f = DualScrollFixture()
        f.page.secondary.contentSize.height = 1500
        f.page.coordinator.layoutContent()
        f.page.primary.contentOffset.y = 600
        f.moveSecondary(by: 80)
        let depth = f.page.primary.contentOffset.y + 37 - 83
        let secondaryDepth = f.secondaryDepth
        let finished = expectation(description: "平滑展开完成")
        var frameCount = 0
        var lastHeight: CGFloat = 37
        f.page.coordinator.expandSharedHeader(animated: true) {
            frameCount += 1
            let height = f.page.coordinator.visibleSharedHeight
            XCTAssertGreaterThanOrEqual(height, lastHeight)
            XCTAssertEqual(f.page.primary.contentOffset.y + height - 83, depth, accuracy: 0.1)
            XCTAssertEqual(f.secondaryDepth, secondaryDepth, accuracy: 0.1)
            XCTAssertEqual(f.tab.convert(f.tab.bounds, to: f.page.view).maxY,
                           f.page.coordinator.visibleHeaderHeight, accuracy: 0.1)
            lastHeight = height
            if !f.page.coordinator.isAnimatingSharedHeader { finished.fulfill() }
        }
        XCTAssertTrue(f.page.coordinator.isAnimatingSharedHeader)
        XCTAssertEqual(f.page.coordinator.visibleSharedHeight, 37, accuracy: 0.1)
        wait(for: [finished], timeout: 2)
        XCTAssertGreaterThan(frameCount, 3)
        XCTAssertFalse(f.page.coordinator.isAnimatingSharedHeader)
        f.moveSecondary(by: 243)
        XCTAssertEqual(f.page.primary.contentOffset.y + 37 - 83, depth, accuracy: 0.1)
    }

    func testDraggingPagingAndStoppingInterruptExpansionAtCurrentPosition() {
        for action in 0..<4 {
            let f = DualScrollFixture()
            f.page.primary.contentOffset.y = 600
            let interrupted = expectation(description: "动画中接管 \(action)")
            var didInterrupt = false
            f.page.coordinator.expandSharedHeader(animated: true) {
                guard !didInterrupt, f.page.coordinator.visibleSharedHeight > 60 else { return }
                didInterrupt = true
                switch action {
                case 0: f.page.coordinator.scrollViewWillBeginDragging(f.page.primary)
                case 1: f.page.coordinator.scrollViewWillBeginDragging(f.page.secondary)
                case 2: f.pager.scrollToPage(at: 0, animated: false)
                default: f.page.coordinator.stopMotion()
                }
                interrupted.fulfill()
            }
            wait(for: [interrupted], timeout: 2)
            let height = f.page.coordinator.visibleSharedHeight
            let offset = f.page.primary.contentOffset
            XCTAssertLessThan(height, 280)
            XCTAssertFalse(f.page.coordinator.isAnimatingSharedHeader)
            let settled = expectation(description: "旧动画不再写入")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { settled.fulfill() }
            wait(for: [settled], timeout: 1)
            XCTAssertEqual(f.page.coordinator.visibleSharedHeight, height, accuracy: 0.1)
            XCTAssertEqual(f.page.primary.contentOffset, offset)
        }
    }

    func testRepeatedExpansionContinuesFromCurrentGeometry() {
        let f = DualScrollFixture()
        f.page.primary.contentOffset.y = 600
        let depth = f.page.primary.contentOffset.y + 37 - 83
        let finished = expectation(description: "重复展开完成")
        var restarted = false
        f.page.coordinator.expandSharedHeader(animated: true) {
            guard !restarted, f.page.coordinator.visibleSharedHeight > 60 else { return }
            restarted = true
            let previousHeight = f.page.coordinator.visibleSharedHeight
            f.page.coordinator.expandSharedHeader(animated: true) {
                XCTAssertEqual(f.page.primary.contentOffset.y + f.page.coordinator.visibleSharedHeight - 83,
                               depth, accuracy: 0.1)
                if !f.page.coordinator.isAnimatingSharedHeader { finished.fulfill() }
            }
            XCTAssertEqual(f.page.coordinator.visibleSharedHeight, previousHeight, accuracy: 0.1)
        }
        wait(for: [finished], timeout: 2)
        XCTAssertEqual(f.page.coordinator.visibleSharedHeight, 280, accuracy: 0.1)
    }

    func testSharedExpansionIsIndependentOfFoodAndPageIndex() {
        let f = DualScrollFixture()
        f.page.secondary.contentSize.height = 1500
        f.page.coordinator.layoutContent()
        f.page.primary.contentOffset.y = 600
        f.moveSecondary(by: 80)
        let primaryDepth = f.page.primary.contentOffset.y + 37 - 83
        let secondaryDepth = f.secondaryDepth
        f.page.coordinator.expandSharedHeader()
        f.synchronizeHeader()
        XCTAssertEqual(f.pager.currentIndex, 1)
        XCTAssertEqual(f.page.coordinator.visibleHeaderHeight, 197, accuracy: 0.1)
        XCTAssertEqual(f.page.coordinator.visibleSharedHeight, 280, accuracy: 0.1)
        XCTAssertEqual(f.page.primary.contentOffset.y + 197, primaryDepth, accuracy: 0.1)
        XCTAssertEqual(f.secondaryDepth, secondaryDepth, accuracy: 0.1)
        let shared = f.page.content.sharedContentView!
        XCTAssertEqual(shared.convert(shared.bounds, to: f.page.view).minY, 197, accuracy: 0.1)
        f.moveSecondary(by: 243)
        XCTAssertEqual(f.page.coordinator.visibleSharedHeight, 37, accuracy: 0.1)
        XCTAssertEqual(f.page.primary.contentOffset.y + 37 - 83, primaryDepth, accuracy: 0.1)
        XCTAssertEqual(f.secondaryDepth, secondaryDepth, accuracy: 0.1)
    }

    func testCustomGeometryAndNonzeroPageIndex() {
        let f = DualScrollFixture()
        // 这项验证跨边界后的独立滚动，副列表须有足够内容；短内容只保证共享区域能收完。
        f.page.secondary.contentSize.height = 1500
        f.page.coordinator.layoutContent()
        XCTAssertEqual(f.pager.currentIndex, 1)
        XCTAssertEqual(f.page.primary.contentOffset.y, -197, accuracy: 0.1)
        XCTAssertEqual(f.page.secondary.contentOffset.y, -280, accuracy: 0.1)
        XCTAssertEqual(f.page.content.secondaryContainerView.frame.minY, 280, accuracy: 0.1)
        XCTAssertEqual(f.page.secondary.frame.width, 71, accuracy: 0.1)
        XCTAssertEqual(f.page.primary.frame.width, 390, accuracy: 0.1)

        // 160 点店铺 + 83 点共享内容，剩余 27 点只滚副列表。
        f.moveSecondary(by: 270)
        XCTAssertEqual(f.page.coordinator.visibleHeaderHeight, 37, accuracy: 0.1)
        XCTAssertEqual(f.page.coordinator.visibleSharedHeight, 37, accuracy: 0.1)
        XCTAssertEqual(f.page.primary.contentOffset.y, 46, accuracy: 0.1)
        XCTAssertEqual(f.secondaryDepth, 27, accuracy: 0.1)
        XCTAssertEqual(f.page.secondary.convert(f.page.secondary.bounds, to: f.page.view).minY, 0, accuracy: 0.1)

        f.moveSecondary(by: -47)
        XCTAssertEqual(f.page.coordinator.visibleSharedHeight, 57, accuracy: 0.1)
        XCTAssertEqual(f.page.primary.contentOffset.y, 26, accuracy: 0.1)
        XCTAssertEqual(f.secondaryDepth, 0, accuracy: 0.1)
    }

    func testInactiveSecondaryCannotDrivePrimary() {
        let f = DualScrollFixture()
        f.pager.scrollToPage(at: 0, animated: false)
        let primaryOffset = f.page.primary.contentOffset
        f.moveSecondary(by: 80)
        XCTAssertEqual(f.page.primary.contentOffset, primaryOffset)
        f.pager.scrollToPage(at: 1, animated: false)
        let offsetAfterSwitch = f.page.primary.contentOffset.y
        f.moveSecondary(by: 20)
        XCTAssertEqual(f.page.primary.contentOffset.y - offsetAfterSwitch, 20, accuracy: 0.1)
    }

    func testProgrammaticSecondaryPositionDoesNotDrivePrimary() {
        let f = DualScrollFixture()
        let primaryOffset = f.page.primary.contentOffset
        f.page.secondary.contentOffset.y += 50
        XCTAssertEqual(f.page.primary.contentOffset, primaryOffset)
        f.page.coordinator.resetSecondaryPosition()
        XCTAssertEqual(f.secondaryDepth, 0, accuracy: 0.1)
        f.moveSecondary(by: 20)
        XCTAssertEqual(f.page.primary.contentOffset.y - primaryOffset.y, 20, accuracy: 0.1)
    }

    func testSecondaryContentResizeRefreshesShortContentInset() {
        let f = DualScrollFixture()
        let secondary = f.page.secondary
        let maximum = secondary.contentSize.height - secondary.bounds.height + secondary.contentInset.bottom
        XCTAssertEqual(maximum, -37, accuracy: 0.1)
        secondary.contentSize.height = 1200
        f.page.coordinator.layoutContent()
        XCTAssertEqual(secondary.contentInset.bottom, f.page.content.safeAreaInsets.bottom, accuracy: 0.1)
        XCTAssertEqual(f.page.primary.contentOffset.y, -197, accuracy: 0.1)
    }

    func testRevealSecondaryRectRespectsUserInteraction() {
        let f = DualScrollFixture()
        f.page.secondary.contentSize.height = 1500
        f.page.coordinator.layoutContent()
        f.moveSecondary(by: 243)
        let primaryOffset = f.page.primary.contentOffset
        let offset = f.page.secondary.contentOffset
        let rect = CGRect(x: 0, y: 900, width: 71, height: 40)
        f.page.secondary.simulatesDragging = true
        f.page.coordinator.revealSecondaryRect(rect)
        XCTAssertEqual(f.page.secondary.contentOffset, offset)
        f.page.secondary.simulatesDragging = false
        f.page.coordinator.revealSecondaryRect(rect)
        XCTAssertEqual(f.page.secondary.contentOffset.y + f.page.secondary.bounds.height, rect.maxY, accuracy: 0.1)
        XCTAssertEqual(f.page.primary.contentOffset, primaryOffset)
    }

    func testCenterSecondaryRectUsesVisibleViewportWithoutMovingPrimary() {
        for primaryY: CGFloat in [-197, -97, 46] {
            let f = DualScrollFixture()
            let secondary = f.page.secondary
            secondary.contentSize.height = 1500
            f.page.coordinator.layoutContent()
            f.page.primary.contentOffset.y = primaryY
            let primaryOffset = f.page.primary.contentOffset
            let sharedHeight = f.page.coordinator.visibleSharedHeight
            let rect = CGRect(x: 0, y: 600, width: 71, height: 40)
            f.page.coordinator.centerSecondaryRect(rect, animated: false)
            XCTAssertEqual(rect.midY - secondary.contentOffset.y,
                           (sharedHeight + secondary.bounds.height) / 2, accuracy: 0.5)
            XCTAssertEqual(f.page.primary.contentOffset, primaryOffset)
            XCTAssertEqual(f.page.coordinator.visibleSharedHeight, sharedHeight, accuracy: 0.1)
        }
    }

    func testCenterSecondaryRectClampsEdgesAndRespectsDragging() {
        for contentHeight: CGFloat in [180, 1500] {
            let f = DualScrollFixture()
            let secondary = f.page.secondary
            secondary.contentSize.height = contentHeight
            f.page.coordinator.layoutContent()
            f.moveSecondary(by: 243)
            let coordinator = f.page.coordinator
            let original = secondary.contentOffset
            let lastRect = CGRect(x: 0, y: contentHeight - 40, width: 71, height: 40)
            secondary.simulatesDragging = true
            coordinator.centerSecondaryRect(lastRect, animated: false)
            XCTAssertEqual(secondary.contentOffset, original)
            secondary.simulatesDragging = false
            coordinator.centerSecondaryRect(lastRect, animated: false)
            let maximum = max(-37, contentHeight - secondary.bounds.height + secondary.contentInset.bottom)
            XCTAssertEqual(secondary.contentOffset.y, maximum, accuracy: 0.5)
            coordinator.centerSecondaryRect(CGRect(x: 0, y: 0, width: 71, height: 40), animated: false)
            XCTAssertEqual(secondary.contentOffset.y, -37, accuracy: 0.5)
            XCTAssertEqual(f.page.primary.contentOffset.y, 46, accuracy: 0.1)
        }
    }

    func testCenteringAnimationStopsOnPrimaryDragPagingAndStopMotion() {
        for action in 0..<3 {
            let f = DualScrollFixture()
            let secondary = f.page.secondary
            secondary.contentSize.height = 1500
            f.page.coordinator.layoutContent()
            f.moveSecondary(by: 243)
            let primaryOffset = f.page.primary.contentOffset
            let moved = expectation(description: "副列表居中动画已经开始")
            var fulfilled = false
            let observation = secondary.observe(\.contentOffset, options: [.new]) { _, change in
                guard let offset = change.newValue, offset.y > 0, !fulfilled else { return }
                fulfilled = true
                moved.fulfill()
            }
            f.page.coordinator.centerSecondaryRect(CGRect(x: 0, y: 900, width: 71, height: 40))
            wait(for: [moved], timeout: 2)
            observation.invalidate()
            XCTAssertEqual(f.page.primary.contentOffset, primaryOffset)
            switch action {
            case 0: f.page.coordinator.scrollViewWillBeginDragging(f.page.primary)
            case 1: f.pager.scrollToPage(at: 0, animated: false)
            default: f.page.coordinator.stopMotion()
            }
            let stoppedOffset = secondary.contentOffset
            let settled = expectation(description: "居中动画停止后不再写入")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { settled.fulfill() }
            wait(for: [settled], timeout: 1)
            XCTAssertEqual(secondary.contentOffset, stoppedOffset)
        }
    }

    func testPlainHorizontalViewsRegistrationAndCoordinatorLifetime() throws {
        let pager = NestedPageViewController()
        let primary = UIScrollView()
        let secondary = UIScrollView()
        let delegate = DualScrollDelegateProbe()
        primary.delegate = delegate
        secondary.delegate = delegate
        pager.containerScrollView.delegate = delegate
        let content = NestedPageDualScrollView(primaryScrollView: primary, secondaryScrollView: secondary, secondaryWidth: 71)
        var coordinator: NestedPageDualScrollCoordinator? = NestedPageDualScrollCoordinator(
            pageViewController: pager, contentView: content, expandedHeaderHeight: 197, pinnedHeaderHeight: 37
        )
        weak var weakCoordinator = coordinator
        // init 不修改列表 offset，避免业务 delegate 在实例赋值前重入。
        XCTAssertEqual(delegate.scrollCount, 0)
        let horizontal = UIScrollView()
        let collection = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        coordinator?.prioritizeHorizontalScrolling(in: [horizontal, collection, horizontal, primary, secondary, pager.containerScrollView])
        for scrollView in [horizontal, collection] {
            let guards = scrollView.gestureRecognizers?.compactMap { $0 as? NestedPagePagingGestureGuard } ?? []
            XCTAssertEqual(guards.count, 1)
            let pagingGuard = try XCTUnwrap(guards.first)
            XCTAssertTrue(pagingGuard.canPrevent(pager.containerScrollView.panGestureRecognizer))
            XCTAssertFalse(pagingGuard.canPrevent(scrollView.panGestureRecognizer))
            XCTAssertFalse(pagingGuard.canPrevent(primary.panGestureRecognizer))
        }
        XCTAssertTrue(primary.delegate === delegate)
        XCTAssertTrue(secondary.delegate === delegate)
        XCTAssertTrue(pager.containerScrollView.delegate === delegate)
        coordinator = nil
        XCTAssertNil(weakCoordinator)
        for scrollView in [horizontal, collection, primary, secondary, pager.containerScrollView] {
            XCTAssertFalse(scrollView.gestureRecognizers?.contains { $0 is NestedPagePagingGestureGuard } ?? false)
        }
        // 协调器释放后，原分页仍可更新，观察与附加手势不残留。
        pager.containerScrollView.contentOffset.x = 10
    }
}

private final class DualScrollFixture: NSObject, NestedPageViewControllerDataSource, NestedPageViewControllerDelegate {
    let pager = NestedPageViewController()
    let page = DualScrollTestPage()
    let other = DualScrollOtherPage()
    let cover = UIView()
    let tab = UIView()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
    var secondaryDepth: CGFloat { page.secondary.contentOffset.y + page.coordinator.visibleSharedHeight }

    override init() {
        super.init()
        page.pager = pager
        pager.dataSource = self
        pager.delegate = self
        pager.defaultPageIndex = 1
        pager.headerBounces = false
        window.windowScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        root.addChild(pager)
        root.view.addSubview(pager.view)
        pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        pager.didMove(toParent: root)
        pager.view.layoutIfNeeded()
        pager.updateLayouts()
        page.view.layoutIfNeeded()
        synchronizeHeader()
    }
    deinit { window.isHidden = true }
    func moveSecondary(by delta: CGFloat) {
        page.secondary.simulatesDragging = true
        page.secondary.simulatedPan.simulatedState = .changed
        page.secondary.contentOffset.y += delta
        page.secondary.simulatedPan.simulatedState = .possible
        page.secondary.simulatesDragging = false
    }
    func synchronizeHeader() {
        guard page.isViewLoaded, tab.superview != nil else { return }
        page.coordinator.updateVisibleHeaderHeight(tab.convert(tab.bounds, to: page.view).maxY)
    }
    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int { 2 }
    func pageViewController(_ pageViewController: NestedPageViewController, viewControllerAt index: Int) -> NestedPageScrollable? { index == 1 ? page : other }
    func coverView(in pageViewController: NestedPageViewController) -> UIView? { cover }
    func heightForCoverView(in pageViewController: NestedPageViewController) -> CGFloat { 160 }
    func tabStrip(in pageViewController: NestedPageViewController) -> UIView? { tab }
    func heightForTabStrip(in pageViewController: NestedPageViewController) -> CGFloat { 37 }
    func pageViewController(_ pageViewController: NestedPageViewController, contentScrollViewDidScroll scrollView: UIScrollView, headerOffset: CGFloat, isSticked: Bool) { synchronizeHeader() }
    func pageViewController(_ pageViewController: NestedPageViewController, didScrollToPageAt index: Int) {
        if page.isViewLoaded { page.coordinator.stopMotion() }
        synchronizeHeader()
    }
}

private final class DualScrollTestPage: UIViewController, NestedPageScrollable, UIScrollViewDelegate {
    weak var pager: NestedPageViewController?
    let primary = UIScrollView()
    let secondary = DualScrollTestScrollView()
    lazy var content = NestedPageDualScrollView(primaryScrollView: primary, secondaryScrollView: secondary,
                                              secondaryWidth: 71, sharedContentView: UIView())
    lazy var coordinator = NestedPageDualScrollCoordinator(
        pageViewController: pager, contentView: content,
        expandedHeaderHeight: 197, pinnedHeaderHeight: 37, sharedContentHeight: 83
    )
    var nestedPageContentScrollView: UIScrollView { primary }
    override func loadView() { view = content }
    override func viewDidLoad() {
        super.viewDidLoad()
        primary.contentSize = CGSize(width: 390, height: 3000)
        secondary.contentSize = CGSize(width: 71, height: 180)
        primary.delegate = self
        secondary.delegate = self
        coordinator.layoutContent()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        coordinator.layoutContent()
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) { coordinator.scrollViewDidScroll(scrollView) }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { coordinator.scrollViewWillBeginDragging(scrollView) }
}

private final class DualScrollOtherPage: UIViewController, NestedPageScrollable {
    let scrollView = UIScrollView()
    var nestedPageContentScrollView: UIScrollView { scrollView }
    override func loadView() { view = scrollView }
    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.contentSize = CGSize(width: 390, height: 3000)
    }
}

private final class DualScrollTestScrollView: UIScrollView {
    var simulatesDragging = false
    var simulatesTracking = false
    let simulatedPan = DualScrollTestPanGestureRecognizer()
    override var panGestureRecognizer: UIPanGestureRecognizer { simulatedPan }
    override var isDragging: Bool { simulatesDragging || super.isDragging }
    override var isTracking: Bool { simulatesTracking || super.isTracking }
}

/// 将手指手势状态与 UIScrollView 的 dragging / decelerating 标记独立模拟。
final class DualScrollTestPanGestureRecognizer: UIPanGestureRecognizer {
    var simulatedState: UIGestureRecognizer.State = .possible
    override var state: UIGestureRecognizer.State {
        get { simulatedState }
        set { simulatedState = newValue }
    }
}

private final class DualScrollDelegateProbe: NSObject, UIScrollViewDelegate {
    var scrollCount = 0
    func scrollViewDidScroll(_ scrollView: UIScrollView) { scrollCount += 1 }
}

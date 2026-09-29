import XCTest
import UIKit
import NestedPageViewController
@testable import NestedPageExample

/// 使用真正的 UITableView / UICollectionView 和组件的 KVO 链路，模拟拖拽/减速事件。
/// 不代替真机手势验收；尤其不验证 UIKit 手势识别和原生惯性的速度曲线。
@MainActor
final class FoodOrderingTests: XCTestCase {
    func testActualDemoRendersExpandedAndPinned() {
        let screen = UIWindow(frame: UIScreen.main.bounds)
        screen.windowScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let demo = FoodOrderingViewController()
        screen.rootViewController = UINavigationController(rootViewController: demo)
        screen.makeKeyAndVisible()
        screen.layoutIfNeeded()
        demo.view.layoutIfNeeded()
        let host = demo.children.compactMap { $0 as? NestedPageViewController }.first!
        host.view.layoutIfNeeded()
        let menu = host.viewController(at: 0) as! FoodMenuViewController
        menu.view.layoutIfNeeded()
        XCTAssertEqual(host.headerHeight, 244, accuracy: 0.1)
        XCTAssertEqual(menu.nestedPageContentScrollView.contentOffset.y, -244, accuracy: 0.1)
        let category = menu.view.subviews.flatMap(\.subviews).compactMap { $0 as? UITableView }.first!
        XCTAssertFalse(menu.nestedPageContentScrollView.bounces)
        XCTAssertFalse(category.bounces)
        XCTAssertFalse(category.alwaysBounceVertical)
        XCTAssertEqual(category.indexPathForSelectedRow?.row, 0)
        XCTAssertEqual(category.contentOffset.y, -244 - FoodMenuViewController.sharedCarouselHeight, accuracy: 0.1)
        attach(screen, name: "点餐页-展开")
        menu.nestedPageContentScrollView.contentOffset.y = -44 + 80
        menu.view.layoutIfNeeded()
        attach(screen, name: "点餐页-Tab吸顶-公共轮播部分收起")
        menu.nestedPageContentScrollView.contentOffset.y = FoodMenuViewController.sharedCarouselHeight - 44
        menu.view.layoutIfNeeded()
        attach(screen, name: "点餐页-公共轮播收完-右侧轮播保留")
        menu.nestedPageContentScrollView.contentOffset.y = 700
        menu.view.layoutIfNeeded()
        attach(screen, name: "点餐页-吸顶")
        let reset = demo.navigationItem.rightBarButtonItems!.first!
        UIApplication.shared.sendAction(reset.action!, to: reset.target, from: reset, for: nil)
        menu.view.layoutIfNeeded()
        // 示例已开启位置保留；现有重置只更新布局，不强制清空商品阅读位置。
        XCTAssertTrue(host.keepsContentScrollPosition)
        XCTAssertEqual(menu.nestedPageContentScrollView.contentOffset.y, 700, accuracy: 0.1)
        XCTAssertEqual(category.contentOffset.y + category.superview!.frame.minY, 0, accuracy: 0.1)
        XCTAssertEqual(category.indexPathForSelectedRow?.row, 0)
        XCTAssertEqual(category.superview!.frame.minY, 44, accuracy: 0.1)
        XCTAssertFalse(menu.nestedPageContentScrollView.bounces)
        XCTAssertFalse(category.bounces)
        screen.isHidden = true
    }

    private func attach(_ window: UIWindow, name: String) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForScroll(_ scrollView: UIScrollView, to target: CGFloat) {
        let arrived = expectation(description: "商品滚动到目标分组")
        var fulfilled = false
        // KVO 在 UIKit 修改 offset 的主线程回调；不让异步 predicate 持有整套 UIWindow 测试夹具。
        let observation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { _, change in
            guard let offset = change.newValue, abs(offset.y - target) < 0.5, !fulfilled else { return }
            fulfilled = true
            arrived.fulfill()
        }
        wait(for: [arrived], timeout: 3)
        observation.invalidate()
    }

    func testInitialGeometryAndFullWidthHeader() {
        let f = FoodFixture()
        XCTAssertEqual(f.headerBottom, 244, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 244, accuracy: 0.1)
        XCTAssertEqual(f.categoryOrigin, 0, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.cover.convert(f.cover.bounds, to: f.menu.view).minX, 0, accuracy: 0.1)
        XCTAssertEqual(f.cover.bounds.width, 390, accuracy: 0.1)
    }

    func testLeftDragSplitsAtStickyBoundaryWithoutMovingProductContent() {
        let f = FoodFixture()
        f.moveCategories(by: 80)
        XCTAssertEqual(f.headerBottom, 164, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        f.moveCategories(by: 190)
        XCTAssertEqual(f.headerBottom, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryOrigin, 0, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 70, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
    }

    func testLeftDecelerationContinuesAcrossStickyBoundary() {
        let f = FoodFixture()
        f.moveCategories(by: 160)
        f.category.simulatesDeceleration = true
        f.moveCategories(by: 30, dragging: false)
        f.moveCategories(by: 40, dragging: false)
        f.moveCategories(by: 20, dragging: false)
        XCTAssertEqual(f.headerBottom, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 50, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
    }

    func testTopBounceRecoveryDoesNotCollapseHeader() {
        let f = FoodFixture()
        f.moveCategories(by: -40)
        f.moveCategories(by: 20)
        XCTAssertEqual(f.headerBottom, 244, accuracy: 0.1)
        f.moveCategories(by: 20)
        XCTAssertEqual(f.headerBottom, 244, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
    }

    func testLeftPullDownConsumesLocalPositionBeforeExpandingHeader() {
        let f = FoodFixture()
        f.moveCategories(by: 270)
        f.moveCategories(by: -40)
        XCTAssertEqual(f.headerBottom, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 30, accuracy: 0.1)
        f.moveCategories(by: -90)
        XCTAssertEqual(f.headerBottom, 104, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
    }

    func testRightScrollPreservesCategoryPositionAndPinnedListsAreIndependent() {
        let f = FoodFixture()
        f.moveCategories(by: 270)
        f.products.contentOffset.y += 100
        XCTAssertEqual(f.categoryDepth, 70, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 100, accuracy: 0.1)
        f.moveCategories(by: 50)
        XCTAssertEqual(f.categoryDepth, 120, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 100, accuracy: 0.1)
        // 商品在深处时，分类的原生滚动边界限制在 tab 下，不把商品突然拉回顶部。
        XCTAssertEqual(f.category.contentInset.top, 44, accuracy: 0.1)
    }

    func testShortCategoriesCanReachPinnedPositionWithoutChangingContentSize() {
        let f = FoodFixture(short: true)
        let size = f.category.contentSize
        let maximumOffset = size.height - f.category.bounds.height + f.category.contentInset.bottom
        XCTAssertGreaterThanOrEqual(maximumOffset, -44)
        f.moveCategories(by: 200)
        XCTAssertEqual(f.headerBottom, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.category.contentSize, size)
    }

    func testSelectingLastShortProductSectionPinsItBelowTab() throws {
        let f = FoodFixture(short: true)
        f.products.layoutIfNeeded()
        f.category.selectRow(at: IndexPath(row: 3, section: 0), animated: false, scrollPosition: .none)
        let lastHeader = try XCTUnwrap(f.products.collectionViewLayout.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 3)))
        let target = lastHeader.frame.minY - 44
        f.menu.tableView(f.category, didSelectRowAt: IndexPath(row: 3, section: 0))
        waitForScroll(f.products, to: target)
        XCTAssertEqual(f.category.indexPathForSelectedRow?.row, 3)
        XCTAssertEqual(f.category.indexPathsForSelectedRows?.count, 1)
        let header = f.products.collectionViewLayout.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 3))!
        XCTAssertEqual(header.frame.minY - f.products.contentOffset.y, 44, accuracy: 0.5)
        XCTAssertLessThanOrEqual(f.products.contentOffset.y, f.products.contentSize.height - f.products.bounds.height + f.products.contentInset.bottom + 0.5)
    }

    func testSwitchingTabsAndExpandingSharedHeaderDoesNotLeaveCategoryGap() {
        let f = FoodFixture()
        f.moveCategories(by: 270)
        f.host.scrollToPage(at: 1, animated: false)
        f.other.scroll.contentOffset.y = -164
        f.host.scrollToPage(at: 0, animated: false)
        XCTAssertEqual(f.headerBottom, 164, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, f.headerBottom, accuracy: 0.1)
        XCTAssertEqual(f.categoryOrigin, 0, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 70, accuracy: 0.1)
    }

    func testResizeAndResetKeepGeometryConsistent() {
        let f = FoodFixture()
        f.moveCategories(by: 270)
        f.host.view.frame.size = CGSize(width: 700, height: 390)
        f.host.updateLayouts()
        f.synchronizeHeader()
        f.menu.resetCategoryPosition()
        XCTAssertEqual(f.categoryTop, f.headerBottom, accuracy: 0.1)
        XCTAssertEqual(f.categoryOrigin, 0, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
    }

    func testCarouselGeometryAndHorizontalScrollingAreIndependent() throws {
        let f = FoodFixture(carousels: true)
        XCTAssertEqual(f.categoryTop, 464, accuracy: 0.1)
        XCTAssertEqual(f.categoryOrigin, 0, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        let shared = try XCTUnwrap(f.products.layoutAttributesForItem(at: IndexPath(item: 0, section: 0)))
        let right = try XCTUnwrap(f.products.layoutAttributesForItem(at: IndexPath(item: 0, section: 1)))
        XCTAssertEqual(shared.frame, CGRect(x: 0, y: 0, width: 390, height: 220))
        XCTAssertEqual(right.frame.minX, 104, accuracy: 0.1)
        XCTAssertEqual(right.frame.minY, 220, accuracy: 0.1)
        let sharedView = try XCTUnwrap(f.products.cellForItem(at: IndexPath(item: 0, section: 0))?.contentView.subviews.first as? FoodCarouselView)
        let rightView = try XCTUnwrap(f.products.cellForItem(at: IndexPath(item: 0, section: 1))?.contentView.subviews.first as? FoodCarouselView)
        sharedView.layoutIfNeeded()
        rightView.layoutIfNeeded()
        let pageOffset = f.host.containerScrollView.contentOffset
        sharedView.contentOffset.x = 90
        XCTAssertEqual(rightView.contentOffset.x, 0, accuracy: 0.1)
        rightView.contentOffset.x = rightView.bounds.width
        XCTAssertEqual(sharedView.contentOffset.x, 90, accuracy: 0.1)
        XCTAssertEqual(f.products.contentOffset.y, -244, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.host.containerScrollView.contentOffset, pageOffset)
    }

    func testBothCarouselsExcludeOnlyPagingGestures() throws {
        let f = FoodFixture(carousels: true)
        for section in 0..<2 {
            let carousel = try XCTUnwrap(f.products.cellForItem(at: IndexPath(item: 0, section: section))?.contentView.subviews.first as? FoodCarouselView)
            let pagingGuard = try XCTUnwrap(carousel.gestureRecognizers?.first { $0.name == "food.carouselPagingGuard" })
            XCTAssertTrue(pagingGuard.canPrevent(f.host.containerScrollView.panGestureRecognizer))
            XCTAssertFalse(pagingGuard.canPrevent(carousel.panGestureRecognizer))
            XCTAssertFalse(pagingGuard.canPrevent(f.products.panGestureRecognizer))
            XCTAssertFalse(pagingGuard.canPrevent(UIScreenEdgePanGestureRecognizer()))
            XCTAssertFalse(pagingGuard.canBePrevented(by: carousel.panGestureRecognizer))
            XCTAssertFalse(pagingGuard.canBePrevented(by: f.products.panGestureRecognizer))
            XCTAssertFalse(pagingGuard.cancelsTouchesInView)
            XCTAssertFalse(pagingGuard.delaysTouchesBegan)
            XCTAssertFalse(pagingGuard.delaysTouchesEnded)
        }
    }

    func testLeftDragConsumesCoverThenSharedCarouselThenOnlyCategories() {
        let f = FoodFixture(carousels: true)
        f.moveCategories(by: 200)
        XCTAssertEqual(f.headerBottom, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 264, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        f.moveCategories(by: 80)
        XCTAssertEqual(f.headerBottom, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 184, accuracy: 0.1)
        f.moveCategories(by: 180)
        XCTAssertEqual(f.categoryTop, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryOrigin, 0, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 40, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.products.contentOffset.y, 176, accuracy: 0.1)
        f.moveCategories(by: 100)
        XCTAssertEqual(f.categoryDepth, 140, accuracy: 0.1)
        XCTAssertEqual(f.products.contentOffset.y, 176, accuracy: 0.1)
    }

    func testCategoryDecelerationCrossesBothSharedBoundaries() {
        let f = FoodFixture(carousels: true)
        f.moveCategories(by: 180)
        f.category.simulatesDeceleration = true
        for delta: CGFloat in [50, 160, 70, 20] { f.moveCategories(by: delta, dragging: false) }
        XCTAssertEqual(f.headerBottom, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 60, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
    }

    func testRightCarouselScrollDoesNotMoveCategoryReadingPosition() {
        let f = FoodFixture(carousels: true)
        f.products.contentOffset.y = -44
        XCTAssertEqual(f.categoryTop, 264, accuracy: 0.1)
        f.products.contentOffset.y += 80
        XCTAssertEqual(f.categoryTop, 184, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        f.products.contentOffset.y = 176
        f.moveCategories(by: 60)
        f.products.contentOffset.y += 70
        XCTAssertEqual(f.categoryDepth, 60, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 70, accuracy: 0.1)
        XCTAssertEqual(f.category.contentInset.top, 44, accuracy: 0.1)
        let productOffset = f.products.contentOffset
        f.moveCategories(by: -100)
        XCTAssertEqual(f.products.contentOffset, productOffset)
        XCTAssertEqual(f.headerBottom, 44, accuracy: 0.1)
    }

    func testPullDownRestoresSharedCarouselBeforeStoreHeader() {
        let f = FoodFixture(carousels: true)
        f.moveCategories(by: 470)
        f.moveCategories(by: -80)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.headerBottom, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 74, accuracy: 0.1)
        f.moveCategories(by: -250)
        XCTAssertEqual(f.headerBottom, 104, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 324, accuracy: 0.1)
        f.moveCategories(by: -140)
        f.moveCategories(by: -40)
        f.moveCategories(by: 40)
        XCTAssertEqual(f.headerBottom, 244, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 464, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
    }

    func testShortCategoriesCanConsumeEntireSharedCarousel() {
        let f = FoodFixture(short: true, carousels: true)
        let size = f.category.contentSize
        let maximumOffset = size.height - f.category.bounds.height + f.category.contentInset.bottom
        XCTAssertGreaterThanOrEqual(maximumOffset, -44)
        f.moveCategories(by: 420)
        XCTAssertEqual(f.categoryTop, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.category.contentSize, size)
    }

    func testCategoryJumpSkipsBothCarouselsAndKeepsCorrectSelection() throws {
        let f = FoodFixture(short: true, carousels: true)
        let index = IndexPath(item: 0, section: 5)
        let lastHeader = try XCTUnwrap(f.products.collectionViewLayout.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: index))
        let target = lastHeader.frame.minY - 44
        f.menu.tableView(f.category, didSelectRowAt: IndexPath(row: 3, section: 0))
        waitForScroll(f.products, to: target)
        XCTAssertEqual(f.category.indexPathForSelectedRow?.row, 3)
        XCTAssertEqual(f.category.indexPathsForSelectedRows?.count, 1)
        XCTAssertEqual(f.categoryTop, 44, accuracy: 0.1)
        let header = try XCTUnwrap(f.products.collectionViewLayout.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: index))
        XCTAssertEqual(header.frame.minY - f.products.contentOffset.y, 44, accuracy: 0.5)
        XCTAssertLessThanOrEqual(target, f.products.contentSize.height - f.products.bounds.height + f.products.contentInset.bottom + 0.5)
    }

    func testCarouselRestoresAfterTabSwitchAndResize() {
        let f = FoodFixture(carousels: true)
        f.moveCategories(by: 470)
        f.host.scrollToPage(at: 1, animated: false)
        f.other.scroll.contentOffset.y = -164
        f.host.scrollToPage(at: 0, animated: false)
        XCTAssertEqual(f.headerBottom, 164, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 384, accuracy: 0.1)
        XCTAssertEqual(f.categoryOrigin, 0, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 50, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        f.host.view.frame.size = CGSize(width: 700, height: 390)
        f.host.updateLayouts()
        f.synchronizeHeader()
        f.menu.resetCategoryPosition()
        XCTAssertEqual(f.categoryTop, f.headerBottom + 220, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
    }

    func testKeptProductPositionDoesNotLeaveCategoryGapAfterPullDown() {
        // 覆盖店铺部分 / 完全展开，且有 / 无公共轮播的悬空头部状态。
        for carousels in [false, true] {
            for expandedHeight: CGFloat in [164, 244] {
                let f = FoodFixture(carousels: carousels, keepsPosition: true)
                f.products.contentOffset.y = 552
                let depth = f.productDepth
                f.host.scrollToPage(at: 1, animated: false)
                f.other.scroll.contentOffset.y = -expandedHeight
                f.host.scrollToPage(at: 0, animated: false)
                XCTAssertEqual(f.headerBottom, expandedHeight, accuracy: 0.1)
                XCTAssertEqual(f.productDepth, depth, accuracy: 0.1)
                XCTAssertEqual(f.categoryTop, expandedHeight, accuracy: 0.1)
                // 商品仍在深处，分类正常静止的上边界只能是当前可见区域，不能预留已滚走的轮播。
                XCTAssertEqual(f.category.contentInset.top, f.categoryTop, accuracy: 0.1)
                let productOffset = f.products.contentOffset
                // 模拟左栏下拉后，原生滚动最终停在自身 inset 决定的上边界。
                f.moveCategories(by: -f.category.contentInset.top - f.category.contentOffset.y)
                XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
                XCTAssertEqual(f.products.contentOffset, productOffset)
            }
        }
    }

    func testFloatingHeaderCollapsesFromCategoriesWithoutLosingProductPosition() {
        let f = FoodFixture(carousels: true, keepsPosition: true)
        f.products.contentOffset.y = 552
        let depth = f.productDepth
        f.host.scrollToPage(at: 1, animated: false)
        f.other.scroll.contentOffset.y = -164
        f.host.scrollToPage(at: 0, animated: false)
        f.moveCategories(by: 50)
        XCTAssertEqual(f.headerBottom, 114, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, depth, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        f.moveCategories(by: 100)
        XCTAssertEqual(f.headerBottom, 44, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, depth, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 30, accuracy: 0.1)
        XCTAssertEqual(f.category.contentInset.top, 44, accuracy: 0.1)
    }
}

private final class FoodFixture: NSObject, NestedPageViewControllerDataSource, NestedPageViewControllerDelegate {
    let host = NestedPageViewController()
    let category = FoodTestTable()
    let menu: FoodMenuViewController
    let other = FoodTestPage()
    let cover = UIView()
    let tab = UIView()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
    let carousels: Bool
    var products: UICollectionView { menu.nestedPageContentScrollView as! UICollectionView }
    var headerBottom: CGFloat { tab.convert(tab.bounds, to: menu.view).maxY }
    var categoryTop: CGFloat { category.superview!.frame.minY }
    var categoryOrigin: CGFloat { category.convert(category.bounds, to: menu.view).minY }
    var categoryDepth: CGFloat { category.contentOffset.y + categoryTop }
    var productDepth: CGFloat { products.contentOffset.y + categoryTop - (carousels ? FoodMenuViewController.sharedCarouselHeight : 0) }

    init(short: Bool = false, carousels: Bool = false, keepsPosition: Bool = false) {
        self.carousels = carousels
        menu = FoodMenuViewController(categoryTable: category, showsCarousels: carousels)
        super.init()
        menu.usesShortCategories = short
        menu.pager = host
        host.dataSource = self
        host.delegate = self
        host.headerBounces = false
        host.keepsContentScrollPosition = keepsPosition
        window.windowScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        let root = window.rootViewController!
        root.addChild(host)
        root.view.addSubview(host.view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        host.didMove(toParent: root)
        host.view.layoutIfNeeded()
        host.updateLayouts()
        menu.view.layoutIfNeeded()
        synchronizeHeader()
    }
    deinit { window.isHidden = true }
    func moveCategories(by delta: CGFloat, dragging: Bool = true) {
        category.simulatesDragging = dragging
        category.contentOffset.y += delta
        category.simulatesDragging = false
    }
    func synchronizeHeader() { menu.updateSharedHeader(visibleHeight: headerBottom) }
    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int { 2 }
    func pageViewController(_ pageViewController: NestedPageViewController, viewControllerAt index: Int) -> NestedPageScrollable? { index == 0 ? menu : other }
    func coverView(in pageViewController: NestedPageViewController) -> UIView? { cover }
    func heightForCoverView(in pageViewController: NestedPageViewController) -> CGFloat { 200 }
    func tabStrip(in pageViewController: NestedPageViewController) -> UIView? { tab }
    func heightForTabStrip(in pageViewController: NestedPageViewController) -> CGFloat { 44 }
    func pageViewController(_ pageViewController: NestedPageViewController, contentScrollViewDidScroll scrollView: UIScrollView, headerOffset: CGFloat, isSticked: Bool) { synchronizeHeader() }
    func pageViewController(_ pageViewController: NestedPageViewController, didScrollToPageAt index: Int) { synchronizeHeader() }
}

private final class FoodTestTable: UITableView {
    var simulatesDragging = false
    var simulatesDeceleration = false
    override var isDragging: Bool { simulatesDragging || super.isDragging }
    override var isDecelerating: Bool { simulatesDeceleration || super.isDecelerating }
}

private final class FoodTestPage: UIViewController, NestedPageScrollable {
    let scroll = UIScrollView()
    var nestedPageContentScrollView: UIScrollView { scroll }
    override func viewDidLoad() {
        super.viewDidLoad()
        scroll.frame = view.bounds
        scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroll.contentSize = CGSize(width: view.bounds.width, height: 2000)
        view.addSubview(scroll)
    }
}

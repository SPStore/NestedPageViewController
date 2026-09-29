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
        XCTAssertEqual(category.indexPathForSelectedRow?.row, 0)
        XCTAssertEqual(category.contentOffset.y, -244, accuracy: 0.1)
        attach(screen, name: "点餐页-展开")
        menu.nestedPageContentScrollView.contentOffset.y = 700
        menu.view.layoutIfNeeded()
        attach(screen, name: "点餐页-吸顶")
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
        // 商品在深处时，分类的原生回弹边界限制在 tab 下，不把商品突然拉回顶部。
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
        let arrived = expectation(for: NSPredicate { _, _ in
            abs(f.products.contentOffset.y - target) < 0.5
        }, evaluatedWith: nil)
        wait(for: [arrived], timeout: 3)
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
}

private final class FoodFixture: NSObject, NestedPageViewControllerDataSource, NestedPageViewControllerDelegate {
    let host = NestedPageViewController()
    let category = FoodTestTable()
    let menu: FoodMenuViewController
    let other = FoodTestPage()
    let cover = UIView()
    let tab = UIView()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
    var products: UICollectionView { menu.nestedPageContentScrollView as! UICollectionView }
    var headerBottom: CGFloat { tab.convert(tab.bounds, to: menu.view).maxY }
    var categoryTop: CGFloat { category.superview!.frame.minY }
    var categoryOrigin: CGFloat { category.convert(category.bounds, to: menu.view).minY }
    var categoryDepth: CGFloat { category.contentOffset.y + headerBottom }
    var productDepth: CGFloat { products.contentOffset.y + headerBottom }

    init(short: Bool = false) {
        menu = FoodMenuViewController(categoryTable: category)
        super.init()
        menu.usesShortCategories = short
        menu.pager = host
        host.dataSource = self
        host.delegate = self
        host.headerBounces = false
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

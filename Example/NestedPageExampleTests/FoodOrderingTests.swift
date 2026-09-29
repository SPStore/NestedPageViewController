import XCTest
import UIKit
import NestedPageViewController
import JXCategoryView
@testable import NestedPageExample

/// 使用真正的 UITableView / UICollectionView 和组件的 KVO 链路，模拟拖拽/减速事件。
/// 不代替真机手势验收；尤其不验证 UIKit 手势识别和原生惯性的速度曲线。
@MainActor
final class FoodOrderingTests: XCTestCase {
    private let sharedHeight = FoodMenuViewController.sharedCarouselHeight
    func testActualDemoReadsKeepsContentScrollPositionConfiguration() {
        let config = NestedPageConfig.shared
        let originalValue = config.keepsContentScrollPosition
        defer { config.keepsContentScrollPosition = originalValue }

        for keepsPosition in [false, true] {
            config.keepsContentScrollPosition = keepsPosition
            let screen = UIWindow(frame: UIScreen.main.bounds)
            screen.windowScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            let demo = FoodOrderingViewController()
            screen.rootViewController = UINavigationController(rootViewController: demo)
            screen.makeKeyAndVisible()
            defer { screen.isHidden = true }
            screen.layoutIfNeeded()
            demo.view.layoutIfNeeded()
            let host = demo.children.compactMap { $0 as? NestedPageViewController }.first!
            host.view.layoutIfNeeded()
            XCTAssertEqual(host.keepsContentScrollPosition, keepsPosition)
            XCTAssertFalse(host.headerBounces)

            let menu = host.viewController(at: 0) as! FoodMenuViewController
            menu.view.layoutIfNeeded()
            menu.nestedPageContentScrollView.contentOffset.y = 700
            menu.view.layoutIfNeeded()
            let reset = demo.navigationItem.rightBarButtonItems!.first!
            UIApplication.shared.sendAction(reset.action!, to: reset.target, from: reset, for: nil)
            menu.view.layoutIfNeeded()
            XCTAssertEqual(menu.nestedPageContentScrollView.contentOffset.y,
                           keepsPosition ? 700 : -host.headerHeight, accuracy: 0.1)
        }
    }

    func testActualDemoRendersExpandedAndPinned() {
        let config = NestedPageConfig.shared
        let originalValue = config.keepsContentScrollPosition
        config.keepsContentScrollPosition = true
        defer { config.keepsContentScrollPosition = originalValue }

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
        // 配置开启位置保留时，现有重置只更新布局，不强制清空商品阅读位置。
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

    func testAnimatedExpansionRendersIntermediateStateWithoutMovingReadingPositions() {
        let f = FoodFixture(carousels: true, keepsPosition: true)
        f.products.contentOffset.y = 552
        f.category.contentOffset.y += 90
        let productDepth = f.productDepth
        let categoryDepth = f.categoryDepth
        attach(f.window, name: "展开动画-开始")
        f.menu.expandSharedHeader(animated: true)
        XCTAssertEqual(f.headerBottom, 44, accuracy: 0.1)
        let intermediate = expectation(description: "真实动画中间帧")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            XCTAssertGreaterThan(f.headerBottom, 44)
            XCTAssertLessThan(f.headerBottom, 244)
            XCTAssertEqual(f.productDepth, productDepth, accuracy: 0.1)
            XCTAssertEqual(f.categoryDepth, categoryDepth, accuracy: 0.1)
            self.attach(f.window, name: "展开动画-中间帧")
            intermediate.fulfill()
        }
        wait(for: [intermediate], timeout: 2)
        waitForScroll(f.products, to: productDepth - 244, accuracy: 0.01)
        XCTAssertEqual(f.headerBottom, 244, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, productDepth, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, categoryDepth, accuracy: 0.1)
        attach(f.window, name: "展开动画-完成")
    }

    func testThirdPartyTabExpandsSharedHeaderWithoutResettingEitherList() throws {
        let config = NestedPageConfig.shared
        let originalValue = config.keepsContentScrollPosition
        defer { config.keepsContentScrollPosition = originalValue }
        for keepsPosition in [false, true] {
            config.keepsContentScrollPosition = keepsPosition
            let screen = UIWindow(frame: UIScreen.main.bounds)
            screen.windowScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            let demo = FoodOrderingViewController()
            screen.rootViewController = UINavigationController(rootViewController: demo)
            screen.makeKeyAndVisible()
            defer { screen.isHidden = true }
            screen.layoutIfNeeded()
            demo.view.layoutIfNeeded()
            let host = try XCTUnwrap(demo.children.compactMap { $0 as? NestedPageViewController }.first)
            host.view.layoutIfNeeded()
            let tab = try XCTUnwrap(demo.tabStrip(in: host) as? FoodOrderingTabStrip)
            tab.layoutIfNeeded()
            let menu = try XCTUnwrap(host.viewController(at: 0) as? FoodMenuViewController)
            menu.view.layoutIfNeeded()
            let category = try XCTUnwrap(menu.view.subviews.flatMap(\.subviews).compactMap { $0 as? UITableView }.first)
            XCTAssertFalse(tab.showsBackToTop)
            XCTAssertFalse(tab.isAverageCellSpacingEnabled)
            XCTAssertTrue(tab.contentScrollView === host.containerScrollView)
            let review = try XCTUnwrap(tab.collectionView.cellForItem(at: IndexPath(item: 1, section: 0)) as? JXCategoryTitleImageCell)
            XCTAssertEqual(review.accessibilityValue, "1710 条评价")
            XCTAssertEqual((review.titleLabel.attributedText?.attribute(.font, at: 3, effectiveRange: nil) as? UIFont)?.pointSize, 10)

            // 刚吸顶、公共轮播尚未收完时就应显示箭头；更新首项不能引发横向切页。
            menu.nestedPageContentScrollView.contentOffset.y = -44
            XCTAssertTrue(tab.showsBackToTop)
            XCTAssertEqual(host.currentIndex, 0)
            for startingPage in [0, 1] {
                menu.nestedPageContentScrollView.contentOffset.y = 700
                category.contentOffset.y += 90
                let productDepth = menu.nestedPageContentScrollView.contentOffset.y + 44 - sharedHeight
                let categoryDepth = category.contentOffset.y + 44
                let selectedCategory = category.indexPathForSelectedRow
                if startingPage == 1 {
                    tab.collectionView.delegate?.collectionView?(tab.collectionView, didSelectItemAt: IndexPath(item: 1, section: 0))
                }
                XCTAssertTrue(tab.showsBackToTop)
                // 经由第三方真实点击回调，覆盖重复点击与从评价页点击回点餐两条路径。
                tab.collectionView.delegate?.collectionView?(tab.collectionView, didSelectItemAt: IndexPath(item: 0, section: 0))
                waitForScroll(menu.nestedPageContentScrollView, to: productDepth - 244, accuracy: 0.01)
                menu.view.layoutIfNeeded()
                XCTAssertEqual(host.currentIndex, 0)
                XCTAssertEqual(tab.selectedIndex, 0)
                XCTAssertFalse(tab.showsBackToTop)
                XCTAssertEqual(menu.nestedPageContentScrollView.contentOffset.y + 244, productDepth, accuracy: 0.1)
                XCTAssertEqual(category.contentOffset.y + 244 + sharedHeight, categoryDepth, accuracy: 0.1)
                XCTAssertEqual(category.indexPathForSelectedRow, selectedCategory)
                let shared = try XCTUnwrap((menu.view as? NestedPageDualScrollView)?.sharedContentView)
                XCTAssertEqual(shared.convert(shared.bounds, to: menu.view).minY, 244, accuracy: 0.1)
                XCTAssertFalse(shared.superview!.isHidden)
                if startingPage == 0 { attach(screen, name: "展开封面与共享轮播-保留两列阅读位置") }
            }
        }
    }

    private func waitForScroll(_ scrollView: UIScrollView, to target: CGFloat, accuracy: CGFloat = 0.5) {
        let arrived = expectation(description: "商品滚动到目标分组")
        var fulfilled = false
        // KVO 在 UIKit 修改 offset 的主线程回调；不让异步 predicate 持有整套 UIWindow 测试夹具。
        let observation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { _, change in
            guard let offset = change.newValue, abs(offset.y - target) < accuracy, !fulfilled else { return }
            fulfilled = true
            arrived.fulfill()
        }
        wait(for: [arrived], timeout: 3)
        observation.invalidate()
    }

    func testOrderIndicatorCentersOnTitleExcludingArrow() throws {
        let tab = FoodOrderingTabStrip(frame: CGRect(x: 0, y: 0, width: 390, height: 44))
        tab.layoutIfNeeded()
        tab.collectionView.layoutIfNeeded()
        let line = try XCTUnwrap(tab.indicators.first as? JXCategoryIndicatorLineView)
        for width: CGFloat in [390, 320, 700] {
            tab.frame.size.width = width
            tab.layoutIfNeeded()
            tab.collectionView.layoutIfNeeded()
            for showsArrow in [false, true, false] {
                tab.showsBackToTop = showsArrow
                tab.collectionView.layoutIfNeeded()
                let firstFrame = tab.getTargetCellFrame(0)
                let reviewFrame = tab.getTargetCellFrame(1)
                XCTAssertEqual(firstFrame.width, showsArrow ? 54 : 36, accuracy: 0.1)
                XCTAssertEqual(reviewFrame.minX, showsArrow ? 94 : 76, accuracy: 0.1)
                XCTAssertEqual(reviewFrame.minX - firstFrame.maxX, tab.cellSpacing, accuracy: 0.1)
                // 从其他 Tab 点击回来、初始化和尺寸变化后都应对齐文案。
                for index in [1, 2, 0] {
                    UIView.performWithoutAnimation { tab.selectItem(at: index) }
                    let cell = try XCTUnwrap(tab.collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? JXCategoryTitleImageCell)
                    cell.layoutIfNeeded()
                    let expectedX = index == 0
                        ? cell.titleLabel.convert(cell.titleLabel.bounds, to: tab.collectionView).midX
                        : cell.frame.midX
                    XCTAssertEqual(line.frame.midX, expectedX, accuracy: 0.5)
                }

                let first = try XCTUnwrap(tab.collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? JXCategoryTitleImageCell)
                let review = try XCTUnwrap(tab.collectionView.cellForItem(at: IndexPath(item: 1, section: 0)))
                let titleX = first.titleLabel.convert(first.titleLabel.bounds, to: tab.collectionView).midX
                let model = JXCategoryIndicatorParamsModel()
                model.leftIndex = 0
                model.rightIndex = 1
                model.leftCellFrame = first.frame
                model.rightCellFrame = review.frame
                for progress: CGFloat in [0, 0.25, 0.5, 0.75, 1, 0.5, 0] {
                    model.percent = progress
                    line.jx_contentScrollViewDidScroll(model)
                    XCTAssertEqual(line.frame.midX, titleX + (review.frame.midX - titleX) * progress, accuracy: 0.5)
                    XCTAssertEqual(model.leftCellFrame, first.frame)
                    XCTAssertEqual(model.rightCellFrame, review.frame)
                }
            }
        }
    }

    func testChangingArrowWidthPreservesInFlightPagingPosition() throws {
        let tab = FoodOrderingTabStrip(frame: CGRect(x: 0, y: 0, width: 390, height: 44))
        tab.layoutIfNeeded()
        let paging = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        paging.contentSize = CGSize(width: 1170, height: 600)
        tab.contentScrollView = paging
        defer { tab.contentScrollView = nil }
        let line = try XCTUnwrap(tab.indicators.first as? JXCategoryIndicatorLineView)
        for selectedIndex in 0..<3 {
            UIView.performWithoutAnimation { tab.selectItem(at: selectedIndex) }
            for progress: CGFloat in [0, 0.35, 1, 1.5, 2] {
                paging.contentOffset.x = progress * paging.bounds.width
                let offset = paging.contentOffset
                var offsetChanges = 0
                let observation = paging.observe(\.contentOffset, options: [.new]) { _, _ in offsetChanges += 1 }
                for showsArrow in [true, false] {
                    tab.showsBackToTop = showsArrow
                    XCTAssertEqual(paging.contentOffset, offset)
                    XCTAssertEqual(tab.selectedIndex, selectedIndex)
                    let left = Int(floor(progress))
                    let right = min(left + 1, 2)
                    let titleOffset: CGFloat = showsArrow ? 9 : 0
                    let leftX = tab.getTargetCellFrame(left).midX - (left == 0 ? titleOffset : 0)
                    let rightX = tab.getTargetCellFrame(right).midX - (right == 0 ? titleOffset : 0)
                    XCTAssertEqual(line.frame.midX, leftX + (rightX - leftX) * (progress - CGFloat(left)), accuracy: 0.5)
                }
                XCTAssertEqual(offsetChanges, 0)
                observation.invalidate()
            }
        }
    }

    func testLeavingDemoDetachesThirdPartyPagingReference() {
        weak var releasedDemo: FoodOrderingViewController?
        var retainedTab: FoodOrderingTabStrip?
        autoreleasepool {
            let screen = UIWindow(frame: UIScreen.main.bounds)
            screen.windowScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            let demo = FoodOrderingViewController()
            releasedDemo = demo
            let navigation = UINavigationController(rootViewController: UIViewController())
            screen.rootViewController = navigation
            screen.makeKeyAndVisible()
            finishNavigationTransition()
            navigation.pushViewController(demo, animated: false)
            finishNavigationTransition()
            screen.layoutIfNeeded()
            demo.view.layoutIfNeeded()
            let host = demo.children.compactMap { $0 as? NestedPageViewController }.first!
            retainedTab = demo.tabStrip(in: host) as? FoodOrderingTabStrip
            XCTAssertNotNil(retainedTab?.contentScrollView)
            retainedTab?.selectItem(at: 1)
            navigation.pushViewController(UIViewController(), animated: false)
            finishNavigationTransition()
            XCTAssertNil(retainedTab?.contentScrollView)
            navigation.popViewController(animated: false)
            finishNavigationTransition()
            XCTAssertTrue(retainedTab?.contentScrollView === host.containerScrollView)
            XCTAssertEqual(retainedTab?.selectedIndex, 1)
            XCTAssertEqual(host.currentIndex, 1)
            navigation.popViewController(animated: false)
            finishNavigationTransition()
            XCTAssertNil(retainedTab?.contentScrollView)
            screen.isHidden = true
            screen.rootViewController = nil
        }
        // UIKit 的非动画转场也会延后释放导航上下文，等主队列完成这一轮事务。
        finishNavigationTransition()
        XCTAssertNil(releasedDemo)
        XCTAssertNil(retainedTab?.contentScrollView)
    }

    private func finishNavigationTransition() {
        let finished = expectation(description: "导航转场已完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { finished.fulfill() }
        wait(for: [finished], timeout: 1)
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

    func testSelectingLastProductSectionPinsItBelowTab() throws {
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
        XCTAssertEqual(f.categoryTop, 244 + sharedHeight, accuracy: 0.1)
        XCTAssertEqual(f.categoryOrigin, 0, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        let shared = try XCTUnwrap(f.products.layoutAttributesForItem(at: IndexPath(item: 0, section: 0)))
        let right = try XCTUnwrap(f.products.layoutAttributesForItem(at: IndexPath(item: 0, section: 1)))
        XCTAssertEqual(shared.frame, CGRect(x: 0, y: 0, width: 390, height: sharedHeight))
        XCTAssertEqual(right.frame.minX, 104, accuracy: 0.1)
        XCTAssertEqual(right.frame.minY, sharedHeight, accuracy: 0.1)
        let sharedView = try XCTUnwrap((f.menu.view as? NestedPageDualScrollView)?.sharedContentView as? FoodCarouselView)
        let rightView = try XCTUnwrap(f.products.cellForItem(at: IndexPath(item: 0, section: 1))?.contentView.subviews.first as? FoodCarouselView)
        sharedView.layoutIfNeeded()
        rightView.layoutIfNeeded()
        XCTAssertFalse(sharedView.isPagingEnabled)
        XCTAssertTrue(rightView.isPagingEnabled)
        XCTAssertEqual(sharedView.subviews.filter { $0.accessibilityIdentifier?.hasPrefix("food.sharedCarousel.card.") == true }.count, 6)
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
            let carousel = try XCTUnwrap(section == 0
                ? (f.menu.view as? NestedPageDualScrollView)?.sharedContentView as? FoodCarouselView
                : f.products.cellForItem(at: IndexPath(item: 0, section: section))?.contentView.subviews.first as? FoodCarouselView)
            let pagingGuard = try XCTUnwrap(carousel.gestureRecognizers?.first { $0 is NestedPagePagingGestureGuard })
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
        XCTAssertEqual(f.categoryTop, 44 + sharedHeight, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        f.moveCategories(by: 80)
        XCTAssertEqual(f.headerBottom, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 44 + sharedHeight - 80, accuracy: 0.1)
        f.moveCategories(by: sharedHeight - 80 + 40)
        XCTAssertEqual(f.categoryTop, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryOrigin, 0, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 40, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.products.contentOffset.y, sharedHeight - 44, accuracy: 0.1)
        f.moveCategories(by: 100)
        XCTAssertEqual(f.categoryDepth, 140, accuracy: 0.1)
        XCTAssertEqual(f.products.contentOffset.y, sharedHeight - 44, accuracy: 0.1)
    }

    func testCategoryDecelerationCrossesBothSharedBoundaries() {
        let f = FoodFixture(carousels: true)
        f.moveCategories(by: 180)
        f.category.simulatesDeceleration = true
        for delta: CGFloat in [50, sharedHeight - 60, 70, 20] { f.moveCategories(by: delta, dragging: false) }
        XCTAssertEqual(f.headerBottom, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 60, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
    }

    func testRightCarouselScrollDoesNotMoveCategoryReadingPosition() {
        let f = FoodFixture(carousels: true)
        f.products.contentOffset.y = -44
        XCTAssertEqual(f.categoryTop, 44 + sharedHeight, accuracy: 0.1)
        f.products.contentOffset.y += 80
        XCTAssertEqual(f.categoryTop, 44 + sharedHeight - 80, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        f.products.contentOffset.y = sharedHeight - 44
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
        f.moveCategories(by: 200 + sharedHeight + 50)
        f.moveCategories(by: -80)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.headerBottom, 44, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 74, accuracy: 0.1)
        f.moveCategories(by: -sharedHeight - 30)
        XCTAssertEqual(f.headerBottom, 104, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 104 + sharedHeight, accuracy: 0.1)
        f.moveCategories(by: -140)
        f.moveCategories(by: -40)
        f.moveCategories(by: 40)
        XCTAssertEqual(f.headerBottom, 244, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 244 + sharedHeight, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
    }

    func testShortCategoriesCanConsumeEntireSharedCarousel() {
        let f = FoodFixture(short: true, carousels: true)
        let size = f.category.contentSize
        let maximumOffset = size.height - f.category.bounds.height + f.category.contentInset.bottom
        XCTAssertGreaterThanOrEqual(maximumOffset, -44)
        f.moveCategories(by: 200 + sharedHeight)
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
        f.moveCategories(by: 200 + sharedHeight + 50)
        f.host.scrollToPage(at: 1, animated: false)
        f.other.scroll.contentOffset.y = -164
        f.host.scrollToPage(at: 0, animated: false)
        XCTAssertEqual(f.headerBottom, 164, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 164 + sharedHeight, accuracy: 0.1)
        XCTAssertEqual(f.categoryOrigin, 0, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, 50, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        f.host.view.frame.size = CGSize(width: 700, height: 390)
        f.host.updateLayouts()
        f.synchronizeHeader()
        f.menu.resetCategoryPosition()
        XCTAssertEqual(f.categoryTop, f.headerBottom + sharedHeight, accuracy: 0.1)
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

    func testExplicitExpansionPreservesReadingThroughBothSharedBoundaries() {
        for keepsPosition in [false, true] {
            for depth: CGFloat in [0, 80, 600] {
                for viaCategories in [false, true] {
                    let f = FoodFixture(carousels: true, keepsPosition: keepsPosition)
                    f.products.contentOffset.y = sharedHeight - 44 + depth
                    f.category.contentOffset.y += 90
                    let categoryDepth = f.categoryDepth
                    for _ in 0..<3 {
                        f.menu.expandSharedHeader()
                        XCTAssertEqual(f.headerBottom, 244, accuracy: 0.1)
                        XCTAssertEqual(f.categoryTop, 244 + sharedHeight, accuracy: 0.1)
                        XCTAssertEqual(f.productDepth, depth, accuracy: 0.1)
                        XCTAssertEqual(f.categoryDepth, categoryDepth, accuracy: 0.1)
                        for delta: CGFloat in [120, 100, sharedHeight - 20] {
                            if viaCategories { f.moveCategories(by: delta) }
                            else { f.products.contentOffset.y += delta }
                            XCTAssertEqual(f.productDepth, depth, accuracy: 0.1)
                            XCTAssertEqual(f.categoryDepth, categoryDepth, accuracy: 0.1)
                        }
                        XCTAssertEqual(f.headerBottom, 44, accuracy: 0.1)
                        XCTAssertEqual(f.categoryTop, 44, accuracy: 0.1)
                    }
                }
            }
        }
    }

    func testExpandedSharedCarouselDoesNotReappearAtSavedProductDepth() {
        let f = FoodFixture(carousels: true, keepsPosition: true)
        f.products.contentOffset.y = 700
        f.menu.expandSharedHeader()
        f.products.contentOffset.y += 200 + 80
        XCTAssertEqual(f.categoryTop, 44 + sharedHeight - 80, accuracy: 0.1)
        f.products.contentOffset.y -= 40
        // 下拉应先阅读前面的商品，而不是提前展开共享轮播。
        XCTAssertEqual(f.categoryTop, 44 + sharedHeight - 80, accuracy: 0.1)
        f.products.contentOffset.y = -44
        XCTAssertEqual(f.categoryTop, 44 + sharedHeight, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, 0, accuracy: 0.1)
        f.products.contentOffset.y = -244
        XCTAssertEqual(f.categoryTop, 244 + sharedHeight, accuracy: 0.1)
    }

    func testExplicitExpansionAlsoHandlesShortCategoriesAndNoCarousel() {
        for carousels in [false, true] {
            let f = FoodFixture(short: true, carousels: carousels)
            f.products.contentOffset.y = 700
            let depth = f.productDepth
            f.menu.expandSharedHeader()
            XCTAssertEqual(f.headerBottom, 244, accuracy: 0.1)
            XCTAssertEqual(f.categoryTop, 244 + (carousels ? sharedHeight : 0), accuracy: 0.1)
            XCTAssertEqual(f.productDepth, depth, accuracy: 0.1)
            // 左栏下拉只回到自己的边界，不能拖走保留中的商品。
            f.moveCategories(by: -f.category.contentInset.top - f.category.contentOffset.y)
            XCTAssertEqual(f.categoryDepth, 0, accuracy: 0.1)
            XCTAssertEqual(f.productDepth, depth, accuracy: 0.1)
            f.moveCategories(by: 200 + (carousels ? sharedHeight : 0))
            XCTAssertEqual(f.categoryTop, 44, accuracy: 0.1)
            XCTAssertEqual(f.productDepth, depth, accuracy: 0.1)
        }
    }

    func testExpandedSharedContentSurvivesKeptPageSwitchAndLayout() {
        let f = FoodFixture(carousels: true, keepsPosition: true)
        f.products.contentOffset.y = 700
        f.category.contentOffset.y += 90
        let productDepth = f.productDepth
        let categoryDepth = f.categoryDepth
        f.menu.expandSharedHeader()
        XCTAssertEqual(f.categoryDepth, categoryDepth, accuracy: 0.1, "展开后")
        f.host.scrollToPage(at: 1, animated: false)
        XCTAssertEqual(f.categoryDepth, categoryDepth, accuracy: 0.1, "切出后")
        f.host.scrollToPage(at: 0, animated: false)
        XCTAssertEqual(f.categoryDepth, categoryDepth, accuracy: 0.1, "切回后")
        f.host.updateLayouts()
        f.synchronizeHeader()
        XCTAssertEqual(f.headerBottom, 244, accuracy: 0.1)
        XCTAssertEqual(f.categoryTop, 244 + sharedHeight, accuracy: 0.1)
        XCTAssertEqual(f.productDepth, productDepth, accuracy: 0.1)
        XCTAssertEqual(f.categoryDepth, categoryDepth, accuracy: 0.1)
    }

    func testCategorySelectionAfterExpansionStillPinsTargetSection() throws {
        let f = FoodFixture(carousels: true, keepsPosition: true)
        f.products.contentOffset.y = 1200
        f.menu.expandSharedHeader()
        let first = IndexPath(item: 0, section: 2)
        _ = try XCTUnwrap(f.products.collectionViewLayout.layoutAttributesForSupplementaryView(
            ofKind: UICollectionView.elementKindSectionHeader, at: first))
        // 使用原始商品内容起点（共享区 + 右侧轮播及间距），不使用吸顶后的标题 frame。
        let target = sharedHeight + FoodMenuViewController.productCarouselHeight + 12 - 44
        f.menu.tableView(f.category, didSelectRowAt: IndexPath(row: 0, section: 0))
        waitForScroll(f.products, to: target)
        XCTAssertEqual(f.categoryTop, 44, accuracy: 0.5)
        XCTAssertEqual(f.category.indexPathForSelectedRow?.row, 0)
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

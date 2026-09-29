import XCTest
import UIKit
import NestedPageViewController
@testable import NestedPageExample

@MainActor
final class ExampleSafeAreaTests: XCTestCase {
    func testNoHeaderNavigationTabIndicatorOnFirstAppearanceAndResize() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = NoHeaderViewController()
        let navigation = NavigationController(rootViewController: root)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }

        for size in [CGSize(width: 390, height: 844), CGSize(width: 844, height: 390)] {
            window.frame.size = size
            window.setNeedsLayout()
            window.layoutIfNeeded()
            root.view.layoutIfNeeded()
            settleAppearance()

            let strip = try XCTUnwrap(root.navigationItem.titleView as? NestedPageTabStripView)
            let stack = try XCTUnwrap(strip.subviews.compactMap { $0 as? UIStackView }.first)
            let indicator = try XCTUnwrap(strip.subviews.first { !($0 is UIStackView) })
            XCTAssertEqual(strip.selectedIndex, 1)
            XCTAssertGreaterThan(strip.bounds.height, 0)
            let selectedCenter = stack.convert(stack.arrangedSubviews[1].center, to: strip)
            XCTAssertEqual(indicator.frame.midX, selectedCenter.x, accuracy: 0.5)
            XCTAssertEqual(indicator.frame.maxY, strip.bounds.height, accuracy: 0.5)
        }
    }

    func testExampleListTextFitsAfterWidthChanges() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let list = ExampleListViewController()
        window.rootViewController = list
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        // 为侧边系统栏预留空间，覆盖比普通 iPhone 更窄的内容区。
        list.additionalSafeAreaInsets = UIEdgeInsets(top: 14, left: 12, bottom: 20, right: 80)
        let table = try XCTUnwrap(list.view.subviews.compactMap { $0 as? UITableView }.first)
        XCTAssertEqual(table.rowHeight, UITableView.automaticDimension)
        for width: CGFloat in [390, 320, 844, 390] {
            window.frame.size.width = width
            window.setNeedsLayout()
            window.layoutIfNeeded()
            list.view.layoutIfNeeded()
            table.layoutIfNeeded()
            for (section, group) in ExampleTypeModel.demoGroups().enumerated() {
                for (row, model) in group.examples.enumerated() {
                    let index = IndexPath(row: row, section: section)
                    table.scrollToRow(at: index, at: .middle, animated: false)
                    table.layoutIfNeeded()
                    let cell = try XCTUnwrap(table.cellForRow(at: index), model.title)
                    cell.layoutIfNeeded()
                    for label in [cell.textLabel, cell.detailTextLabel].compactMap({ $0 }) where !(label.text ?? "").isEmpty {
                        let required = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                        XCTAssertEqual(label.numberOfLines, 0, model.title)
                        XCTAssertGreaterThanOrEqual(label.bounds.height + 0.5, required.height, model.title)
                        let frame = label.convert(label.bounds, to: cell.contentView)
                        XCTAssertGreaterThanOrEqual(frame.minY, -0.5, model.title)
                        XCTAssertLessThanOrEqual(frame.maxY, cell.contentView.bounds.height + 0.5, model.title)
                    }
                    if model.targetClass == FoodOrderingViewController.self && width <= 390 {
                        XCTAssertGreaterThan(cell.bounds.height, 60, "窄屏外卖示例必须随多行文案增高")
                    }
                }
            }
        }
    }

    func testStoryboardTabConfiguration() throws {
        let root = try XCTUnwrap(UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? TabBarController)
        root.loadViewIfNeeded()
        if #available(iOS 18.0, *) {
            XCTAssertEqual(root.tabs.map(\.identifier), ["examples", "settings"])
            XCTAssertEqual(root.tabs.map(\.title), ["示例", "设置"])
            XCTAssertTrue(root.selectedTab === root.tabs[0])
            XCTAssertTrue(root.tabs[0].viewController === root.exampleNavigationController)
            let settings = try XCTUnwrap(root.tabs[1].viewController as? NavigationController)
            settings.loadViewIfNeeded()
            XCTAssertEqual(settings.navigationBar.tintColor, UIColor.label)
            XCTAssertTrue(settings.viewControllers.first is SettingsViewController)
            root.selectedTab = root.tabs[1]
            XCTAssertTrue(root.selectedViewController === settings)
            root.selectedTab = root.tabs[0]
            XCTAssertTrue(root.selectedViewController === root.exampleNavigationController)
            if #available(iOS 26.1, *) {
                XCTAssertNotNil(root.tabs[0].selectedImage)
                XCTAssertNotNil(root.tabs[1].selectedImage)
            }
        } else {
            XCTAssertEqual(root.viewControllers?.count, 2)
            XCTAssertTrue(root.viewControllers?.first === root.exampleNavigationController)
        }
        if #available(iOS 26.0, *) {
            XCTAssertEqual(root.tabBar.backgroundColor?.cgColor.alpha, 0)
            XCTAssertEqual(root.tabBar.standardAppearance.backgroundColor?.cgColor.alpha ?? 0, 0)
            XCTAssertEqual(root.tabBar.scrollEdgeAppearance?.backgroundColor?.cgColor.alpha ?? 0, 0)
            XCTAssertNil(root.tabBar.standardAppearance.backgroundEffect)
            XCTAssertNil(root.tabBar.scrollEdgeAppearance?.backgroundEffect)
            XCTAssertTrue(root.tabBar.isTranslucent)
        } else {
            XCTAssertFalse(root.tabBar.isTranslucent)
        }
    }

    func testAllExamplesFitPortraitSafeArea() throws {
        try verifyExamples(size: CGSize(width: 390, height: 844))
    }

    func testAllExamplesFitLandscapeSafeArea() throws {
        try verifyExamples(size: CGSize(width: 844, height: 390))
    }

    private func verifyExamples(size: CGSize) throws {
        let animationsEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animationsEnabled) }

        for (section, group) in ExampleTypeModel.demoGroups().enumerated() {
            for (row, model) in group.examples.enumerated() {
                try autoreleasepool {
                    let window = UIWindow(frame: CGRect(origin: .zero, size: size))
                    let list = ExampleListViewController()
                    let navigation = ImmediateExampleNavigationController(rootViewController: list)
                    let tabs = UITabBarController()
                    tabs.viewControllers = [navigation]
                    window.rootViewController = tabs
                    window.makeKeyAndVisible()
                    defer {
                        window.isHidden = true
                        window.rootViewController = nil
                    }
                    window.layoutIfNeeded()
                    list.view.layoutIfNeeded()
                    settleAppearance()
                    XCTAssertEqual(window.bounds.size, size)
                    let table = try XCTUnwrap(list.view.subviews.compactMap { $0 as? UITableView }.first)
                    list.tableView(table, didSelectRowAt: IndexPath(row: row, section: section))
                    let root = try XCTUnwrap(navigation.topViewController)
                    // 模拟非零的四边安全距离，检查横屏左右和底部没有被忽略。
                    root.additionalSafeAreaInsets = UIEdgeInsets(top: 7, left: 19, bottom: 11, right: 23)
                    window.layoutIfNeeded()
                    navigation.view.layoutIfNeeded()
                    root.view.layoutIfNeeded()
                    settleAppearance()

                    let pager = try XCTUnwrap(root.children.compactMap { $0 as? NestedPageViewController }.first, model.title)
                    XCTAssertEqual(navigation.navigationBar.tintColor, UIColor.label, model.title)
                    pager.view.layoutIfNeeded()
                    let safeFrame = root.view.safeAreaLayoutGuide.layoutFrame
                    var expected = expectedPagerFrame(in: root)
                    assertEqual(pager.view.frame, expected, model.title)
                    XCTAssertFalse(pager.view.translatesAutoresizingMaskIntoConstraints, model.title)
                    XCTAssertFalse(pager.view.hasAmbiguousLayout, model.title)
                    assertEqual(pager.containerScrollView.frame, pager.view.bounds, model.title)

                    if root is SafeAreaExampleHostViewController {
                        // 安全区由宿主处理，继承型组件不能再额外扣一次导航栏 / TabBar。
                        XCTAssertEqual(root.hidesBottomBarWhenPushed, pager is NoBouncesViewController)
                    }

                    let child = try XCTUnwrap(pager.viewController(at: pager.currentIndex), model.title)
                    child.view.layoutIfNeeded()
                    let scrollView = child.nestedPageContentScrollView
                    var expectedScrollFrame = child.view.safeAreaLayoutGuide.layoutFrame
                    if root is HeaderZoomViewController || root is FoodOrderingViewController {
                        expectedScrollFrame.size.height += expectedScrollFrame.minY
                        expectedScrollFrame.origin.y = 0
                    }
                    assertEqual(scrollView.frame, expectedScrollFrame, model.title)

                    if root is ObjcExmpleViewController {
                        XCTAssertEqual(pager.stickyOffset, 44, model.title)
                        let back = try XCTUnwrap(root.view.subviews.compactMap { $0 as? UIButton }.first)
                        XCTAssertEqual(back.tintColor, UIColor.label, model.title)
                        XCTAssertTrue(safeFrame.contains(back.frame), model.title)
                    }
                    if let headerZoom = root as? HeaderZoomViewController {
                        try verifyHeaderZoom(headerZoom, pager: pager)
                        // 顶部安全区改变后，仍应以系统导航栏的实际底边作为吸顶位置。
                        root.additionalSafeAreaInsets.top += 13
                        window.layoutIfNeeded()
                        root.view.layoutIfNeeded()
                        pager.view.layoutIfNeeded()
                        try verifyHeaderZoom(headerZoom, pager: pager)
                    }
                    if root is FoodOrderingViewController {
                        try verifyFoodCart(in: root)
                        try verifyFoodNavigationBackground(in: root)
                    }

                    // 安全区改变后约束应自动重排，不依赖 viewDidLoad 时读取到的 inset。
                    root.additionalSafeAreaInsets.bottom += 17
                    root.additionalSafeAreaInsets.left += 9
                    window.layoutIfNeeded()
                    root.view.layoutIfNeeded()
                    pager.view.layoutIfNeeded()
                    expected = expectedPagerFrame(in: root)
                    assertEqual(pager.view.frame, expected, model.title)
                    assertEqual(pager.containerScrollView.frame, pager.view.bounds, model.title)
                    if root is FoodOrderingViewController {
                        try verifyFoodCart(in: root)
                        try verifyFoodNavigationBackground(in: root)
                    }
                }
            }
        }
    }

    private func expectedPagerFrame(in root: UIViewController) -> CGRect {
        var frame = root.view.safeAreaLayoutGuide.layoutFrame
        if root is HeaderZoomViewController || root is FoodOrderingViewController {
            frame.size.height += frame.minY
            frame.origin.y = 0
        }
        if root is FoodOrderingViewController { frame.size.height -= 58 }
        return frame
    }

    private func verifyFoodCart(in root: UIViewController) throws {
        let safeFrame = root.view.safeAreaLayoutGuide.layoutFrame
        let label = try XCTUnwrap(findView(in: root.view, identifier: "food.cart"))
        let cart = try XCTUnwrap(label.superview)
        let top = safeFrame.maxY - 58
        assertEqual(cart.frame, CGRect(x: 0, y: top, width: root.view.bounds.width,
                                      height: root.view.bounds.maxY - top), "购物车背景覆盖安全区")
        assertEqual(label.convert(label.bounds, to: root.view),
                    CGRect(x: safeFrame.minX + 20, y: top, width: safeFrame.width - 40, height: 58),
                    "购物车文字留在安全区内")
        for style: UIUserInterfaceStyle in [.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let background = try XCTUnwrap(cart.backgroundColor?.resolvedColor(with: traits))
            XCTAssertNotEqual(background, UIColor.secondarySystemBackground.resolvedColor(with: traits))
            XCTAssertEqual(background.cgColor.alpha, 1)
        }
    }

    private func verifyFoodNavigationBackground(in root: UIViewController) throws {
        let background = try XCTUnwrap(root.view.subviews.first { $0.accessibilityIdentifier == "food.navigationBackground" })
        let navigationBar = try XCTUnwrap(root.navigationController?.navigationBar)
        let bottom = max(0, navigationBar.convert(navigationBar.bounds, to: root.view).maxY)
        assertEqual(background.frame, CGRect(x: 0, y: 0, width: root.view.bounds.width, height: bottom),
                    "顶部背景覆盖屏幕顶边、左右安全区和导航栏")
        XCTAssertFalse(background.translatesAutoresizingMaskIntoConstraints)
        XCTAssertFalse(background.hasAmbiguousLayout)
        XCTAssertFalse(background.isUserInteractionEnabled)
        XCTAssertTrue(root.view.subviews.last === background, "背景必须在封面上层")
        for style: UIUserInterfaceStyle in [.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            XCTAssertEqual(background.backgroundColor?.resolvedColor(with: traits),
                           UIColor.systemBackground.resolvedColor(with: traits))
        }
    }

    private func verifyHeaderZoom(_ root: HeaderZoomViewController, pager: NestedPageViewController) throws {
        let cover = try XCTUnwrap(root.coverView(in: pager) as? ProfileCoverView)
        let navigation = try XCTUnwrap(root.navigationController)
        let navigationBar = navigation.navigationBar
        let originalAppearance = navigationBar.standardAppearance.copy() as! UINavigationBarAppearance
        let navigationBottom = max(0, navigationBar.convert(navigationBar.bounds, to: root.view).maxY)
        XCTAssertFalse(navigation.isNavigationBarHidden)
        XCTAssertFalse(root.navigationItem.hidesBackButton)
        XCTAssertNil(root.navigationItem.leftBarButtonItem)
        XCTAssertNil(root.navigationItem.titleView)
        XCTAssertFalse(root.view.subviews.contains { $0 is UIButton })
        XCTAssertEqual(pager.stickyOffset, navigationBottom, accuracy: 0.5)
        for index in 0..<root.numberOfViewControllers(in: pager) {
            pager.scrollToPage(at: index, animated: false)
            pager.scrollToTop(animated: false)
            pager.view.layoutIfNeeded()
            let child = try XCTUnwrap(pager.viewController(at: index))
            child.view.layoutIfNeeded()
            let scrollView = child.nestedPageContentScrollView
            if #available(iOS 26.0, *) {
                XCTAssertTrue(scrollView.topEdgeEffect.isHidden)
                XCTAssertTrue(pager.containerScrollView.topEdgeEffect.isHidden)
            }
            XCTAssertEqual(scrollView.frame.minY, 0, accuracy: 0.5)
            XCTAssertEqual(cover.convert(cover.bounds, to: root.view).minY, 0, accuracy: 0.5)
            assertNavigationProgress(root, expected: 0)

            let collapseDistance = root.heightForCoverView(in: pager) - pager.stickyOffset
            scrollView.setContentOffset(CGPoint(x: 0, y: -pager.headerHeight + collapseDistance / 2), animated: false)
            assertNavigationProgress(root, expected: 0.5)

            scrollView.setContentOffset(.zero, animated: false)
            XCTAssertEqual(cover.convert(cover.bounds, to: root.view).maxY, navigationBottom, accuracy: 0.5)
            assertNavigationProgress(root, expected: 1)

            scrollView.setContentOffset(CGPoint(x: 0, y: -pager.headerHeight - 80), animated: false)
            XCTAssertEqual(cover.bgImageView.frame.height, root.heightForCoverView(in: pager) + 80, accuracy: 0.5)
            XCTAssertEqual(cover.bgImageView.convert(cover.bgImageView.bounds, to: root.view).minY, 0, accuracy: 0.5)
            assertNavigationProgress(root, expected: 0)
            pager.scrollToTop(animated: false)
        }
        XCTAssertEqual(navigationBar.standardAppearance, originalAppearance)
    }

    private func assertNavigationProgress(_ root: HeaderZoomViewController, expected: CGFloat,
                                          file: StaticString = #filePath, line: UInt = #line) {
        let appearances = [root.navigationItem.standardAppearance, root.navigationItem.scrollEdgeAppearance,
                           root.navigationItem.compactAppearance, root.navigationItem.compactScrollEdgeAppearance]
        for appearance in appearances {
            XCTAssertEqual(appearance?.backgroundColor?.cgColor.alpha ?? -1, expected, accuracy: 0.01, file: file, line: line)
            let titleColor = appearance?.titleTextAttributes[.foregroundColor] as? UIColor
            XCTAssertEqual(titleColor?.cgColor.alpha ?? -1, expected, accuracy: 0.01, file: file, line: line)
        }
    }

    private func assertEqual(_ actual: CGRect, _ expected: CGRect, _ context: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.5, context, file: file, line: line)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.5, context, file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: 0.5, context, file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: 0.5, context, file: file, line: line)
    }

    private func settleAppearance() {
        let settled = expectation(description: "完成窗口和导航的显示事务")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 1)
    }

    private func findView(in view: UIView, identifier: String) -> UIView? {
        if view.accessibilityIdentifier == identifier { return view }
        return view.subviews.lazy.compactMap { self.findView(in: $0, identifier: identifier) }.first
    }
}

/// 布局检查不等待导航转场动画；仍通过实际示例入口创建宿主与页面。
private final class ImmediateExampleNavigationController: NavigationController {
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: false)
    }
}

import XCTest

/// 真正向模拟器发送横拖 / 纵拖，补充单元测试无法覆盖的手势识别链路。
final class FoodCarouselUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-food-demo"]
        app.launch()
        XCTAssertTrue(app.collectionViews["food.products"].waitForExistence(timeout: 10))
    }

    override func tearDownWithError() throws {
        if let app, let testRun, testRun.failureCount > 0 {
            capture("失败现场")
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        app = nil
    }

    func testSharedCarouselHorizontalDragDoesNotSwitchTabAndVerticalDragScrollsPage() {
        let carousel = app.scrollViews["food.sharedCarousel"]
        let first = app.descendants(matching: .any)["food.sharedCarousel.card.0"].firstMatch
        let initialX = first.frame.minX
        let initialY = carousel.frame.minY
        carousel.swipeLeft(velocity: .slow)
        XCTAssertLessThan(first.frame.minX, initialX - 30)
        XCTAssertEqual(carousel.frame.minY, initialY, accuracy: 2)
        XCTAssertTrue(app.collectionViews["food.products"].isHittable)
        XCTAssertFalse(app.tables["food.reviews"].isHittable)
        let start = carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.7))
        let end = start.withOffset(CGVector(dx: 0, dy: -100))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 120, thenHoldForDuration: 0.2)
        XCTAssertLessThan(carousel.frame.minY, initialY - 50)
        capture("公共轮播-横滑与纵滑")
    }

    func testLeftDragHidesSharedCarouselButPreservesRightCarousel() {
        let right = app.scrollViews["food.productCarousel"]
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.82))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.22))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 180, thenHoldForDuration: 0.2)
        XCTAssertFalse(app.scrollViews["food.sharedCarousel"].isHittable)
        XCTAssertTrue(right.isHittable)
        let pinnedRightY = right.frame.minY
        let secondStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.65))
        secondStart.press(forDuration: 0.05, thenDragTo: secondStart.withOffset(CGVector(dx: 0, dy: -100)), withVelocity: 120, thenHoldForDuration: 0.2)
        XCTAssertEqual(right.frame.minY, pinnedRightY, accuracy: 2)
        right.swipeLeft(velocity: .slow)
        XCTAssertTrue(app.descendants(matching: .any)["food.productCarousel.card.1"].firstMatch.isHittable)
        XCTAssertEqual(right.frame.minY, pinnedRightY, accuracy: 2)
        XCTAssertTrue(app.collectionViews["food.products"].isHittable)
        capture("左栏收起公共轮播-右侧轮播保留")

        // 从右侧商品区域纵拖，才会把右侧轮播也卷走。
        let productStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.70))
        productStart.press(forDuration: 0.05, thenDragTo: productStart.withOffset(CGVector(dx: 0, dy: -180)), withVelocity: 160, thenHoldForDuration: 0.2)
        XCTAssertFalse(right.isHittable)
        capture("右栏单独收起小轮播")
    }

    func testBothCarouselsKeepPagingPriorityAtEdgesAndOnDiagonalDrags() {
        for identifier in ["food.sharedCarousel", "food.productCarousel"] {
            if identifier == "food.productCarousel" {
                // 由左栏收起共享区域，右侧轮播仍在其独立内容顶部。
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.82))
                let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.22))
                start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 180, thenHoldForDuration: 0.2)
            }
            let carousel = app.scrollViews[identifier]
            XCTAssertTrue(carousel.isHittable)
            // 从第一页向外拖；再到末页继续左拖，边缘也不能交给横向分页。
            carousel.swipeRight(velocity: .slow)
            assertMenuRemainsVisible()
            for _ in 0..<4 {
                carousel.swipeLeft(velocity: .slow)
                assertMenuRemainsVisible()
            }
            // 向下斜拖避免把轮播卷出屏幕，覆盖横向占优和纵向占优两种起手。
            for delta in [CGVector(dx: -150, dy: 90), CGVector(dx: -130, dy: 150)] {
                let start = carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.35))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(delta), withVelocity: 220, thenHoldForDuration: 0.2)
                assertMenuRemainsVisible()
            }
            capture("\(identifier)-边缘与斜拖不切页")
            if identifier == "food.productCarousel" {
                let initialY = carousel.frame.minY
                let start = carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.8))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -70)), withVelocity: 120, thenHoldForDuration: 0.2)
                XCTAssertLessThan(carousel.frame.minY, initialY - 30)
                assertMenuRemainsVisible()
            }
        }
    }

    func testPartiallyVisibleCarouselKeepsPriorityAndAllowsSystemBack() {
        let leftStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.80))
        leftStart.press(forDuration: 0.05, thenDragTo: leftStart.withOffset(CGVector(dx: 0, dy: -300)), withVelocity: 180, thenHoldForDuration: 0.2)
        let carousel = app.scrollViews["food.sharedCarousel"]
        let tab = foodTab(at: 0)
        XCTAssertTrue(carousel.isHittable)
        XCTAssertLessThan(carousel.frame.minY, tab.frame.maxY)
        let firstCard = app.descendants(matching: .any)["food.sharedCarousel.card.0"].firstMatch
        let initialX = firstCard.frame.minX
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: app.frame.width * 0.8, dy: tab.frame.maxY + 40))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -220, dy: 15)), withVelocity: 220, thenHoldForDuration: 0.2)
        XCTAssertLessThan(firstCard.frame.minX, initialX - 30)
        assertMenuRemainsVisible()

        // 轮播优先于分页，但不能吞掉导航控制器的系统边缘返回。
        let edge = origin.withOffset(CGVector(dx: 2, dy: tab.frame.maxY + 40))
        edge.press(forDuration: 0.05, thenDragTo: edge.withOffset(CGVector(dx: app.frame.width * 0.8, dy: 0)), withVelocity: 400, thenHoldForDuration: 0.2)
        XCTAssertFalse(app.navigationBars["外卖点餐双列表"].exists)
    }

    private func assertMenuRemainsVisible(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.collectionViews["food.products"].isHittable, file: file, line: line)
        XCTAssertFalse(app.tables["food.reviews"].isHittable, file: file, line: line)
        XCTAssertEqual(app.collectionViews["food.products"].frame.minX, 0, accuracy: 2, file: file, line: line)
    }

    func testTabSwitchAndLayoutKeepProductReadingPosition() {
        enableKeepsContentScrollPosition()
        app.collectionViews["food.products"].swipeUp()
        let visibleProduct = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "food.add.")).allElementsBoundByIndex.first { $0.isHittable }!
        let productIdentifier = visibleProduct.identifier
        let originalY = visibleProduct.frame.minY
        // 轮播已离屏，在普通商品区域横滑仍能正常切换到评价页。
        app.collectionViews["food.products"].swipeLeft(velocity: .slow)
        XCTAssertTrue(app.tables["food.reviews"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tables["food.reviews"].isHittable)
        // 吸顶后的“点餐 ↑”现在是显式回顶；用横滑验证普通切页的位置保留。
        app.tables["food.reviews"].swipeRight(velocity: .slow)
        XCTAssertEqual(app.buttons[productIdentifier].frame.minY, originalY, accuracy: 2)
        app.navigationBars.buttons["重置"].tap()
        // keepsContentScrollPosition = true 时，现有“重置”的布局更新也保留商品位置。
        XCTAssertEqual(app.buttons[productIdentifier].frame.minY, originalY, accuracy: 2)
        XCTAssertTrue(app.cells["food.category.0"].isHittable)
        capture("切页与布局更新-商品位置保留")
    }

    func testPullingCategoriesUnderFloatingHeaderDoesNotLeaveGap() {
        enableKeepsContentScrollPosition()
        // 先滚到第一组约 3 号餐，随后去评价页展开店铺，再回来下拉左栏。
        let productStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.82))
        let productEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.28))
        productStart.press(forDuration: 0.05, thenDragTo: productEnd, withVelocity: 180, thenHoldForDuration: 0.2)
        let thirdProduct = app.staticTexts["招牌热销 · 3 号餐"]
        XCTAssertTrue(thirdProduct.isHittable)
        let tab = foodTab(at: 0)
        let remaining = thirdProduct.frame.minY - tab.frame.maxY - 40
        let secondStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.76))
        secondStart.press(forDuration: 0.05, thenDragTo: secondStart.withOffset(CGVector(dx: 0, dy: -remaining)), withVelocity: 180, thenHoldForDuration: 0.2)
        let readingY = thirdProduct.frame.minY - tab.frame.maxY

        foodTab(at: 1).tap()
        let reviewStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.27))
        reviewStart.press(forDuration: 0.05, thenDragTo: reviewStart.withOffset(CGVector(dx: 0, dy: 280)), withVelocity: 180, thenHoldForDuration: 0.2)
        XCTAssertTrue(app.staticTexts["food.shop"].isHittable)
        foodTab(at: 0).tap()
        XCTAssertEqual(thirdProduct.frame.minY - tab.frame.maxY, readingY, accuracy: 2)
        let productY = thirdProduct.frame.minY
        let firstCategory = app.cells["food.category.0"]
        XCTAssertEqual(firstCategory.frame.minY, tab.frame.maxY, accuracy: 2)

        let leftStart = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 44, dy: tab.frame.maxY + 30))
        leftStart.press(forDuration: 0.05, thenDragTo: leftStart.withOffset(CGVector(dx: 0, dy: 240)), withVelocity: 180, thenHoldForDuration: 0.2)
        // 松手后不能留下公共轮播的空白，也不能拖走右侧阅读位置。
        XCTAssertEqual(firstCategory.frame.minY, tab.frame.maxY, accuracy: 2)
        XCTAssertEqual(thirdProduct.frame.minY, productY, accuracy: 2)
        capture("保留3号餐-评价展开头部-左栏下拉后无空白")
    }

    func testCompactCarouselAndPinnedOrderTabExpandWithoutResettingLists() {
        enableKeepsContentScrollPosition()
        let order = foodTab(at: 0)
        let review = foodTab(at: 1)
        let merchant = foodTab(at: 2)
        let carousel = app.scrollViews["food.sharedCarousel"]
        XCTAssertEqual(review.value as? String, "1710 条评价")
        XCTAssertLessThan(merchant.frame.maxX, app.frame.width * 0.7)
        XCTAssertEqual(carousel.frame.height, 144, accuracy: 1)
        let expandedCarouselBottom = carousel.frame.maxY
        XCTAssertNotEqual(order.value as? String, "返回顶部")
        let expandedReviewX = review.frame.minX
        XCTAssertEqual(order.frame.width, 36, accuracy: 1)
        capture("新版店铺封面-左对齐Tab-紧凑活动卡片")
        for _ in 0..<4 { carousel.swipeLeft(velocity: .slow) }
        XCTAssertTrue(app.descendants(matching: .any)["food.sharedCarousel.card.5"].firstMatch.isHittable)
        assertMenuRemainsVisible()

        for fromReviews in [false, true] {
            app.collectionViews["food.products"].swipeUp()
            let leftStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.75))
            leftStart.press(forDuration: 0.05, thenDragTo: leftStart.withOffset(CGVector(dx: 0, dy: -150)), withVelocity: 180, thenHoldForDuration: 0.2)
            let productID = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "food.add."))
                .allElementsBoundByIndex.first { $0.isHittable && $0.frame.minY >= order.frame.maxY }!.identifier
            let categoryID = app.tables["food.categories"].cells.allElementsBoundByIndex
                .first { $0.isHittable && $0.frame.minY >= order.frame.maxY }!.identifier
            // 展开会改变可见 cell 集合，按稳定业务标识跟踪同一项，不能继续按可见下标查询。
            let product = app.buttons[productID]
            let category = app.cells[categoryID]
            let productReadingY = product.frame.minY - order.frame.maxY
            let categoryReadingY = category.frame.minY - order.frame.maxY
            if fromReviews { review.tap() }
            XCTAssertEqual(order.value as? String, "返回顶部")
            XCTAssertEqual(order.frame.width, 54, accuracy: 1)
            XCTAssertEqual(review.frame.minX, expandedReviewX + 18, accuracy: 1)
            capture("吸顶点餐箭头-\(fromReviews ? "评价页" : "点餐页")")
            order.tap()
            waitForExpansion(of: carousel, bottom: expandedCarouselBottom)
            XCTAssertTrue(app.staticTexts["food.shop"].isHittable)
            XCTAssertTrue(carousel.isHittable)
            XCTAssertNotEqual(order.value as? String, "返回顶部")
            XCTAssertEqual(order.frame.width, 36, accuracy: 1)
            XCTAssertEqual(review.frame.minX, expandedReviewX, accuracy: 1)
            XCTAssertEqual(product.frame.minY - carousel.frame.maxY, productReadingY, accuracy: 2)
            XCTAssertEqual(category.frame.minY - carousel.frame.maxY, categoryReadingY, accuracy: 2)
            // 重新展示的轮播仍保留横向位置和手势优先级。
            carousel.swipeRight(velocity: .slow)
            assertMenuRemainsVisible()
            XCTAssertEqual(product.frame.minY - carousel.frame.maxY, productReadingY, accuracy: 2)
            let collapseStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.78))
            collapseStart.press(forDuration: 0.05, thenDragTo: collapseStart.withOffset(CGVector(dx: 0, dy: -360)),
                                withVelocity: 180, thenHoldForDuration: 0.2)
            XCTAssertFalse(carousel.isHittable)
            XCTAssertEqual(product.frame.minY - order.frame.maxY, productReadingY, accuracy: 2)
            order.tap()
            waitForExpansion(of: carousel, bottom: expandedCarouselBottom)
            XCTAssertTrue(carousel.isHittable)
            XCTAssertEqual(product.frame.minY - carousel.frame.maxY, productReadingY, accuracy: 2)
        }
        capture("点餐展开-封面和共享轮播恢复-两列保留阅读位置")
    }

    private func waitForExpansion(of carousel: XCUIElement, bottom: CGFloat) {
        // CADisplayLink 不属于 XCTest 自动等待的 UIKit 动画；明确等到展开后的几何再比较两列坐标。
        let expanded = NSPredicate { _, _ in abs(carousel.frame.maxY - bottom) < 0.1 }
        let finished = expectation(for: expanded, evaluatedWith: carousel)
        wait(for: [finished], timeout: 3)
    }

    private func enableKeepsContentScrollPosition() {
        // 配置只保存在内存中：从设置页开启，再重新进入示例，验证实际接入路径。
        app.navigationBars["外卖点餐双列表"].buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["设置"].tap()
        let toggle = app.cells.containing(.staticText, identifier: "keepsContentScrollPosition").switches.firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        if toggle.value as? String != "1" { toggle.tap() }
        XCTAssertEqual(toggle.value as? String, "1")
        // 导航栈变化时系统可能用「示例」或「示例列表」作为标签，固定返回第一个 Tab。
        app.tabBars.buttons.element(boundBy: 0).tap()
        app.cells.containing(.staticText, identifier: "外卖点餐双列表").firstMatch.tap()
        XCTAssertTrue(app.collectionViews["food.products"].waitForExistence(timeout: 3))
    }

    private func foodTab(at index: Int) -> XCUIElement {
        // JXCategoryView 使用 UICollectionViewCell，不再是内置 Tab 的 UIButton。
        app.descendants(matching: .any)["food.tab.\(index)"].firstMatch
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

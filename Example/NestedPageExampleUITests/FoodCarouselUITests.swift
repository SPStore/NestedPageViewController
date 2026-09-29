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
        let tab = app.buttons["点餐"]
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
        app.collectionViews["food.products"].swipeUp()
        let visibleProduct = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "food.add.")).allElementsBoundByIndex.first { $0.isHittable }!
        let productIdentifier = visibleProduct.identifier
        let originalY = visibleProduct.frame.minY
        // 轮播已离屏，在普通商品区域横滑仍能正常切换到评价页。
        app.collectionViews["food.products"].swipeLeft(velocity: .slow)
        XCTAssertTrue(app.tables["food.reviews"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tables["food.reviews"].isHittable)
        app.staticTexts["点餐"].firstMatch.tap()
        XCTAssertEqual(app.buttons[productIdentifier].frame.minY, originalY, accuracy: 2)
        app.navigationBars.buttons["重置"].tap()
        // keepsContentScrollPosition = true 时，现有“重置”的布局更新也保留商品位置。
        XCTAssertEqual(app.buttons[productIdentifier].frame.minY, originalY, accuracy: 2)
        XCTAssertTrue(app.cells["food.category.0"].isHittable)
        capture("切页与布局更新-商品位置保留")
    }

    func testPullingCategoriesUnderFloatingHeaderDoesNotLeaveGap() {
        // 先滚到第一组约 3 号餐，随后去评价页展开店铺，再回来下拉左栏。
        let productStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.82))
        let productEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.28))
        productStart.press(forDuration: 0.05, thenDragTo: productEnd, withVelocity: 180, thenHoldForDuration: 0.2)
        let thirdProduct = app.staticTexts["招牌热销 · 3 号餐"]
        XCTAssertTrue(thirdProduct.isHittable)
        let tab = app.buttons["点餐"]
        let remaining = thirdProduct.frame.minY - tab.frame.maxY - 40
        let secondStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.76))
        secondStart.press(forDuration: 0.05, thenDragTo: secondStart.withOffset(CGVector(dx: 0, dy: -remaining)), withVelocity: 180, thenHoldForDuration: 0.2)
        let readingY = thirdProduct.frame.minY - tab.frame.maxY

        app.buttons["评价"].tap()
        let reviewStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.27))
        reviewStart.press(forDuration: 0.05, thenDragTo: reviewStart.withOffset(CGVector(dx: 0, dy: 280)), withVelocity: 180, thenHoldForDuration: 0.2)
        XCTAssertTrue(app.staticTexts["food.shop"].isHittable)
        app.buttons["点餐"].tap()
        XCTAssertEqual(thirdProduct.frame.minY - tab.frame.maxY, readingY, accuracy: 2)
        let productY = thirdProduct.frame.minY
        let firstCategory = app.cells["food.category.0"]
        XCTAssertEqual(firstCategory.frame.minY, tab.frame.maxY, accuracy: 2)

        let leftStart = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 44, dy: tab.frame.maxY + 30))
        leftStart.press(forDuration: 0.05, thenDragTo: leftStart.withOffset(CGVector(dx: 0, dy: 240)), withVelocity: 180, thenHoldForDuration: 0.2)
        // 松手后不能留下公共轮播的 220 点空白，也不能拖走右侧阅读位置。
        XCTAssertEqual(firstCategory.frame.minY, tab.frame.maxY, accuracy: 2)
        XCTAssertEqual(thirdProduct.frame.minY, productY, accuracy: 2)
        capture("保留3号餐-评价展开头部-左栏下拉后无空白")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

import XCTest

final class HeaderZoomUITests: XCTestCase {
    func testSystemNavigationBarWithZoomAndReturn() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        app.cells.containing(.staticText, identifier: "头部缩放 + 导航栏隐藏（常见）").firstMatch.tap()
        let back = app.buttons["BackButton"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertTrue(back.isHittable)
        capture(app, name: "系统导航栏-封面展开")

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.70))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -70)),
                    withVelocity: 100, thenHoldForDuration: 0.2)
        capture(app, name: "系统导航栏-渐显过程")
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -250)),
                    withVelocity: 150, thenHoldForDuration: 0.2)
        XCTAssertTrue(back.isHittable)
        capture(app, name: "系统导航栏-标签吸顶")

        let pullStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.30))
        pullStart.press(forDuration: 0.05, thenDragTo: pullStart.withOffset(CGVector(dx: 0, dy: 430)),
                        withVelocity: 180, thenHoldForDuration: 0.2)
        XCTAssertTrue(back.isHittable)
        capture(app, name: "系统导航栏-下拉恢复")
        back.tap()
        XCTAssertTrue(app.navigationBars["示例列表"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["设置"].firstMatch.isHittable)
        capture(app, name: "系统导航栏-返回首页")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// 检查真实入口的横竖屏 Tab 展示，以及 Push / Pop 后恢复；也可在折叠屏模拟器运行。
final class TabBarUITests: XCTestCase {
    func testTabsRemainUsableAcrossOrientationAndNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        defer { XCUIDevice.shared.orientation = .portrait }
        for orientation: UIDeviceOrientation in [.portrait, .landscapeLeft] {
            app.terminate()
            XCUIDevice.shared.orientation = orientation
            app.launch()
            let settings = app.buttons["设置"].firstMatch
            let examples = app.buttons["示例"].firstMatch
            waitUntilHittable(settings)
            waitUntilHittable(examples)
            settings.tap()
            XCTAssertTrue(app.cells.containing(.staticText, identifier: "keepsContentScrollPosition").firstMatch.waitForExistence(timeout: 5))
            examples.tap()
            app.cells.containing(.staticText, identifier: "默认").firstMatch.tap()
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "默认示例-导航层级-\(orientation.rawValue)"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            // 折叠屏的返回按钮可能位于系统竖栏，而不在 navigationBars 下。
            let back = app.buttons.matching(NSPredicate(format: "identifier == 'BackButton' OR label == 'Back' OR label == '返回'")).firstMatch
            waitUntilHittable(back)
            back.tap()
            waitUntilHittable(settings)
            waitUntilHittable(examples)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "TabBar-返回首页-\(orientation.rawValue)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }

    private func waitUntilHittable(_ element: XCUIElement) {
        let ready = expectation(for: NSPredicate(format: "exists == true AND hittable == true"), evaluatedWith: element)
        wait(for: [ready], timeout: 10)
    }
}

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

    func testFullBleedFoodCoverWithSystemNavigationBar() {
        let slogan = app.staticTexts["food.slogan"]
        let order = foodTab(at: 0)
        XCTAssertTrue(slogan.isHittable)
        XCTAssertFalse(app.navigationBars.staticTexts["外卖点餐双列表"].exists)
        let expandedTabY = order.frame.minY
        let expandedCarouselBottom = app.scrollViews["food.sharedCarousel"].frame.maxY
        XCTAssertGreaterThan(expandedTabY, app.segmentedControls["food.fulfillment"].frame.maxY)
        XCTAssertTrue(app.buttons["BackButton"].firstMatch.isHittable)
        capture("点餐封面-屏幕顶部展开-无导航标题")
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.82))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -100)),
                    withVelocity: 160, thenHoldForDuration: 0.2)
        capture("点餐封面-导航栏背景渐显")
        app.collectionViews["food.products"].swipeUp()
        XCTAssertEqual(order.value as? String, "返回顶部")
        XCTAssertLessThan(order.frame.minY, expandedTabY)
        XCTAssertFalse(app.navigationBars.staticTexts["外卖点餐双列表"].exists)
        capture("点餐封面-导航栏下方吸顶")
        order.tap()
        waitForExpansion(of: app.scrollViews["food.sharedCarousel"], bottom: expandedCarouselBottom)
        XCTAssertTrue(slogan.isHittable)
        XCTAssertEqual(order.frame.minY, expandedTabY, accuracy: 2)
        capture("点餐封面-点击点餐恢复透明导航栏")
        app.buttons["BackButton"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["示例列表"].waitForExistence(timeout: 5))
    }

    func testFulfillmentSwitchAndExpandWithNewCoverHeight() {
        let control = app.segmentedControls["food.fulfillment"]
        XCTAssertTrue(control.waitForExistence(timeout: 3))
        let order = foodTab(at: 0)
        let deliveryTop = order.frame.minY
        capture("外送-配送时间与优惠")
        control.buttons["自取"].tap()
        XCTAssertTrue(control.buttons["自取"].isSelected)
        XCTAssertTrue(app.staticTexts["food.serviceSummary"].label.contains("免配送费"))
        XCTAssertTrue(app.staticTexts["food.serviceDetail"].label.contains("幸福路"))
        let pickupTop = order.frame.minY
        let pickupCarouselBottom = app.scrollViews["food.sharedCarousel"].frame.maxY
        XCTAssertLessThan(pickupTop, deliveryTop - 15)
        capture("自取-门店地址与更紧凑的封面")
        app.collectionViews["food.products"].swipeUp()
        XCTAssertEqual(order.value as? String, "返回顶部")
        order.tap()
        waitForExpansion(of: app.scrollViews["food.sharedCarousel"], bottom: pickupCarouselBottom)
        XCTAssertTrue(control.buttons["自取"].isHittable)
        XCTAssertTrue(control.buttons["自取"].isSelected)
        control.buttons["外送"].tap()
        XCTAssertEqual(order.frame.minY, deliveryTop, accuracy: 1)
        capture("切回外送-封面及共享轮播恢复")
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

    func testLeftUpwardFlickContinuesCollapsingPageAfterRelease() {
        let order = foodTab(at: 0)
        let expandedTabY = order.frame.minY
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: 44, dy: app.frame.height * 0.82))
        // 手指只上滑 70 点，松手后页面仍需由惯性继续向上收起。
        start.press(forDuration: 0.05,
                    thenDragTo: start.withOffset(CGVector(dx: 0, dy: -70)),
                    withVelocity: 1000, thenHoldForDuration: 0)
        XCTAssertLessThan(order.frame.minY, expandedTabY - 110)
        capture("左栏向上甩动-松手后继续收起页面")
    }

    func testLeftDownwardFlickStopsAtCategoryTopWithoutExpandingPage() {
        let order = foodTab(at: 0)
        let leftStart = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: 44, dy: app.frame.height * 0.82))
        leftStart.press(forDuration: 0.05,
                        thenDragTo: leftStart.withOffset(CGVector(dx: 0, dy: -540)),
                        withVelocity: 220, thenHoldForDuration: 0.2)
        XCTAssertEqual(order.value as? String, "返回顶部")
        XCTAssertFalse(app.scrollViews["food.sharedCarousel"].isHittable)

        let visibleCategory = app.tables["food.categories"].cells.allElementsBoundByIndex.first {
            $0.isHittable && $0.frame.minY >= order.frame.maxY
        }!
        let row = Int(visibleCategory.identifier.components(separatedBy: ".").last!)!
        let depth = order.frame.maxY + CGFloat(row) * 60 - visibleCategory.frame.minY
        let positionStart = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 44, dy: 420))
        positionStart.press(forDuration: 0.05,
                            thenDragTo: positionStart.withOffset(CGVector(dx: 0, dy: depth - 180)),
                            withVelocity: 160, thenHoldForDuration: 0.2)
        let rightCarousel = app.scrollViews["food.productCarousel"]
        let pinnedTabY = order.frame.minY
        let rightY = rightCarousel.frame.minY
        capture("左栏显示鲜香炖菜-下滑松手前")

        // 拖动距离小于分类的阅读深度，确保是在到顶前松手，由惯性跨过顶部边界。
        let flickStart = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 44, dy: 360))
        flickStart.press(forDuration: 0.05,
                         thenDragTo: flickStart.withOffset(CGVector(dx: 0, dy: 70)),
                         withVelocity: 1000, thenHoldForDuration: 0)
        XCTAssertEqual(order.frame.minY, pinnedTabY, accuracy: 2)
        XCTAssertEqual(rightCarousel.frame.minY, rightY, accuracy: 2)
        XCTAssertFalse(app.scrollViews["food.sharedCarousel"].isHittable)
        XCTAssertEqual(app.cells["food.category.0"].frame.minY, order.frame.maxY, accuracy: 2)
        capture("左栏惯性到顶-页面保持吸顶")

        // 再次用手指拖拽，才允许展开共享轮播。
        flickStart.press(forDuration: 0.05,
                         thenDragTo: flickStart.withOffset(CGVector(dx: 0, dy: 80)),
                         withVelocity: 160, thenHoldForDuration: 0.2)
        XCTAssertTrue(app.scrollViews["food.sharedCarousel"].isHittable)
        XCTAssertGreaterThan(rightCarousel.frame.minY, rightY + 40)
        capture("再次拖拽左栏-正常展开共享轮播")
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
        let carousel = app.scrollViews["food.sharedCarousel"]
        let tab = foodTab(at: 0)
        // 先收起当前封面，再收起半个共享轮播；封面高度变化后也必须进入同一测试场景。
        let pinnedTabTop = app.navigationBars.firstMatch.frame.maxY
        let collapseDistance = max(0, tab.frame.minY - pinnedTabTop) + carousel.frame.height / 2
        let leftStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.80))
        leftStart.press(forDuration: 0.05, thenDragTo: leftStart.withOffset(CGVector(dx: 0, dy: -collapseDistance)), withVelocity: 180, thenHoldForDuration: 0.2)
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
        XCTAssertTrue(app.navigationBars["示例列表"].waitForExistence(timeout: 5))
    }

    private func assertMenuRemainsVisible(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.collectionViews["food.products"].isHittable, file: file, line: line)
        XCTAssertFalse(app.tables["food.reviews"].isHittable, file: file, line: line)
        XCTAssertEqual(app.collectionViews["food.products"].frame.minX, 0, accuracy: 2, file: file, line: line)
    }

    func testTabSwitchKeepsProductReadingPosition() {
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
        XCTAssertTrue(app.cells["food.category.0"].isHittable)
        capture("切页-商品位置保留")
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
        let carouselHeight = carousel.frame.height
        let expandedCarouselBottom = carousel.frame.maxY
        let expandedTabY = order.frame.minY
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
            let sharedCollapseDistance = expandedTabY - order.frame.minY + carouselHeight
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
            collapseStart.press(forDuration: 0.05, thenDragTo: collapseStart.withOffset(CGVector(dx: 0, dy: -sharedCollapseDistance - 15)),
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

    func testCoreDragBoundaryAcrossOrderingAndReviews() {
        setConfiguration("requiresNewDragToExpandHeader", enabled: true)
        let products = app.collectionViews["food.products"]
        let firstCategory = app.cells["food.category.0"]
        if !firstCategory.isHittable { products.swipeUp(velocity: .slow) }
        XCTAssertTrue(firstCategory.isHittable)
        firstCategory.tap() // 独立轮播之后的第一组，确保商品已有阅读深度。
        let order = foodTab(at: 0)
        XCTAssertEqual(order.value as? String, "返回顶部")
        let pinnedY = order.frame.minY
        let origin = app.coordinate(withNormalizedOffset: .zero)

        for index in [0, 1] {
            if index == 1 {
                foodTab(at: 1).tap()
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.83))
                let distance = order.frame.minY - pinnedY + 120
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)),
                            withVelocity: 180, thenHoldForDuration: 0.3)
            }
            XCTAssertEqual(order.frame.minY, pinnedY, accuracy: 2)
            let start = origin.withOffset(CGVector(dx: app.frame.width * 0.72, dy: order.frame.maxY + 45))
            let end = start.withOffset(CGVector(dx: 0, dy: 430))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 220, thenHoldForDuration: 0.3)
            XCTAssertEqual(order.frame.minY, pinnedY, accuracy: 2, "第一轮到内容顶部后应保持吸顶")
            if index == 0 { XCTAssertFalse(app.scrollViews["food.sharedCarousel"].isHittable) }
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 220, thenHoldForDuration: 0.3)
            XCTAssertGreaterThan(order.frame.minY, pinnedY + 20, "第二轮下拉应展开头部")
        }

        // 商家是只有四行的短列表：吸顶后已经在内容顶部，可在第一轮下拉直接展开。
        foodTab(at: 2).tap()
        app.tables["food.merchant"].swipeUp(velocity: .slow)
        XCTAssertEqual(order.frame.minY, pinnedY, accuracy: 2)
        let start = origin.withOffset(CGVector(dx: app.frame.width * 0.72, dy: order.frame.maxY + 45))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 240)),
                    withVelocity: 180, thenHoldForDuration: 0.3)
        XCTAssertGreaterThan(order.frame.minY, pinnedY + 20)
    }

    private func enableKeepsContentScrollPosition() {
        setConfiguration("keepsContentScrollPosition", enabled: true)
    }

    private func setConfiguration(_ key: String, enabled: Bool) {
        // 配置只保存在内存中：从设置页开启，再重新进入示例，验证实际接入路径。
        app.buttons["BackButton"].firstMatch.tap()
        app.tabBars.buttons["设置"].tap()
        let toggle = app.cells.containing(.staticText, identifier: key).switches.firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        let expectedValue = enabled ? "1" : "0"
        if toggle.value as? String != expectedValue { toggle.tap() }
        XCTAssertEqual(toggle.value as? String, expectedValue)
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

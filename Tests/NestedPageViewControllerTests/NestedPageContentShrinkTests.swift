@testable import NestedPageViewController
import UIKit
import XCTest

@MainActor
final class NestedPageContentShrinkTests: XCTestCase {
    func testInactiveEstimatedHeightClampDoesNotLeaveGapAfterReload() {
        for automatic in [false, true] {
            let fixture = makeEstimatedHeightFixture(automatic: automatic)
            let inactive = fixture.pages[0].scrollView

            // 重放日志中的 UIKit 顺序：按尚未补足的范围收敛 offset，再通知 contentSize 变化。
            inactive.contentOffset.y = 640 - inactive.bounds.height + inactive.adjustedContentInset.bottom
            XCTAssertEqual(inactive.contentOffset.y, -112, accuracy: 0.001)
            inactive.contentSize.height = 640
            inactive.contentSize.height = 1000

            XCTAssertEqual(inactive.contentOffset.y, -44, accuracy: 0.001)
            XCTAssertEqual(fixture.headerY, -204, accuracy: 0.001)
            for index in [0, 1, 0] {
                fixture.host.scrollToPage(at: index, animated: false)
                let scrollView = fixture.pages[index].scrollView
                XCTAssertEqual(fixture.tab.convert(fixture.tab.bounds, to: scrollView).maxY, 0, accuracy: 0.001)
            }
        }
    }

    func testPageArrivalRepairsClampAfterRangeNotification() {
        let fixture = makeEstimatedHeightFixture()
        let inactive = fixture.pages[0].scrollView
        inactive.contentSize.height = 640
        // UIKit 也可能在范围回调之后才写入自动调整的 offset。
        inactive.contentOffset.y = -112

        fixture.host.scrollToPage(at: 0, animated: false)

        XCTAssertEqual(inactive.contentOffset.y, -44, accuracy: 0.001)
        XCTAssertEqual(fixture.headerY, -204, accuracy: 0.001)
    }

    func testInactiveRangeChangesPreserveDeeperReadingPosition() {
        let fixture = makeEstimatedHeightFixture()
        let inactive = fixture.pages[0].scrollView
        inactive.contentOffset.y = 140
        inactive.contentSize.height = 1100
        fixture.host.scrollToPage(at: 0, animated: false)
        XCTAssertEqual(inactive.contentOffset.y, 140)
    }

    func testAlignmentUsesSharedHeaderCoordinatesWithHoverAndInsetOrigin() {
        for contentTop: CGFloat in [0, 32] {
            for stickyOffset: CGFloat in [0, 36] {
                let fixture = ScrollBehaviorFixture(contentTop: contentTop, stickyOffset: stickyOffset)
                fixture.scroll(to: -144)
                let inactive = fixture.pages[1].scrollView
                inactive.contentOffset.y = -212
                fixture.events.removeAll()
                inactive.contentSize.height = 1000

                XCTAssertEqual(inactive.contentOffset.y, -144, accuracy: 0.001)
                fixture.host.scrollToPage(at: 1, animated: false)
                XCTAssertEqual(fixture.headerY, contentTop - 104, accuracy: 0.001)
                XCTAssertTrue(fixture.events.isEmpty)
            }
        }
    }

    func testUnpaddedShortPageStillExpandsHeaderToItsReachablePosition() {
        let fixture = makeEstimatedHeightFixture(automatic: false)
        let inactive = fixture.pages[0].scrollView
        inactive.contentOffset.y = -140
        inactive.contentSize.height = 640
        fixture.host.scrollToPage(at: 0, animated: false)

        XCTAssertEqual(inactive.contentOffset.y, -112, accuracy: 0.001)
        XCTAssertEqual(inactive.contentInset.bottom, 83)
        XCTAssertEqual(fixture.tab.convert(fixture.tab.bounds, to: inactive).maxY, 0, accuracy: 0.001)
        XCTAssertEqual(fixture.headerY, -136, accuracy: 0.001)
    }

    func testInactiveRangeChangesDoNotCancelRefreshOrDeceleration() {
        for refreshing in [false, true] {
            let fixture = makeEstimatedHeightFixture()
            let inactive = fixture.pages[0].scrollView
            if refreshing {
                inactive.contentInset.top += 60
            } else {
                inactive.simulatesDeceleration = true
            }
            let offset: CGFloat = refreshing ? -308 : -112
            inactive.contentOffset.y = offset
            inactive.contentSize.height = 640
            inactive.contentSize.height = 1000
            fixture.host.scrollToPage(at: 0, animated: false)
            XCTAssertEqual(inactive.contentOffset.y, offset)
        }
    }

    func testInactiveAlignmentDoesNotInterfereWithLayoutTransaction() {
        let fixture = makeEstimatedHeightFixture()
        let inactive = fixture.pages[0].scrollView
        fixture.host.isUpdatingLayouts = true
        inactive.contentOffset.y = -112
        inactive.contentSize.height = 1000
        XCTAssertEqual(inactive.contentOffset.y, -112)
        fixture.host.isUpdatingLayouts = false
    }

    private func makeEstimatedHeightFixture(automatic: Bool = true) -> ScrollBehaviorFixture {
        let fixture = ScrollBehaviorFixture()
        fixture.host.autoAdjustsContentSizeMinimumHeight = automatic
        fixture.host.view.frame.size.height = 835
        fixture.host.view.layoutIfNeeded()
        fixture.host.updateLayouts()
        for page in fixture.pages {
            page.scrollView.contentSize.height = 1036
            fixture.host.setContentBottomInset(83, for: page.scrollView)
        }
        fixture.host.scrollToPage(at: 1, animated: false)
        fixture.scroll(to: -44)
        return fixture
    }

    func testShrinkingCurrentPageDuringHeaderChangeDoesNotLeaveGapOnOtherPage() {
        for kind in [TestPage.Kind.flow, .compositional, .list, .table] {
            for timing in 0..<3 {
                for offset: CGFloat in [-248, -44, 140, 900] {
                    for automatic in [false, true] {
                        for recentOffset: CGFloat in [-248, 140, 900] {
                            verifyShrinkingCurrentPage(kind: kind, timing: timing, offset: offset,
                                                       recentOffset: recentOffset, automatic: automatic)
                        }
                    }
                }
            }
        }
    }

    private func verifyShrinkingCurrentPage(
        kind: TestPage.Kind, timing: Int, offset: CGFloat, recentOffset: CGFloat, automatic: Bool
    ) {
        let dataSource = TestPages(kind: kind)
        dataSource.pages.forEach { $0.itemCount = 30 }
        let host = NestedPageViewController()
        host.dataSource = dataSource
        host.keepsContentScrollPosition = true
        host.autoAdjustsContentSizeMinimumHeight = automatic
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 587)
        host.view.layoutIfNeeded()
        dataSource.pages[0].nestedPageContentScrollView.contentOffset.y = recentOffset
        host.scrollToPage(at: 1, animated: false)
        let current = dataSource.pages[1].nestedPageContentScrollView
        current.contentOffset.y = offset

        // 进入选择态，业务按原来可见的文档恢复当前页；另一页仍由组件协调。
        dataSource.showsHeader = false
        dataSource.coverView(in: host)?.isHidden = true
        dataSource.tabStrip(in: host)?.isHidden = true
        host.updateLayouts()
        current.contentOffset.y = max(0, offset)
        dataSource.pages.forEach { host.setContentBottomInset(90, for: $0.nestedPageContentScrollView) }

        // 分别覆盖先完成数据布局、数据布局延迟到头部更新、先退出选择态三种时序。
        if timing != 2 {
            dataSource.pages[1].itemCount = 1
            reload(dataSource.pages, layout: timing == 0)
        }
        dataSource.showsHeader = true
        dataSource.coverView(in: host)?.isHidden = false
        dataSource.tabStrip(in: host)?.isHidden = false
        host.updateLayouts()
        dataSource.pages.forEach { host.setContentBottomInset(34, for: $0.nestedPageContentScrollView) }
        if timing == 2 { dataSource.pages[1].itemCount = 1 }
        reload(dataSource.pages, layout: true)

        let context = "kind=\(kind) timing=\(timing) offset=\(offset) recent=\(recentOffset) automatic=\(automatic)"
        for index in [0, 1, 0] {
            host.scrollToPage(at: index, animated: false)
            let scrollView = dataSource.pages[index].nestedPageContentScrollView
            scrollView.layoutIfNeeded()
            let tab = dataSource.tabStrip(in: host)!
            let tabBottom = tab.convert(tab.bounds, to: scrollView).maxY
            XCTAssertGreaterThanOrEqual(
                tabBottom, -0.5,
                "\(context) page=\(index) offset=\(scrollView.contentOffset.y) tabBottom=\(tabBottom)"
            )
        }
    }

    private func reload(_ pages: [TestPage], layout: Bool) {
        for page in pages {
            let scrollView = page.nestedPageContentScrollView
            if let collectionView = scrollView as? UICollectionView {
                collectionView.collectionViewLayout.invalidateLayout()
                collectionView.reloadData()
            } else if let tableView = scrollView as? UITableView {
                tableView.reloadData()
            }
            if layout { scrollView.layoutIfNeeded() }
        }
    }
}

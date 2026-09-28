@testable import NestedPageViewController
import UIKit
import XCTest

@MainActor
final class NestedPageScrollRangeTests: XCTestCase {
    private func makeScrollView(contentHeight: CGFloat = 248) -> UIScrollView {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 587))
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = UIEdgeInsets(top: 248, left: 0, bottom: 34, right: 0)
        scrollView.contentSize = CGSize(width: 390, height: contentHeight)
        return scrollView
    }

    func testShortContentHasEnoughRangeWithoutChangingContentSize() {
        let scrollView = makeScrollView()
        let range = NestedPageScrollRange(scrollView: scrollView, pinnedHeight: 44)
        XCTAssertEqual(scrollView.contentSize.height, 248)
        XCTAssertEqual(scrollView.contentInset.bottom, 295)
        XCTAssertEqual(maximumOffsetY(scrollView), -44)
        XCTAssertEqual(range.requestedBottomInset, 34)
    }

    func testLongContentAndDisabledAdjustmentReleasePadding() {
        let scrollView = makeScrollView()
        let range = NestedPageScrollRange(scrollView: scrollView, pinnedHeight: 44)
        scrollView.contentSize.height = 1000
        XCTAssertEqual(scrollView.contentInset.bottom, 34)
        scrollView.contentSize.height = 248
        XCTAssertEqual(maximumOffsetY(scrollView), -44)
        range.update(pinnedHeight: nil)
        XCTAssertEqual(scrollView.contentInset.bottom, 34)
        range.update(pinnedHeight: 44)
        XCTAssertEqual(maximumOffsetY(scrollView), -44)
    }

    func testHeaderViewportAndContentChangesRecomputeRange() {
        let scrollView = makeScrollView()
        let range = NestedPageScrollRange(scrollView: scrollView, pinnedHeight: 44)
        range.update(pinnedHeight: 0)
        XCTAssertEqual(maximumOffsetY(scrollView), 0)
        scrollView.bounds.size.height = 720
        XCTAssertEqual(maximumOffsetY(scrollView), 0)
        range.update(pinnedHeight: 64)
        XCTAssertEqual(maximumOffsetY(scrollView), -64)
        scrollView.contentSize.height = 0
        XCTAssertEqual(maximumOffsetY(scrollView), -64)
    }

    func testBusinessInsetAndRefreshTopDoNotAccumulatePadding() {
        let scrollView = makeScrollView()
        let range = NestedPageScrollRange(scrollView: scrollView, pinnedHeight: 44)
        scrollView.contentInset.top += 60
        XCTAssertEqual(range.requestedBottomInset, 34)
        XCTAssertEqual(scrollView.contentInset.top, 308)
        scrollView.contentInset.bottom = 90
        XCTAssertEqual(range.requestedBottomInset, 90)
        XCTAssertEqual(maximumOffsetY(scrollView), -44)
        range.updateHeaderInsets(top: 248)
        range.updateHeaderInsets(top: 248)
        XCTAssertEqual(range.requestedBottomInset, 90)
        XCTAssertEqual(scrollView.verticalScrollIndicatorInsets.bottom, 90)
        range.setRequestedBottomInset(34)
        scrollView.contentSize.height = 1000
        XCTAssertEqual(scrollView.contentInset.bottom, 34)
    }

    func testUnloadingRestoresInsetAndStopsObserving() {
        let scrollView = makeScrollView()
        let range = NestedPageScrollRange(scrollView: scrollView, pinnedHeight: 44)
        range.invalidate()
        XCTAssertEqual(scrollView.contentInset.bottom, 34)
        scrollView.contentSize.height = 0
        scrollView.bounds.size.height = 800
        XCTAssertEqual(scrollView.contentInset.bottom, 34)
    }

    func testSafeAreaCanShrinkWithoutBecomingBusinessInset() {
        let scrollView = SafeAreaScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 587))
        scrollView.contentSize = CGSize(width: 390, height: 1000)
        scrollView.testBottomSafeArea = 34
        let range = NestedPageScrollRange(scrollView: scrollView, pinnedHeight: 44)
        range.updateHeaderInsets(top: 248)
        XCTAssertEqual(scrollView.contentInset.bottom, 34)
        scrollView.testBottomSafeArea = 0
        range.refresh()
        XCTAssertEqual(scrollView.contentInset.bottom, 0)
        XCTAssertEqual(range.requestedBottomInset, 0)
    }

    func testRepeatedPageSwitchAfterHeaderChangeWithFlowLayout() {
        verifyRepeatedPageSwitch(kind: .flow)
    }

    func testRepeatedPageSwitchAfterHeaderChangeWithCompositionalLayout() {
        verifyRepeatedPageSwitch(kind: .compositional)
    }

    func testRepeatedPageSwitchAfterHeaderChangeWithTableView() {
        verifyRepeatedPageSwitch(kind: .table)
    }

    func testCompositionalLayoutFractionalHeightDoesNotCollapse() {
        let dataSource = TestPages(kind: .fractionalCompositional)
        let host = NestedPageViewController()
        host.dataSource = dataSource
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 587)
        host.view.layoutIfNeeded()
        for _ in 0..<5 { dataSource.pages.forEach { $0.reloadAndLayout() } }
        guard let collectionView = dataSource.pages[0].nestedPageContentScrollView as? UICollectionView else {
            return XCTFail("Expected a collection view")
        }
        let attributes = collectionView.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))
        XCTAssertGreaterThan(attributes?.frame.height ?? 0, 1)
        XCTAssertGreaterThanOrEqual(maximumOffsetY(collectionView), -44)
    }

    func testDisabledAdjustmentWithFlowLayout() {
        verifyDisabledAdjustment(kind: .flow)
    }

    func testDisabledAdjustmentWithCompositionalLayout() {
        verifyDisabledAdjustment(kind: .compositional)
    }

    func testDisabledAdjustmentWithTableView() {
        verifyDisabledAdjustment(kind: .table)
    }

    func testDisablingAdjustmentWhilePinnedReconcilesHeader() {
        let dataSource = TestPages(kind: .flow)
        let host = makeHost(dataSource: dataSource)
        let scrollView = dataSource.pages[0].nestedPageContentScrollView
        scrollView.contentOffset.y = -44
        XCTAssertTrue(host.isSticked)

        host.autoAdjustsContentSizeMinimumHeight = false

        XCTAssertEqual(scrollView.contentInset.bottom, 0)
        assertUnpaddedPageIsAligned(host: host, dataSource: dataSource)
        XCTAssertFalse(host.isSticked)
    }

    func testDisabledAdjustmentHandlesCurrentContentShrinking() {
        let dataSource = TestPages(kind: .compositional)
        dataSource.pages[0].itemCount = 30
        let host = makeHost(dataSource: dataSource, automatic: false)
        let scrollView = dataSource.pages[0].nestedPageContentScrollView
        scrollView.contentOffset.y = -44
        XCTAssertTrue(host.isSticked)

        dataSource.pages[0].itemCount = 0
        dataSource.pages[0].reloadAndLayout()

        assertUnpaddedPageIsAligned(host: host, dataSource: dataSource)
        XCTAssertFalse(host.isSticked)
        XCTAssertEqual(scrollView.contentInset.bottom, 0)
    }

    func testDisabledAdjustmentHandlesViewportGrowth() {
        let dataSource = TestPages(kind: .flow)
        dataSource.pages[0].itemCount = 10
        let host = makeHost(dataSource: dataSource, automatic: false)
        let scrollView = dataSource.pages[0].nestedPageContentScrollView
        scrollView.contentOffset.y = -44
        XCTAssertTrue(host.isSticked)

        scrollView.bounds.size.height = 900

        assertUnpaddedPageIsAligned(host: host, dataSource: dataSource)
        XCTAssertFalse(host.isSticked)
    }

    func testDisabledAdjustmentHandlesBusinessInsetShrinking() {
        let dataSource = TestPages(kind: .flow)
        dataSource.pages[0].itemCount = 6
        let host = makeHost(dataSource: dataSource, automatic: false)
        let scrollView = dataSource.pages[0].nestedPageContentScrollView
        host.setContentBottomInset(220, for: scrollView)
        scrollView.contentOffset.y = -44
        XCTAssertTrue(host.isSticked)

        host.setContentBottomInset(34, for: scrollView)

        assertUnpaddedPageIsAligned(host: host, dataSource: dataSource)
        XCTAssertFalse(host.isSticked)
        XCTAssertEqual(scrollView.contentInset.bottom, 34)
    }

    func testDisabledAdjustmentWithLazyLoadedPage() {
        let dataSource = TestPages(kind: .flow)
        dataSource.preloadsPages = false
        dataSource.pages[0].itemCount = 30
        let host = makeHost(dataSource: dataSource, automatic: false)
        dataSource.pages[0].nestedPageContentScrollView.contentOffset.y = -44
        XCTAssertFalse(dataSource.pages[1].isViewLoaded)

        host.scrollToPage(at: 1, animated: false)

        assertUnpaddedPageIsAligned(host: host, dataSource: dataSource)
        XCTAssertFalse(host.isSticked)
    }

    func testDisabledAdjustmentPreservesReachablePinnedPosition() {
        let dataSource = TestPages(kind: .flow)
        dataSource.pages.forEach { $0.itemCount = 30 }
        let host = makeHost(dataSource: dataSource, automatic: false)
        dataSource.pages[0].nestedPageContentScrollView.contentOffset.y = -44

        for index in [1, 0, 1] {
            host.scrollToPage(at: index, animated: false)
            XCTAssertTrue(host.isSticked)
            XCTAssertEqual(dataSource.pages[index].nestedPageContentScrollView.contentOffset.y, -44)
        }
    }

    func testDisablingAdjustmentDoesNotCancelTopRefresh() {
        let dataSource = TestPages(kind: .flow)
        let host = makeHost(dataSource: dataSource)
        let scrollView = dataSource.pages[0].nestedPageContentScrollView
        scrollView.contentInset.top += 60
        scrollView.contentOffset.y = -308

        host.autoAdjustsContentSizeMinimumHeight = false

        XCTAssertEqual(scrollView.contentInset.top, 308)
        XCTAssertEqual(scrollView.contentOffset.y, -308)
    }

    private func verifyDisabledAdjustment(kind: TestPage.Kind) {
        for keepsPosition in [false, true] {
            for count in [0, 3, 6] {
                let dataSource = TestPages(kind: kind)
                dataSource.pages[0].itemCount = 30
                dataSource.pages[1].itemCount = count
                let host = makeHost(dataSource: dataSource, automatic: false)
                host.keepsContentScrollPosition = keepsPosition
                dataSource.pages.forEach { host.setContentBottomInset(34, for: $0.nestedPageContentScrollView) }
                dataSource.showsHeader = false
                host.updateLayouts()
                dataSource.showsHeader = true
                host.updateLayouts()

                for _ in 0..<3 {
                    dataSource.pages[0].nestedPageContentScrollView.contentOffset.y = -44
                    // 模拟横向切页中途，暂时忽略竖向 KVO；完成切页后再协调新页面。
                    host.containerScrollView.contentOffset.x = host.containerScrollView.bounds.width / 2
                    // 非当前页重新布局会收回超出真实滚动范围的 offset。
                    dataSource.pages[1].reloadAndLayout()
                    host.scrollToPage(at: 1, animated: false)
                    assertUnpaddedPageIsAligned(host: host, dataSource: dataSource)
                    XCTAssertFalse(host.isSticked)
                    XCTAssertEqual(dataSource.pages[1].nestedPageContentScrollView.contentInset.bottom, 34)
                    dataSource.pages[1].reloadAndLayout()
                    assertUnpaddedPageIsAligned(host: host, dataSource: dataSource)
                    host.scrollToPage(at: 0, animated: false)
                }
            }
        }
    }

    private func makeHost(dataSource: TestPages, automatic: Bool = true) -> NestedPageViewController {
        let host = NestedPageViewController()
        host.dataSource = dataSource
        host.autoAdjustsContentSizeMinimumHeight = automatic
        host.keepsContentScrollPosition = true
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 587)
        host.view.layoutIfNeeded()
        return host
    }

    private func assertUnpaddedPageIsAligned(
        host: NestedPageViewController, dataSource: TestPages,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let scrollView = dataSource.pages[host.currentIndex].nestedPageContentScrollView
        let maximum = max(-scrollView.adjustedContentInset.top, maximumOffsetY(scrollView))
        XCTAssertLessThanOrEqual(scrollView.contentOffset.y, maximum + 0.5, file: file, line: line)
        guard let tab = dataSource.tabStrip(in: host) else { return XCTFail("Missing tab", file: file, line: line) }
        // 内容起点为列表坐标 0，短列表的 header 底边必须与其衔接。
        XCTAssertEqual(tab.convert(tab.bounds, to: scrollView).maxY, 0, accuracy: 0.5, file: file, line: line)
    }

    private func verifyRepeatedPageSwitch(kind: TestPage.Kind) {
        let dataSource = TestPages(kind: kind)
        let host = NestedPageViewController()
        host.dataSource = dataSource
        host.keepsContentScrollPosition = true
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 587)
        host.view.layoutIfNeeded()
        dataSource.showsHeader = false
        host.updateLayouts()
        dataSource.pages.forEach { $0.reloadAndLayout() }
        dataSource.showsHeader = true
        host.updateLayouts()
        let firstScrollView = dataSource.pages[0].nestedPageContentScrollView
        firstScrollView.setContentOffset(CGPoint(x: 0, y: -44), animated: false)

        for index in [1, 0, 1, 0, 1] {
            dataSource.pages.forEach { $0.reloadAndLayout() }
            host.scrollToPage(at: index, animated: false)
            let scrollView = dataSource.pages[index].nestedPageContentScrollView
            scrollView.layoutIfNeeded()
            XCTAssertEqual(host.currentIndex, index)
            XCTAssertEqual(scrollView.contentOffset.y, -44, accuracy: 0.5)
            XCTAssertTrue(host.isSticked)
            XCTAssertGreaterThanOrEqual(maximumOffsetY(scrollView), -44)
            if let collectionView = scrollView as? UICollectionView {
                XCTAssertEqual(collectionView.contentSize, collectionView.collectionViewLayout.collectionViewContentSize)
            }
        }
    }

    private func maximumOffsetY(_ scrollView: UIScrollView) -> CGFloat {
        return scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
    }
}

private final class SafeAreaScrollView: UIScrollView {
    var testBottomSafeArea: CGFloat = 0
    override var safeAreaInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: testBottomSafeArea, right: 0)
    }
}

private final class TestPages: NestedPageViewControllerDataSource {
    let pages: [TestPage]
    var showsHeader = true
    var preloadsPages = true
    private let cover = UIView()
    private let tab = UIView()

    init(kind: TestPage.Kind) { pages = [TestPage(kind: kind), TestPage(kind: kind)] }
    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int { return pages.count }
    func pageViewController(_ pageViewController: NestedPageViewController, viewControllerAt index: Int) -> NestedPageScrollable? {
        return pages[index]
    }
    func pageViewController(_ pageViewController: NestedPageViewController, shouldPreloadViewControllerAt index: Int) -> Bool {
        return preloadsPages
    }
    func coverView(in pageViewController: NestedPageViewController) -> UIView? { return cover }
    func tabStrip(in pageViewController: NestedPageViewController) -> UIView? { return tab }
    func heightForCoverView(in pageViewController: NestedPageViewController) -> CGFloat { return showsHeader ? 204 : 0 }
    func heightForTabStrip(in pageViewController: NestedPageViewController) -> CGFloat { return showsHeader ? 44 : 0 }
}

private final class TestPage: UIViewController, NestedPageScrollable, UICollectionViewDataSource, UITableViewDataSource {
    enum Kind { case flow, compositional, fractionalCompositional, table }
    let nestedPageContentScrollView: UIScrollView
    var itemCount = 3

    init(kind: Kind) {
        switch kind {
        case .table:
            nestedPageContentScrollView = UITableView(frame: .zero, style: .plain)
        case .flow, .compositional, .fractionalCompositional:
            let layout: UICollectionViewLayout
            if kind == .flow {
                let flow = UICollectionViewFlowLayout()
                flow.itemSize = CGSize(width: 300, height: 56)
                flow.minimumLineSpacing = 0
                layout = flow
            } else {
                let height: NSCollectionLayoutDimension = kind == .fractionalCompositional ? .fractionalHeight(0.2) : .absolute(56)
                let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: height)
                let item = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                layout = UICollectionViewCompositionalLayout(section: NSCollectionLayoutSection(group: group))
            }
            nestedPageContentScrollView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        nestedPageContentScrollView.frame = view.bounds
        nestedPageContentScrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(nestedPageContentScrollView)
        if let collectionView = nestedPageContentScrollView as? UICollectionView {
            collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
            collectionView.dataSource = self
        } else if let tableView = nestedPageContentScrollView as? UITableView {
            tableView.rowHeight = 56
            tableView.estimatedRowHeight = 0
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
            tableView.dataSource = self
        }
    }

    func reloadAndLayout() {
        (nestedPageContentScrollView as? UICollectionView)?.reloadData()
        (nestedPageContentScrollView as? UITableView)?.reloadData()
        nestedPageContentScrollView.layoutIfNeeded()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { return itemCount }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return itemCount }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    }
}

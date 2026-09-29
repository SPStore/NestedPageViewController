import UIKit
import XCTest
@testable import NestedPageViewController

@MainActor
final class NestedPageTabStripLayoutTests: XCTestCase {
    func testInitialSelectionIsLaidOutAfterReceivingNonzeroBounds() throws {
        let strip = makeTabStrip()
        strip.selectTab(at: 1, animated: false)
        XCTAssertEqual(strip.bounds.height, 0)

        strip.frame.size = CGSize(width: 120, height: 44)
        strip.layoutIfNeeded()

        try assertIndicator(strip, progress: 1)
    }

    func testDefaultPageOffsetBeforeFirstLayoutIsPreserved() throws {
        let strip = makeTabStrip()
        let scrollView = makeScrollView()
        strip.linkedScrollView = scrollView
        scrollView.contentOffset.x = 390
        XCTAssertEqual(strip.selectedIndex, 1)

        strip.frame.size = CGSize(width: 120, height: 44)
        strip.layoutIfNeeded()

        try assertIndicator(strip, progress: 1)
    }

    func testLayoutPreservesFractionalScrollProgressAfterResize() throws {
        let strip = makeTabStrip()
        let scrollView = makeScrollView()
        strip.linkedScrollView = scrollView
        strip.frame.size = CGSize(width: 120, height: 44)
        strip.layoutIfNeeded()
        scrollView.contentOffset.x = 390 * 0.3

        for size in [CGSize(width: 240, height: 50), CGSize(width: 100, height: 32)] {
            strip.frame.size = size
            strip.layoutIfNeeded()
            XCTAssertEqual(strip.selectedIndex, 0)
            try assertIndicator(strip, progress: 0.3)
        }
    }

    func testSingleTabAlsoRelayoutsItsIndicator() throws {
        let strip = makeTabStrip(titles: ["作品"])
        let scrollView = makeScrollView()
        strip.linkedScrollView = scrollView
        strip.frame.size = CGSize(width: 100, height: 44)
        strip.layoutIfNeeded()
        try assertIndicator(strip, progress: 0)
    }

    func testLinkedScrollViewWithZeroWidthWaitsForValidLayout() throws {
        let strip = makeTabStrip()
        let scrollView = UIScrollView()
        strip.linkedScrollView = scrollView
        scrollView.contentOffset.x = 20
        XCTAssertEqual(strip.selectedIndex, 0)

        scrollView.frame.size = CGSize(width: 390, height: 600)
        scrollView.contentOffset.x = 390
        strip.frame.size = CGSize(width: 120, height: 44)
        strip.layoutIfNeeded()
        XCTAssertEqual(strip.selectedIndex, 1)
        try assertIndicator(strip, progress: 1)
    }

    private func makeTabStrip(titles: [String] = ["作品", "推荐"]) -> NestedPageTabStripView {
        var configuration = NestedPageTabStripConfiguration()
        configuration.titles = titles
        configuration.spacing = 20
        configuration.indicatorVerticalMargin = 2
        return NestedPageTabStripView(configuration: configuration)
    }

    private func makeScrollView() -> UIScrollView {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        scrollView.contentSize = CGSize(width: 780, height: 600)
        return scrollView
    }

    private func assertIndicator(_ strip: NestedPageTabStripView, progress: CGFloat,
                                 file: StaticString = #filePath, line: UInt = #line) throws {
        let stack = try XCTUnwrap(strip.subviews.compactMap { $0 as? UIStackView }.first)
        let indicator = try XCTUnwrap(strip.subviews.first { !($0 is UIStackView) })
        let from = stack.arrangedSubviews[Int(floor(progress))]
        let to = stack.arrangedSubviews[Int(ceil(progress))]
        let startX = stack.convert(from.center, to: strip).x
        let endX = stack.convert(to.center, to: strip).x
        let expectedX = startX + (endX - startX) * (progress - floor(progress))
        XCTAssertEqual(indicator.frame.midX, expectedX, accuracy: 0.5, file: file, line: line)
        XCTAssertEqual(indicator.frame.maxY, strip.bounds.height - strip.configuration.indicatorVerticalMargin,
                       accuracy: 0.5, file: file, line: line)
        XCTAssertEqual(indicator.frame.size, strip.configuration.indicatorSize, file: file, line: line)
    }
}

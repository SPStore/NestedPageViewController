import UIKit

/// 只管理可滚动范围，不接管列表布局或修改列表的真实 contentSize。
final class NestedPageScrollRange {
    private weak var scrollView: UIScrollView?
    private var observations: [NSKeyValueObservation] = []
    private var isApplyingInsets = false
    private var pinnedHeight: CGFloat?
    private(set) var requestedBottomInset: CGFloat
    var onRangeChange: (() -> Void)?

    init(scrollView: UIScrollView, pinnedHeight: CGFloat?) {
        self.scrollView = scrollView
        self.pinnedHeight = pinnedHeight
        requestedBottomInset = scrollView.contentInset.bottom
        observations = [
            scrollView.observe(\.contentSize, options: [.old, .new]) { [weak self] _, change in
                guard change.oldValue != change.newValue else { return }
                self?.refresh()
            },
            scrollView.observe(\.bounds, options: [.old, .new]) { [weak self] _, change in
                guard change.oldValue?.size != change.newValue?.size else { return }
                self?.refresh()
            },
            scrollView.observe(\.contentInset, options: [.old, .new]) { [weak self] _, change in
                guard let self = self, !self.isApplyingInsets,
                      let old = change.oldValue, let new = change.newValue else { return }
                // 只改 top（例如下拉刷新）时，不把组件的补足量误记成业务 bottom inset。
                if old.bottom != new.bottom {
                    self.requestedBottomInset = new.bottom
                }
                self.refresh()
            }
        ]
        refresh()
    }

    func update(pinnedHeight: CGFloat?) {
        self.pinnedHeight = pinnedHeight
        refresh()
    }

    func setRequestedBottomInset(_ inset: CGFloat) {
        requestedBottomInset = inset
        refresh()
    }

    private func bottomInset(for scrollView: UIScrollView) -> CGFloat {
        let baseInset = max(requestedBottomInset, scrollView.safeAreaInsets.bottom)
        guard let pinnedHeight = pinnedHeight else { return baseInset }
        // maxOffsetY = contentHeight - viewportHeight + bottomInset，至少要能到达 -pinnedHeight。
        let minimumInset = scrollView.bounds.height - scrollView.contentSize.height - pinnedHeight
        return max(baseInset, minimumInset)
    }

    func refresh() {
        guard let scrollView = scrollView, !isApplyingInsets else { return }
        var inset = scrollView.contentInset
        inset.bottom = bottomInset(for: scrollView)
        apply(inset, to: scrollView)
        onRangeChange?()
    }

    func updateHeaderInsets(top: CGFloat) {
        guard let scrollView = scrollView else { return }
        let inset = UIEdgeInsets(top: top, left: 0, bottom: bottomInset(for: scrollView), right: 0)
        apply(inset, to: scrollView)
        // 补足量是空内容的滚动空间，不是遮挡区域，不应缩短滚动条的轨道。
        scrollView.scrollIndicatorInsets = UIEdgeInsets(
            top: top, left: 0,
            bottom: max(requestedBottomInset, scrollView.safeAreaInsets.bottom), right: 0
        )
        onRangeChange?()
    }

    private func apply(_ inset: UIEdgeInsets, to scrollView: UIScrollView) {
        guard scrollView.contentInset != inset else { return }
        isApplyingInsets = true
        defer { isApplyingInsets = false }
        scrollView.contentInset = inset
    }

    func invalidate() {
        onRangeChange = nil
        observations.removeAll()
        guard let scrollView = scrollView else { return }
        var inset = scrollView.contentInset
        inset.bottom = requestedBottomInset
        apply(inset, to: scrollView)
        self.scrollView = nil
    }

    deinit {
        invalidate()
    }
}

import UIKit
import NestedPageViewController

/// 协调“右侧主列表 + 左侧副列表”的垂直滚动。
///
/// 本类是 Demo 中的可复用业务组件，不属于 NestedPageViewController 基础库的发布内容。
/// 点餐页中，`primary` 是右侧商品列表，也是 NestedPageViewController 认识的子页列表；
/// `secondary` 是左侧分类列表。两列共享 Tab 上方的组件头部和 Tab 下方的业务内容。
///
/// 垂直结构（展开状态）：
/// ```
/// [ Cover + Tab ]       <- 组件头部，高度 expandedHeaderHeight
/// [ 共享轮播图 ]          <- Tab 下方的业务共享内容，高度 sharedContentHeight
/// [ 左侧分类 | 右侧商品 ] <- 两列各自的独立内容
/// ```
/// Tab 吸顶后，组件头部只剩 `pinnedHeaderHeight`；继续上滑才会完全收起共享轮播图。
///
/// 接入约定：
/// - 主列表是当前子页的 nestedPageContentScrollView；共享内容位于主列表内容开头。
/// - `expandedHeaderHeight` / `pinnedHeaderHeight` 是同一坐标系下，展开 / 吸顶时 Tab 底边的 y 值。
/// - `sharedContentHeight` 仅指 Tab 下方的共享内容，不包含两个列表的独立内容。
/// - 页面转发布局、主副列表 delegate 和实际头部高度；本类不抢占任何 delegate。
/// - 本类拥有副列表的 inset / offset / 裁剪几何；主列表 inset 仍由核心与业务配置。
final class NestedPageDualScrollCoordinator {
    // MARK: - 依赖与状态

    /// 承载两个列表和共享内容的容器视图。
    let contentView: NestedPageDualScrollView
    private weak var pageViewController: NestedPageViewController?
    /// 右侧主列表，也是核心组件认识的子页列表；左侧副列表由本协调器管理。
    private var primary: UIScrollView { contentView.primaryScrollView }
    private var secondary: UIScrollView { contentView.secondaryScrollView }

    /// 共享区域的尺寸、可见高度与保留阅读位置时的展开状态。
    private var sharedHeader: SharedHeaderState
    /// 副列表的位移基准、回弹策略与回调重入状态。
    private var secondaryState: SecondaryScrollState
    /// 展开动画的生命周期与逐帧更新状态。
    private var expansion = HeaderExpansionState()

    /// 横向切 Tab 时的观察；切页一开始就停止副列表惯性。
    private var pagingObservation: NSKeyValueObservation?
    /// 已注册的内部横向滚动手势保护器，例如共享轮播图和商品轮播图。
    private var pagingGuards: [NestedPagePagingGestureGuard] = []

    // MARK: - 对外只读信息

    /// 头部完全展开时，Tab 底边在 contentView 坐标系中的 y 值。
    var expandedHeaderHeight: CGFloat { sharedHeader.expandedHeight }
    /// 头部吸顶时，Tab 底边在 contentView 坐标系中的 y 值。
    var pinnedHeaderHeight: CGFloat { sharedHeader.pinnedHeight }
    /// Tab 下方共享内容的完整高度；点餐页中对应共享轮播图。
    var sharedContentHeight: CGFloat { sharedHeader.contentHeight }
    /// 副列表开启原生回弹时，是否允许顶部越界；不影响下拉展开共享区。
    var allowsSecondaryTopBounce: Bool { secondaryState.allowsTopBounce }
    /// 当前可见的组件头部高度，取值范围为 pinnedHeaderHeight...expandedHeaderHeight。
    var visibleHeaderHeight: CGFloat { sharedHeader.visibleHeaderHeight }
    /// 当前两列顶部需要避让的总高度，即可见头部 + 剩余共享内容。
    var visibleSharedHeight: CGFloat { sharedHeader.visibleSharedHeight }
    /// 正在同一帧内更新头部与两列的几何，页面同步回调应暂时跳过。
    var isUpdatingSharedHeader: Bool { expansion.isApplyingFrame }
    /// 共享区展开动画是否正在运行。
    var isAnimatingSharedHeader: Bool { expansion.isAnimating }

    private var primaryContentDepth: CGFloat { sharedHeader.primaryContentDepth(at: primary.contentOffset.y) }

    // MARK: - 生命周期

    init(pageViewController: NestedPageViewController?, contentView: NestedPageDualScrollView,
         expandedHeaderHeight: CGFloat, pinnedHeaderHeight: CGFloat, sharedContentHeight: CGFloat = 0,
         allowsSecondaryTopBounce: Bool = true) {
        self.pageViewController = pageViewController
        self.contentView = contentView
        let header = SharedHeaderState(expandedHeight: expandedHeaderHeight, pinnedHeight: pinnedHeaderHeight,
                                       contentHeight: sharedContentHeight)
        sharedHeader = header
        secondaryState = SecondaryScrollState(allowsTopBounce: allowsSecondaryTopBounce,
                                              previousOffset: -header.visibleSharedHeight)
        if let popGesture = pageViewController?.navigationController?.interactivePopGestureRecognizer {
            secondary.panGestureRecognizer.require(toFail: popGesture)
        }
        // 非当前页不会收到主列表的 delegate 回调，横向切页开始就停止副列表惯性。
        pagingObservation = pageViewController?.containerScrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            self?.stopExpansionAnimation()
            self?.stopSecondaryMotion()
        }
    }

    deinit {
        expansion.stop()
        pagingObservation?.invalidate()
        for guardGesture in pagingGuards {
            guardGesture.isEnabled = false
            guardGesture.view?.removeGestureRecognizer(guardGesture)
        }
    }

    // MARK: - 布局与头部同步

    /// 从子页的 viewDidLayoutSubviews 调用；副列表内容数量改变后同样需要重新布局。
    func layoutContent() {
        initializeSecondaryIfNeeded()
        if primary.frame != contentView.bounds { primary.frame = contentView.bounds }
        layoutSecondaryViewport()
        updateSecondaryInsets()
        layoutSharedContent()
    }

    /// 导航栏或安全区改变时更新吸顶底边，随后仍由页面同步 Tab 的实际位置。
    func updatePinnedHeaderHeight(_ height: CGFloat) {
        guard sharedHeader.pinnedHeight != height else { return }
        updateHeaderHeights(expanded: sharedHeader.expandedHeight, pinned: height)
        updateVisibleHeaderHeight(sharedHeader.visibleHeaderHeight)
    }

    /// 封面内容或安全区变化后同步展开 / 吸顶边界，再用 updateVisibleHeaderHeight 传入最终 Tab 坐标。
    /// 两个边界一起更新，避免增高导航栏时拿新吸顶高度校验旧展开高度。
    func updateHeaderHeights(expanded: CGFloat, pinned: CGFloat) {
        guard sharedHeader.updateBounds(expanded: expanded, pinned: pinned) else { return }
        // stopMotion 可能同步触发主列表 KVO，先提交新边界，避免回调重入时再次更新。
        stopMotion()
    }

    /// 传入 Tab 实际底边在 contentView 中的坐标，而不是仅传 isSticked。
    /// 滚动、切页和 updateLayouts 后均需同步；位置保留时，头部状态不能由主列表 offset 单独推断。
    func updateVisibleHeaderHeight(_ height: CGFloat) {
        guard !expansion.isApplyingFrame else { return }
        initializeSecondaryIfNeeded()
        let delta = sharedHeader.synchronize(visibleHeaderHeight: height, primaryOffset: primary.contentOffset.y)
        // 展开前先放宽滚动边界，避免新 offset 被旧的吸顶 inset 收回。
        updateSecondaryInsets()
        if !secondaryState.isDrivingPrimary && abs(delta) > 0.001 {
            setSecondaryOffset(secondary.contentOffset.y + delta)
        }
        layoutSecondaryViewport()
        layoutSharedContent()
    }

    // MARK: - 主动展开共享区域

    /// 展开店铺头部及 Tab 下方的共享内容，保留两列各自相对可见区域的阅读位置。
    /// - Parameters:
    ///   - animated: 是否使用逐帧几何动画展开；开启“减少动态效果”时会直接完成。
    ///   - onUpdate: 每帧完成两列补偿后回调，业务层可在此刷新布局或选中状态。
    /// 有共享内容时，需要通过 `contentView.sharedContentView` 提供独立展示层。
    func expandSharedHeader(animated: Bool = false, onUpdate: (() -> Void)? = nil) {
        guard let pager = pageViewController,
              pager.viewController(at: pager.currentIndex)?.nestedPageContentScrollView === primary,
              sharedHeader.contentHeight == 0 || contentView.sharedContentView != nil else { return }
        stopMotion()
        initializeSecondaryIfNeeded()
        let primaryDepth = max(0, primaryContentDepth)
        let secondaryDepth = max(0, secondary.contentOffset.y + sharedHeader.visibleSharedHeight)
        let initialHeader = sharedHeader.visibleHeaderHeight
        let initialContent = sharedHeader.visibleContentHeight
        let initialSize = contentView.bounds.size
        let scale = max(1, contentView.traitCollection.displayScale)
        let update: (CGFloat) -> Void = { [weak self] progress in
            guard let self else { return }
            // UIScrollView 会按屏幕像素收敛 offset。高度也对齐像素，并始终从原阅读锚点求绝对偏移，
            // 避免每帧累加亚像素舍入误差，导致动画结束后内容漂移。
            let header = initialHeader + (self.sharedHeader.expandedHeight - initialHeader) * progress
            let content = initialContent + (self.sharedHeader.contentHeight - initialContent) * progress
            self.applySharedExpansion(
                headerHeight: progress < 1 ? (header * scale).rounded() / scale : self.sharedHeader.expandedHeight,
                contentHeight: progress < 1 ? (content * scale).rounded() / scale : self.sharedHeader.contentHeight,
                primaryDepth: primaryDepth,
                secondaryDepth: secondaryDepth
            )
            onUpdate?()
        }
        guard animated, contentView.window != nil, !UIAccessibility.isReduceMotionEnabled,
              sharedHeader.collapsedHeight > 0.5 else {
            update(1)
            return
        }
        expansion.animation = SharedHeaderExpansionAnimation(duration: 0.32) { [weak self] progress in
            guard let self else { return }
            guard let pager = self.pageViewController else {
                self.stopExpansionAnimation()
                return
            }
            // 用户拖动、翻页或尺寸变化后，让原生滚动从当前几何接管，不跳到动画终点。
            // 普通点击不打断，避免再次点到移动中的 Tab 时停在半展开状态。
            guard self.contentView.window != nil, self.contentView.bounds.size == initialSize,
                  self.pageViewController?.viewController(at: pager.currentIndex)?.nestedPageContentScrollView === self.primary,
                  !self.primary.isDragging, !self.secondary.isDragging,
                  !pager.containerScrollView.isDragging,
                  !self.pagingGuards.contains(where: { ($0.view as? UIScrollView)?.isDragging == true }) else {
                self.stopExpansionAnimation()
                return
            }
            if progress >= 1 { self.stopExpansionAnimation() }
            update(progress)
        }
    }

    private func applySharedExpansion(headerHeight: CGFloat, contentHeight: CGFloat,
                                      primaryDepth: CGFloat, secondaryDepth: CGFloat) {
        guard let pager = pageViewController else { return }
        expansion.isApplyingFrame = true
        defer { expansion.isApplyingFrame = false }
        let headerRange = sharedHeader.expandedHeight - sharedHeader.pinnedHeight
        pager.setHeaderExpansionProgress(headerRange > 0 ? (headerHeight - sharedHeader.pinnedHeight) / headerRange : 1)
        primary.setContentOffset(CGPoint(x: primary.contentOffset.x,
                                        y: primaryDepth + sharedHeader.contentHeight - headerHeight - contentHeight), animated: false)
        sharedHeader.applyExpansion(headerHeight: headerHeight, contentHeight: contentHeight,
                                    primaryOffset: primary.contentOffset.y)
        updateSecondaryInsets()
        setSecondaryOffset(secondaryDepth - sharedHeader.visibleSharedHeight)
        layoutSecondaryViewport()
        layoutSharedContent()
    }

    /// 分类等业务需要跳到指定内容前，先收起保留阅读位置时悬停的头部 / 共享区。
    /// 正常随列表滚动的头部不提前收起，仍由业务接下来的定位动画带动。
    func prepareForPrimaryContentSelection() {
        // 切页后也可能出现“头部已展开、商品仍在深处”，不一定经过显式展开共享区。
        // 自然滚动时展开头部的底边与内容起点重合；二者分离，说明头部正在悬停。
        let hasHoveringHeader = sharedHeader.visibleHeaderHeight > sharedHeader.pinnedHeight + 0.5
            && primary.contentOffset.y + sharedHeader.visibleHeaderHeight > 0.5
        guard sharedHeader.hasFloatingContent || hasHoveringHeader else { return }
        let remaining = sharedHeader.visibleSharedHeight - sharedHeader.pinnedHeight
        primary.setContentOffset(CGPoint(x: primary.contentOffset.x,
                                        y: primary.contentOffset.y + remaining), animated: false)
    }

    // MARK: - 双列表滚动联动

    /// 从两个列表的 UIScrollViewDelegate 原样转发。程序化修改副列表也会更新位移基准。
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !expansion.isApplyingFrame && !secondaryState.isUpdating && (scrollView === primary || scrollView === secondary) {
            stopExpansionAnimation()
        }
        guard scrollView === secondary, !secondaryState.isUpdating else { return }
        let previous = secondaryState.previousOffset
        secondaryState.previousOffset = secondary.contentOffset.y
        guard secondaryState.isInitialized else { return }
        defer {
            // 先处理拖拽展开，再收回剩余的顶部越界；底部仍由 UIKit 回弹。
            // 关闭原生回弹时无需干预，0.5pt 容差避免像素舍入打断向上惯性。
            if !secondaryState.allowsTopBounce, secondary.bounces,
               secondary.contentOffset.y < -sharedHeader.visibleSharedHeight - 0.5 {
                setSecondaryOffset(-sharedHeader.visibleSharedHeight)
            }
        }
        // 根据主列表身份判断当前页，不假设双列表一定放在第 0 个 Tab。
        guard let pager = pageViewController,
              pager.viewController(at: pager.currentIndex)?.nestedPageContentScrollView === primary,
              secondary.isDragging || secondary.isDecelerating else { return }
        let delta = secondaryState.previousOffset - previous
        // isDragging 在真实减速回调中仍可能为 true，不能用它判断手指是否还在拖拽。
        let panState = secondary.panGestureRecognizer.state
        let isDraggingWithFinger = panState == .began || panState == .changed
        // 仅吸顶后的向下惯性不传给共享区；向上惯性、非吸顶时的惯性仍正常联动。
        // top inset 保留了拖拽展开的空间，减速到视觉顶部时需截停并收回越界量。
        if !isDraggingWithFinger, delta < 0, sharedHeader.visibleHeaderHeight <= sharedHeader.pinnedHeight + 0.5 {
            if secondaryState.previousOffset <= -sharedHeader.visibleSharedHeight {
                updateSecondary {
                    stopScrolling(secondary)
                    secondary.setContentOffset(CGPoint(x: secondary.contentOffset.x, y: -sharedHeader.visibleSharedHeight), animated: false)
                }
            }
            return
        }
        let localPosition = max(0, previous + sharedHeader.visibleSharedHeight)
        let consumed: CGFloat
        if delta > 0 {
            // 即使业务开启回弹，也不能把越界恢复误算为收起共享区域。
            let beyondBounce = max(0, delta + min(0, previous + sharedHeader.visibleSharedHeight))
            consumed = min(beyondBounce, sharedHeader.maximumCollapse - sharedHeader.collapsedHeight)
        } else if primaryContentDepth <= 0.5 {
            consumed = max(-sharedHeader.collapsedHeight, min(0, delta + localPosition))
        } else {
            consumed = 0
        }
        guard abs(consumed) > 0.001 else { return }
        secondaryState.isDrivingPrimary = true
        defer {
            secondaryState.isDrivingPrimary = false
            secondaryState.previousOffset = secondary.contentOffset.y
        }
        // 共享位移由主列表驱动核心头部；独立位移仍交给副列表原生滚动。
        primary.setContentOffset(CGPoint(x: primary.contentOffset.x, y: primary.contentOffset.y + consumed), animated: false)
    }

    /// 从两个列表的 `scrollViewWillBeginDragging` 转发，手指接管一列时停止另一列的运动。
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        stopExpansionAnimation()
        if scrollView === primary { stopSecondaryMotion() }
        else if scrollView === secondary {
            stopScrolling(primary)
            secondaryState.previousOffset = secondary.contentOffset.y
        }
    }

    // MARK: - 副列表定位

    /// 仅重置副列表的阅读位置，不更改主列表及共享区域状态。
    func resetSecondaryPosition() {
        setSecondaryOffset(-sharedHeader.visibleSharedHeight)
    }

    /// 业务选中一项后可请求将其内容坐标 rect 显示出来；用户拖动 / 减速期间不抢位置。
    func revealSecondaryRect(_ rect: CGRect) {
        guard !secondary.isDragging, !secondary.isDecelerating, !secondaryState.isDrivingPrimary else { return }
        let top = secondary.contentOffset.y + sharedHeader.visibleSharedHeight
        let bottom = secondary.contentOffset.y + secondary.bounds.height
        if rect.minY < top { setSecondaryOffset(rect.minY - sharedHeader.visibleSharedHeight) }
        else if rect.maxY > bottom { setSecondaryOffset(rect.maxY - secondary.bounds.height) }
    }

    /// 将业务选中项尽量居中到副列表的实际可见区域；首尾和短内容不额外制造留白。
    /// 建议在主列表跳转完成、共享区域高度稳定后调用，避免两列动画互相补偿。
    func centerSecondaryRect(_ rect: CGRect, animated: Bool = true) {
        guard !secondary.isDragging, !secondary.isDecelerating, !secondaryState.isDrivingPrimary,
              secondary.bounds.height > sharedHeader.visibleSharedHeight else { return }
        // 副列表本身仍是全屏高，顶部被共享区域裁剪，不能直接使用整个 bounds 的中点。
        let center = (sharedHeader.visibleSharedHeight + secondary.bounds.height) / 2
        let minimum = -sharedHeader.visibleSharedHeight
        let maximum = max(minimum, secondary.contentSize.height - secondary.bounds.height + secondary.contentInset.bottom)
        let target = min(maximum, max(minimum, rect.midY - center))
        setSecondaryOffset(target, animated: animated && secondary.window != nil && !UIAccessibility.isReduceMotionEnabled)
    }

    // MARK: - 手势与运动管理

    /// 让内部横向滚动视图比页面横向切 Tab 手势优先识别。
    /// 任意 UIScrollView / UICollectionView 都可注册；横纵方向判断仍由该视图自身负责。
    func prioritizeHorizontalScrolling(in scrollViews: [UIScrollView]) {
        guard let pager = pageViewController else { return }
        for scrollView in scrollViews {
            guard scrollView !== pager.containerScrollView, scrollView !== primary, scrollView !== secondary,
                  !pagingGuards.contains(where: { $0.view === scrollView }) else { continue }
            let guardGesture = NestedPagePagingGestureGuard(target: nil, action: nil)
            guardGesture.name = "nestedPage.dualScroll.pagingGuard"
            guardGesture.pagingPan = pager.containerScrollView.panGestureRecognizer
            guardGesture.cancelsTouchesInView = false
            guardGesture.delaysTouchesBegan = false
            guardGesture.delaysTouchesEnded = false
            scrollView.addGestureRecognizer(guardGesture)
            pager.containerScrollView.panGestureRecognizer.require(toFail: guardGesture)
            // 不能让主列表纵向 pan 等待内部横向 pan，否则纵拖会被阻断。
            if let popGesture = pager.navigationController?.interactivePopGestureRecognizer {
                scrollView.panGestureRecognizer.require(toFail: popGesture)
            }
            pagingGuards.append(guardGesture)
        }
    }

    /// 切页完成、程序化跳转前调用，同时停止两列和已注册横向内容的运动。
    func stopMotion() {
        stopExpansionAnimation()
        stopSecondaryMotion()
        stopScrolling(primary)
        for guardGesture in pagingGuards {
            if let scrollView = guardGesture.view as? UIScrollView { stopScrolling(scrollView) }
        }
    }

    private func stopExpansionAnimation() {
        expansion.stop()
    }

    // MARK: - 应用副列表与共享内容布局

    private func layoutSecondaryViewport() {
        updateSecondary { contentView.layoutSecondaryViewport(visibleSharedHeight: sharedHeader.visibleSharedHeight) }
    }

    private func layoutSharedContent() {
        contentView.layoutSharedContent(visibleHeaderHeight: sharedHeader.visibleHeaderHeight,
                                        visibleSharedHeight: sharedHeader.visibleSharedHeight, contentHeight: sharedHeader.contentHeight)
    }

    private func initializeSecondaryIfNeeded() {
        guard !secondaryState.isInitialized else { return }
        secondaryState.isInitialized = true
        // 延迟到初始化完成后的首次布局 / 同步，避免 init 内修改 offset 导致业务 delegate 重入构造。
        updateSecondary {
            secondary.contentInsetAdjustmentBehavior = .never
            secondary.scrollsToTop = false
            secondary.contentInset.top = sharedHeader.expandedTotalHeight
            secondary.contentOffset.y = -sharedHeader.expandedTotalHeight
        }
    }

    private func updateSecondaryInsets() {
        updateSecondary {
            // 主列表独立内容未回顶时，副列表不能强行拉回主列表。
            // 位置保留开启后，头部未吸顶也可能处于这种状态。
            let top = primaryContentDepth <= 0.5 ? sharedHeader.expandedTotalHeight : sharedHeader.visibleSharedHeight
            let bottom = max(contentView.safeAreaInsets.bottom,
                             contentView.bounds.height - secondary.contentSize.height - sharedHeader.pinnedHeight)
            let inset = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
            if secondary.contentInset != inset {
                let offset = secondary.contentOffset
                secondary.contentInset = inset
                if secondary.contentOffset != offset { secondary.contentOffset = offset }
            }
        }
    }

    private func setSecondaryOffset(_ value: CGFloat, animated: Bool = false) {
        updateSecondary {
            secondary.setContentOffset(CGPoint(x: secondary.contentOffset.x, y: value), animated: animated)
        }
    }

    private func updateSecondary(_ changes: () -> Void) {
        // UIKit 修改会同步触发 delegate / KVO，标记需分步写入；不能在结构体的 mutating 闭包内执行 changes。
        // 这样回调再次读取 secondaryState 时，不会与 Swift 对值类型的独占写入冲突。
        let wasUpdating = secondaryState.isUpdating
        secondaryState.isUpdating = true
        defer {
            secondaryState.isUpdating = wasUpdating
            secondaryState.previousOffset = secondary.contentOffset.y
        }
        changes()
    }

    private func stopSecondaryMotion() {
        // 除手势减速外，也要终止分类居中的程序化动画。
        stopScrolling(secondary)
        secondaryState.previousOffset = secondary.contentOffset.y
    }

    private func stopScrolling(_ scrollView: UIScrollView) {
        if #available(iOS 17.4, *) { scrollView.stopScrollingAndZooming() }
        else { scrollView.setContentOffset(scrollView.contentOffset, animated: false) }
    }
}

// MARK: - 协调器内部状态

private extension NestedPageDualScrollCoordinator {
    /// 共享区域的完整状态：组件头部 + Tab 下方的业务共享内容。
    /// 只计算数值并同步相关字段，不操作 UIScrollView，避免一次高度更新留下半完成状态。
    struct SharedHeaderState {
        private(set) var expandedHeight: CGFloat
        private(set) var pinnedHeight: CGFloat
        let contentHeight: CGFloat
        /// 当前 Tab 底边和共享内容底边在 contentView 中的 y 值。
        private(set) var visibleHeaderHeight: CGFloat
        private(set) var visibleSharedHeight: CGFloat

        /// 保留阅读位置主动展开后，额外展示的共享内容。nil 表示已恢复到自然滚动状态。
        /// 这部分可见量需要单独保存，因为它无法只从主列表 offset 推导出来。
        private var floatingContentHeight: CGFloat?
        /// 上一次 Tab 底边对应的主列表内容坐标，用于消耗主动展开的共享内容。
        private var lastPrimaryPosition: CGFloat?

        var expandedTotalHeight: CGFloat { expandedHeight + contentHeight }
        var maximumCollapse: CGFloat { expandedTotalHeight - pinnedHeight }
        var collapsedHeight: CGFloat { expandedTotalHeight - visibleSharedHeight }
        var visibleContentHeight: CGFloat { visibleSharedHeight - visibleHeaderHeight }
        var hasFloatingContent: Bool { floatingContentHeight != nil }

        init(expandedHeight: CGFloat, pinnedHeight: CGFloat, contentHeight: CGFloat) {
            precondition(expandedHeight >= pinnedHeight && pinnedHeight >= 0)
            precondition(contentHeight >= 0)
            self.expandedHeight = expandedHeight
            self.pinnedHeight = pinnedHeight
            self.contentHeight = contentHeight
            visibleHeaderHeight = expandedHeight
            visibleSharedHeight = expandedHeight + contentHeight
        }

        /// 更新边界后仍需同步 Tab 的实际位置；返回是否变化，供协调器决定是否停止运动。
        mutating func updateBounds(expanded: CGFloat, pinned: CGFloat) -> Bool {
            precondition(expanded >= pinned && pinned >= 0)
            guard expandedHeight != expanded || pinnedHeight != pinned else { return false }
            expandedHeight = expanded
            pinnedHeight = pinned
            return true
        }

        /// 根据实际 Tab 位置更新可见区域，返回副列表保持阅读位置所需的 offset 补偿量。
        mutating func synchronize(visibleHeaderHeight height: CGFloat, primaryOffset: CGFloat) -> CGFloat {
            let newHeight = min(expandedHeight, max(pinnedHeight, height))
            let position = primaryOffset + newHeight
            let naturalRemaining = min(contentHeight, max(0, contentHeight - position))
            var remainingContent = naturalRemaining
            if let floating = floatingContentHeight {
                // 向上先消耗共享区；向下先滚回独立内容，不在原阅读点提前展开共享区。
                let upward = max(0, position - (lastPrimaryPosition ?? position))
                remainingContent = max(naturalRemaining, floating - upward)
                floatingContentHeight = remainingContent > naturalRemaining + 0.001 ? remainingContent : nil
            }
            lastPrimaryPosition = position
            let newSharedHeight = newHeight + remainingContent
            let delta = visibleSharedHeight - newSharedHeight
            visibleHeaderHeight = newHeight
            visibleSharedHeight = newSharedHeight
            return delta
        }

        /// 主动展开的一帧完成后，一起记录两种高度和后续滚动所需的基准。
        mutating func applyExpansion(headerHeight: CGFloat, contentHeight: CGFloat, primaryOffset: CGFloat) {
            visibleHeaderHeight = headerHeight
            visibleSharedHeight = headerHeight + contentHeight
            floatingContentHeight = contentHeight
            lastPrimaryPosition = primaryOffset + headerHeight
        }

        /// 主列表独立内容在共享区域底边以上已滚过的距离；不大于 0 时视为尚未离开顶部。
        func primaryContentDepth(at offset: CGFloat) -> CGFloat {
            offset + visibleSharedHeight - contentHeight
        }
    }

    /// 副列表一次次滚动之间需要保留的状态；不保存 UIScrollView 已有的拖拽 / 减速状态。
    struct SecondaryScrollState {
        let allowsTopBounce: Bool
        /// 上一次已处理的 offset，程序化调整完成后也必须同步。
        var previousOffset: CGFloat
        var isInitialized = false
        /// 正在程序化修改副列表，忽略由此产生的联动回调。
        var isUpdating = false
        /// 副列表正在驱动主列表；收到头部同步时不再反向补偿副列表。
        var isDrivingPrimary = false
    }

    /// 主动展开的运行状态。每帧的几何更新也用于无动画展开，因此与动画生命周期分别记录。
    struct HeaderExpansionState {
        var animation: SharedHeaderExpansionAnimation?
        var isApplyingFrame = false
        var isAnimating: Bool { animation != nil }

        /// 停在当前帧，不改变几何；后续滚动可以从当前位置接管。
        mutating func stop() {
            animation?.invalidate()
            animation = nil
        }
    }
}

/// 单一时钟驱动真实几何，不用模型已到终点、呈现层仍在运动的动画来驱动嵌套滚动。
private final class SharedHeaderExpansionAnimation: NSObject {
    private var displayLink: CADisplayLink?
    private var onFrame: ((CGFloat) -> Void)?
    private let startedAt = CACurrentMediaTime()
    private let duration: CFTimeInterval

    init(duration: CFTimeInterval, onFrame: @escaping (CGFloat) -> Void) {
        self.duration = duration
        self.onFrame = onFrame
        super.init()
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        displayLink = link
        link.add(to: .main, forMode: .common)
    }

    @objc private func tick(_ link: CADisplayLink) {
        let t = min(1, max(0, (link.timestamp - startedAt) / duration))
        let progress = 1 - pow(1 - t, 3) // ease-out
        onFrame?(CGFloat(progress))
    }

    func invalidate() {
        displayLink?.invalidate()
        displayLink = nil
        onFrame = nil
    }
}

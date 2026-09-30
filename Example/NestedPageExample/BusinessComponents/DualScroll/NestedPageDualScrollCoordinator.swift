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
/// 吸顶后，组件头部只剩 `pinnedHeaderHeight`，共享轮播图完全收起。
///
/// 接入约定：
/// - 主列表是当前子页的 nestedPageContentScrollView；共享内容位于主列表内容开头。
/// - `expandedHeaderHeight` / `pinnedHeaderHeight` 是同一坐标系下，展开 / 吸顶时 Tab 底边的 y 值。
/// - `sharedContentHeight` 仅指 Tab 下方的共享内容，不包含两个列表的独立内容。
/// - 页面转发布局、主副列表 delegate 和实际头部高度；本类不抢占任何 delegate。
/// - 本类拥有副列表的 inset / offset / 裁剪几何；主列表 inset 仍由核心与业务配置。
final class NestedPageDualScrollCoordinator {
    /// 承载两个列表和共享内容的容器视图。
    let contentView: NestedPageDualScrollView
    /// 头部完全展开时，Tab 底边在 contentView 坐标系中的 y 值。
    private(set) var expandedHeaderHeight: CGFloat
    /// 头部吸顶时，Tab 底边在 contentView 坐标系中的 y 值。
    private(set) var pinnedHeaderHeight: CGFloat
    /// Tab 下方共享内容的完整高度；点餐页中对应共享轮播图。
    let sharedContentHeight: CGFloat
    /// 副列表开启原生回弹时，是否允许顶部越界；不影响下拉展开共享区。
    let allowsSecondaryTopBounce: Bool
    /// 当前可见的组件头部高度，取值范围为 pinnedHeaderHeight...expandedHeaderHeight。
    private(set) var visibleHeaderHeight: CGFloat
    /// 当前两列顶部需要避让的总高度，即可见头部 + 剩余共享内容。
    private(set) var visibleSharedHeight: CGFloat

    private weak var pageViewController: NestedPageViewController?
    /// 右侧主列表；负责驱动 NestedPageViewController 头部折叠。
    private var primary: UIScrollView { contentView.primaryScrollView }
    /// 左侧副列表；拥有独立的滚动位置。
    private var secondary: UIScrollView { contentView.secondaryScrollView }
    /// 完全展开时，列表上方的总共享高度（组件头部 + 业务共享内容）。
    private var initialSharedHeight: CGFloat { expandedHeaderHeight + sharedContentHeight }
    /// 从完全展开到完全吸顶，共享区最多可收起的距离。
    private var maximumSharedCollapse: CGFloat { initialSharedHeight - pinnedHeaderHeight }
    /// 共享区目前已经收起的距离。
    private var collapsedSharedHeight: CGFloat { initialSharedHeight - visibleSharedHeight }
    /// 主列表独立内容已向上滚过的深度；0 表示尚未越过共享内容。
    private var primaryContentDepth: CGFloat { primary.contentOffset.y + visibleSharedHeight - sharedContentHeight }
    /// 上一次已处理的副列表 offset，用于计算本次滚动增量。
    private var secondaryOffset: CGFloat
    /// 副列表的 inset 和初始 offset 是否已完成首次配置。
    private var hasInitializedSecondary = false
    /// 协调器正在修改副列表，用于忽略这些程序化滚动回调。
    private var isUpdatingSecondary = false
    /// 当前是副列表在反向驱动主列表，避免两列相互递归补偿。
    private var isDrivingFromSecondary = false
    /// 正在同一帧内更新头部与两列的几何，页面同步回调应暂时跳过。
    private(set) var isUpdatingSharedHeader = false
    /// 共享区展开动画是否正在运行。
    var isAnimatingSharedHeader: Bool { expansionAnimation != nil }
    private var expansionAnimation: SharedHeaderExpansionAnimation?
    /// 点击 Tab 显式展开后，共享内容的剩余可见高度。
    /// 此时共享区处于“悬浮”中间态，不能只根据主列表 offset 反推。
    private var floatingSharedContentHeight: CGFloat?
    /// 上一次主列表内容在 Tab 下方的逻辑位置，用于判断本次滚动方向。
    private var lastPrimaryPosition: CGFloat?
    /// 横向切 Tab 时的观察；切页一开始就停止副列表惯性。
    private var pagingObservation: NSKeyValueObservation?
    /// 已注册的内部横向滚动手势保护器，例如共享轮播图和商品轮播图。
    private var pagingGuards: [NestedPagePagingGestureGuard] = []

    init(pageViewController: NestedPageViewController?, contentView: NestedPageDualScrollView,
         expandedHeaderHeight: CGFloat, pinnedHeaderHeight: CGFloat, sharedContentHeight: CGFloat = 0,
         allowsSecondaryTopBounce: Bool = true) {
        precondition(expandedHeaderHeight >= pinnedHeaderHeight && pinnedHeaderHeight >= 0)
        precondition(sharedContentHeight >= 0)
        self.pageViewController = pageViewController
        self.contentView = contentView
        self.expandedHeaderHeight = expandedHeaderHeight
        self.pinnedHeaderHeight = pinnedHeaderHeight
        self.sharedContentHeight = sharedContentHeight
        self.allowsSecondaryTopBounce = allowsSecondaryTopBounce
        visibleHeaderHeight = expandedHeaderHeight
        visibleSharedHeight = expandedHeaderHeight + sharedContentHeight
        secondaryOffset = -visibleSharedHeight
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
        expansionAnimation?.invalidate()
        pagingObservation?.invalidate()
        for guardGesture in pagingGuards {
            guardGesture.isEnabled = false
            guardGesture.view?.removeGestureRecognizer(guardGesture)
        }
    }

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
        guard pinnedHeaderHeight != height else { return }
        updateHeaderHeights(expanded: expandedHeaderHeight, pinned: height)
        updateVisibleHeaderHeight(visibleHeaderHeight)
    }

    /// 封面内容或安全区变化后同步展开 / 吸顶边界，再用 updateVisibleHeaderHeight 传入最终 Tab 坐标。
    /// 两个边界一起更新，避免增高导航栏时拿新吸顶高度校验旧展开高度。
    func updateHeaderHeights(expanded: CGFloat, pinned: CGFloat) {
        precondition(expanded >= pinned && pinned >= 0)
        guard expandedHeaderHeight != expanded || pinnedHeaderHeight != pinned else { return }
        expandedHeaderHeight = expanded
        pinnedHeaderHeight = pinned
        // stopMotion 可能同步触发主列表 KVO，先提交新边界，避免回调重入时再次更新。
        stopMotion()
    }

    /// 传入 Tab 实际底边在 contentView 中的坐标，而不是仅传 isSticked。
    /// 滚动、切页和 updateLayouts 后均需同步；位置保留时，头部状态不能由主列表 offset 单独推断。
    func updateVisibleHeaderHeight(_ height: CGFloat) {
        guard !isUpdatingSharedHeader else { return }
        initializeSecondaryIfNeeded()
        let newHeight = min(expandedHeaderHeight, max(pinnedHeaderHeight, height))
        let position = primary.contentOffset.y + newHeight
        let naturalRemaining = min(sharedContentHeight, max(0, sharedContentHeight - position))
        var remainingContent = naturalRemaining
        if let floating = floatingSharedContentHeight {
            // 向上先消耗共享区；向下先滚回独立内容，不在原阅读点提前展开共享区。
            let upward = max(0, position - (lastPrimaryPosition ?? position))
            remainingContent = max(naturalRemaining, floating - upward)
            floatingSharedContentHeight = remainingContent > naturalRemaining + 0.001 ? remainingContent : nil
        }
        lastPrimaryPosition = position
        let newSharedHeight = newHeight + remainingContent
        let delta = visibleSharedHeight - newSharedHeight
        visibleHeaderHeight = newHeight
        visibleSharedHeight = newSharedHeight
        // 展开前先放宽滚动边界，避免新 offset 被旧的吸顶 inset 收回。
        updateSecondaryInsets()
        if !isDrivingFromSecondary && abs(delta) > 0.001 {
            setSecondaryOffset(secondary.contentOffset.y + delta)
        }
        layoutSecondaryViewport()
        layoutSharedContent()
    }

    /// 展开店铺头部及 Tab 下方的共享内容，保留两列各自相对可见区域的阅读位置。
    /// - Parameters:
    ///   - animated: 是否使用逐帧几何动画展开；关闭减少动效时会直接完成。
    ///   - onUpdate: 每帧完成两列补偿后回调，业务层可在此刷新布局或选中状态。
    /// 有共享内容时，需要通过 `contentView.sharedContentView` 提供独立展示层。
    func expandSharedHeader(animated: Bool = false, onUpdate: (() -> Void)? = nil) {
        guard let pager = pageViewController,
              pager.viewController(at: pager.currentIndex)?.nestedPageContentScrollView === primary,
              sharedContentHeight == 0 || contentView.sharedContentView != nil else { return }
        stopMotion()
        initializeSecondaryIfNeeded()
        let primaryDepth = max(0, primaryContentDepth)
        let secondaryDepth = max(0, secondary.contentOffset.y + visibleSharedHeight)
        let initialHeader = visibleHeaderHeight
        let initialContent = visibleSharedHeight - visibleHeaderHeight
        let initialSize = contentView.bounds.size
        let scale = max(1, contentView.traitCollection.displayScale)
        let update: (CGFloat) -> Void = { [weak self] progress in
            guard let self else { return }
            // UIScrollView 会按屏幕像素收敛 offset。高度也对齐像素，并始终从原阅读锚点求绝对偏移，
            // 避免每帧累加亚像素舍入误差，导致动画结束后内容漂移。
            let header = initialHeader + (self.expandedHeaderHeight - initialHeader) * progress
            let content = initialContent + (self.sharedContentHeight - initialContent) * progress
            self.applySharedExpansion(
                headerHeight: progress < 1 ? (header * scale).rounded() / scale : self.expandedHeaderHeight,
                contentHeight: progress < 1 ? (content * scale).rounded() / scale : self.sharedContentHeight,
                primaryDepth: primaryDepth,
                secondaryDepth: secondaryDepth
            )
            onUpdate?()
        }
        guard animated, contentView.window != nil, !UIAccessibility.isReduceMotionEnabled,
              initialSharedHeight - visibleSharedHeight > 0.5 else {
            update(1)
            return
        }
        expansionAnimation = SharedHeaderExpansionAnimation(duration: 0.32) { [weak self] progress in
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
        isUpdatingSharedHeader = true
        defer { isUpdatingSharedHeader = false }
        let headerRange = expandedHeaderHeight - pinnedHeaderHeight
        pager.setHeaderExpansionProgress(headerRange > 0 ? (headerHeight - pinnedHeaderHeight) / headerRange : 1)
        primary.setContentOffset(CGPoint(x: primary.contentOffset.x,
                                        y: primaryDepth + sharedContentHeight - headerHeight - contentHeight), animated: false)
        visibleHeaderHeight = headerHeight
        visibleSharedHeight = headerHeight + contentHeight
        floatingSharedContentHeight = contentHeight
        lastPrimaryPosition = primary.contentOffset.y + headerHeight
        updateSecondaryInsets()
        setSecondaryOffset(secondaryDepth - visibleSharedHeight)
        layoutSecondaryViewport()
        layoutSharedContent()
    }

    /// 分类等业务需要跳到指定内容前，先收起显式展开的共享区，避免向上方分组跳转时留在悬空状态。
    func prepareForPrimaryContentSelection() {
        guard floatingSharedContentHeight != nil else { return }
        let remaining = visibleSharedHeight - pinnedHeaderHeight
        primary.setContentOffset(CGPoint(x: primary.contentOffset.x,
                                        y: primary.contentOffset.y + remaining), animated: false)
    }

    /// 从两个列表的 UIScrollViewDelegate 原样转发。程序化修改副列表也会更新位移基准。
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !isUpdatingSharedHeader && !isUpdatingSecondary && (scrollView === primary || scrollView === secondary) {
            stopExpansionAnimation()
        }
        guard scrollView === secondary, !isUpdatingSecondary else { return }
        let previous = secondaryOffset
        secondaryOffset = secondary.contentOffset.y
        guard hasInitializedSecondary else { return }
        defer {
            // 先处理拖拽展开，再收回剩余的顶部越界；底部仍由 UIKit 回弹。
            // 关闭原生回弹时无需干预，0.5pt 容差避免像素舍入打断向上惯性。
            if !allowsSecondaryTopBounce, secondary.bounces,
               secondary.contentOffset.y < -visibleSharedHeight - 0.5 {
                setSecondaryOffset(-visibleSharedHeight)
            }
        }
        // 根据主列表身份判断当前页，不假设双列表一定放在第 0 个 Tab。
        guard let pager = pageViewController,
              pager.viewController(at: pager.currentIndex)?.nestedPageContentScrollView === primary,
              secondary.isDragging || secondary.isDecelerating else { return }
        let delta = secondaryOffset - previous
        // isDragging 在真实减速回调中仍可能为 true，不能用它判断手指是否还在拖拽。
        let panState = secondary.panGestureRecognizer.state
        let isDraggingWithFinger = panState == .began || panState == .changed
        // 仅吸顶后的向下惯性不传给共享区；向上惯性、非吸顶时的惯性仍正常联动。
        // top inset 保留了拖拽展开的空间，减速到视觉顶部时需截停并收回越界量。
        if !isDraggingWithFinger, delta < 0, visibleHeaderHeight <= pinnedHeaderHeight + 0.5 {
            if secondaryOffset <= -visibleSharedHeight {
                updateSecondary {
                    stopScrolling(secondary)
                    secondary.setContentOffset(CGPoint(x: secondary.contentOffset.x, y: -visibleSharedHeight), animated: false)
                }
            }
            return
        }
        let localPosition = max(0, previous + visibleSharedHeight)
        let consumed: CGFloat
        if delta > 0 {
            // 即使业务开启回弹，也不能把越界恢复误算为收起共享区域。
            let beyondBounce = max(0, delta + min(0, previous + visibleSharedHeight))
            consumed = min(beyondBounce, maximumSharedCollapse - collapsedSharedHeight)
        } else if primaryContentDepth <= 0.5 {
            consumed = max(-collapsedSharedHeight, min(0, delta + localPosition))
        } else {
            consumed = 0
        }
        guard abs(consumed) > 0.001 else { return }
        isDrivingFromSecondary = true
        defer {
            isDrivingFromSecondary = false
            secondaryOffset = secondary.contentOffset.y
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
            secondaryOffset = secondary.contentOffset.y
        }
    }

    /// 仅重置副列表的阅读位置，不更改主列表及共享区域状态。
    func resetSecondaryPosition() {
        setSecondaryOffset(-visibleSharedHeight)
    }

    /// 业务选中一项后可请求将其内容坐标 rect 显示出来；用户拖动 / 减速期间不抢位置。
    func revealSecondaryRect(_ rect: CGRect) {
        guard !secondary.isDragging, !secondary.isDecelerating, !isDrivingFromSecondary else { return }
        let top = secondary.contentOffset.y + visibleSharedHeight
        let bottom = secondary.contentOffset.y + secondary.bounds.height
        if rect.minY < top { setSecondaryOffset(rect.minY - visibleSharedHeight) }
        else if rect.maxY > bottom { setSecondaryOffset(rect.maxY - secondary.bounds.height) }
    }

    /// 将业务选中项尽量居中到副列表的实际可见区域；首尾和短内容不额外制造留白。
    /// 建议在主列表跳转完成、共享区域高度稳定后调用，避免两列动画互相补偿。
    func centerSecondaryRect(_ rect: CGRect, animated: Bool = true) {
        guard !secondary.isDragging, !secondary.isDecelerating, !isDrivingFromSecondary,
              secondary.bounds.height > visibleSharedHeight else { return }
        // 副列表本身仍是全屏高，顶部被共享区域裁剪，不能直接使用整个 bounds 的中点。
        let center = (visibleSharedHeight + secondary.bounds.height) / 2
        let minimum = -visibleSharedHeight
        let maximum = max(minimum, secondary.contentSize.height - secondary.bounds.height + secondary.contentInset.bottom)
        let target = min(maximum, max(minimum, rect.midY - center))
        setSecondaryOffset(target, animated: animated && secondary.window != nil && !UIAccessibility.isReduceMotionEnabled)
    }

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
        expansionAnimation?.invalidate()
        expansionAnimation = nil
    }

    private func layoutSecondaryViewport() {
        updateSecondary { contentView.layoutSecondaryViewport(visibleSharedHeight: visibleSharedHeight) }
    }

    private func layoutSharedContent() {
        contentView.layoutSharedContent(visibleHeaderHeight: visibleHeaderHeight,
                                        visibleSharedHeight: visibleSharedHeight, contentHeight: sharedContentHeight)
    }

    private func initializeSecondaryIfNeeded() {
        guard !hasInitializedSecondary else { return }
        hasInitializedSecondary = true
        // 延迟到初始化完成后的首次布局 / 同步，避免 init 内修改 offset 导致业务 delegate 重入构造。
        updateSecondary {
            secondary.contentInsetAdjustmentBehavior = .never
            secondary.scrollsToTop = false
            secondary.contentInset.top = initialSharedHeight
            secondary.contentOffset.y = -initialSharedHeight
        }
    }

    private func updateSecondaryInsets() {
        updateSecondary {
            // 主列表独立内容未回顶时，副列表不能强行拉回主列表。
            // 位置保留开启后，头部未吸顶也可能处于这种状态。
            let top = primaryContentDepth <= 0.5 ? initialSharedHeight : visibleSharedHeight
            let bottom = max(contentView.safeAreaInsets.bottom,
                             contentView.bounds.height - secondary.contentSize.height - pinnedHeaderHeight)
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
        let wasUpdating = isUpdatingSecondary
        isUpdatingSecondary = true
        defer {
            isUpdatingSecondary = wasUpdating
            secondaryOffset = secondary.contentOffset.y
        }
        changes()
    }

    private func stopSecondaryMotion() {
        // 除手势减速外，也要终止分类居中的程序化动画。
        stopScrolling(secondary)
        secondaryOffset = secondary.contentOffset.y
    }

    private func stopScrolling(_ scrollView: UIScrollView) {
        if #available(iOS 17.4, *) { scrollView.stopScrollingAndZooming() }
        else { scrollView.setContentOffset(scrollView.contentOffset, animated: false) }
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

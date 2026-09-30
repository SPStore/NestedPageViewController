import UIKit

/// 将右侧主列表、左侧副列表和可选的共享内容组合成双列页面。
///
/// 本类只负责视图层级和裁剪，不处理滚动联动，也不接管列表的数据源或 delegate。
/// `NestedPageDualScrollCoordinator` 会根据当前头部和共享内容的可见高度，调用本类更新几何。
///
/// 主列表始终保持全宽，以便共享轮播图可以占满整行；普通主列内容需通过 layout
/// 自行留出左侧宽度。副列表则放在左侧裁剪容器中，只露出它应显示的部分。
final class NestedPageDualScrollView: UIView {
    /// 右侧主列表；同时作为子页的 `nestedPageContentScrollView` 驱动核心头部。
    let primaryScrollView: UIScrollView
    /// 左侧副列表；滚动位置独立，但在共享区收起阶段会与主列表联动。
    let secondaryScrollView: UIScrollView
    /// 副列表的可见窗口；通过 `clipsToBounds` 隐藏头部和共享内容下方之外的部分。
    let secondaryContainerView = UIView()
    /// 副列表可见窗口的宽度。
    let secondaryWidth: CGFloat
    /// Tab 下方、两列上方的可选共享内容；点餐页中对应共享轮播图。
    let sharedContentView: UIView?
    /// 共享内容的裁剪容器，共享区逐渐收起时只显示剩余高度。
    private let sharedContentContainer = UIView()

    init(primaryScrollView: UIScrollView, secondaryScrollView: UIScrollView, secondaryWidth: CGFloat,
         sharedContentView: UIView? = nil) {
        precondition(primaryScrollView !== secondaryScrollView)
        precondition(secondaryWidth >= 0)
        self.primaryScrollView = primaryScrollView
        self.secondaryScrollView = secondaryScrollView
        self.secondaryWidth = secondaryWidth
        self.sharedContentView = sharedContentView
        super.init(frame: .zero)
        addSubview(primaryScrollView)
        secondaryContainerView.clipsToBounds = true
        addSubview(secondaryContainerView)
        secondaryContainerView.addSubview(secondaryScrollView)
        if let sharedContentView {
            // 仍挂在主列表内部，纵向拖拽继续由主列表原生 pan 承接。
            sharedContentContainer.clipsToBounds = true
            sharedContentContainer.backgroundColor = .systemBackground
            primaryScrollView.addSubview(sharedContentContainer)
            sharedContentContainer.addSubview(sharedContentView)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 布局 Tab 下方的共享内容，并根据剩余可见高度从顶部裁剪。
    /// - Parameters:
    ///   - visibleHeaderHeight: 当前可见的组件头部高度。
    ///   - visibleSharedHeight: 两列顶部当前需要避让的总高度。
    ///   - contentHeight: 共享内容完全展开时的高度。
    func layoutSharedContent(visibleHeaderHeight: CGFloat, visibleSharedHeight: CGFloat, contentHeight: CGFloat) {
        guard let sharedContentView else { return }
        let remaining = max(0, visibleSharedHeight - visibleHeaderHeight)
        sharedContentContainer.frame = CGRect(x: 0, y: primaryScrollView.contentOffset.y + visibleHeaderHeight,
                                              width: bounds.width, height: remaining)
        sharedContentContainer.isHidden = remaining <= 0.001
        sharedContentView.frame = CGRect(x: 0, y: remaining - contentHeight, width: bounds.width, height: contentHeight)
        primaryScrollView.bringSubviewToFront(sharedContentContainer)
    }

    /// 调整副列表的可见窗口，使其始终从当前共享区底部开始显示。
    /// 副列表本身仍保持全屏高度，从而保留 UIKit 原生的拖拽、减速和回弹行为。
    func layoutSecondaryViewport(visibleSharedHeight: CGFloat) {
        let width = min(secondaryWidth, bounds.width)
        secondaryContainerView.frame = CGRect(x: 0, y: visibleSharedHeight, width: width,
                                              height: max(0, bounds.height - visibleSharedHeight))
        // 容器与列表反向补偿：列表在根视图中的原点始终为 0，高度也不随头部折叠变化。
        // 保留 UIKit 原生拖拽和减速的几何，只改变可见区域。
        secondaryScrollView.frame = CGRect(x: 0, y: -visibleSharedHeight, width: width, height: bounds.height)
    }
}

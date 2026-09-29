import UIKit

/// Demo 业务组件：主列表保持全宽，副列表覆盖在其左侧的独立裁剪容器中。
/// 主列表的普通内容需要自行给副列表留出宽度；共享内容可以继续占满整行。
/// 由协调器在页面布局和共享高度变化时更新几何，不接管列表的数据源或 delegate。
final class NestedPageDualScrollView: UIView {
    let primaryScrollView: UIScrollView
    let secondaryScrollView: UIScrollView
    let secondaryContainerView = UIView()
    let secondaryWidth: CGFloat
    let sharedContentView: UIView?
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

    func layoutSharedContent(visibleHeaderHeight: CGFloat, visibleSharedHeight: CGFloat, contentHeight: CGFloat) {
        guard let sharedContentView else { return }
        let remaining = max(0, visibleSharedHeight - visibleHeaderHeight)
        sharedContentContainer.frame = CGRect(x: 0, y: primaryScrollView.contentOffset.y + visibleHeaderHeight,
                                              width: bounds.width, height: remaining)
        sharedContentContainer.isHidden = remaining <= 0.001
        sharedContentView.frame = CGRect(x: 0, y: remaining - contentHeight, width: bounds.width, height: contentHeight)
        primaryScrollView.bringSubviewToFront(sharedContentContainer)
    }

    func layoutSecondaryViewport(visibleSharedHeight: CGFloat) {
        let width = min(secondaryWidth, bounds.width)
        secondaryContainerView.frame = CGRect(x: 0, y: visibleSharedHeight, width: width,
                                              height: max(0, bounds.height - visibleSharedHeight))
        // 容器与列表反向补偿：列表在根视图中的原点始终为 0，高度也不随头部折叠变化。
        // 保留 UIKit 原生拖拽和减速的几何，只改变可见区域。
        secondaryScrollView.frame = CGRect(x: 0, y: -visibleSharedHeight, width: width, height: bounds.height)
    }
}

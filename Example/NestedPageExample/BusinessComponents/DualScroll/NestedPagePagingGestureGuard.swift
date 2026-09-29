import UIKit

/// 不处理位移，只排除指定的横向分页；与内部横拖、主列表纵拖及系统返回手势并行。
/// 不能只等待内部 scrollView 的 pan：它可能因纵向 / 斜向起手失败，让外层分页接手。
final class NestedPagePagingGestureGuard: UIPanGestureRecognizer {
    weak var pagingPan: UIPanGestureRecognizer?

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        preventedGestureRecognizer === pagingPan
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }
}

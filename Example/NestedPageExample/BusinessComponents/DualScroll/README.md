# 双列表滚动业务组件

这是 Demo 内的业务组件，不属于发布的 `NestedPageViewController` 基础库；依赖方向仅为业务组件 → 核心公开 API。核心提供 `expandHeader()` 和可控的 `setHeaderExpansionProgress(_:)`（只调整头部并保留阅读位置），不包含双列表或轮播逻辑。`Package.swift` 与 podspec 不引入业务组件。

## 职责

- `NestedPageDualScrollCoordinator`：共享位移分配、副列表 inset 与阅读位置同步、短内容补足、运动停止和横向手势优先级。
- `NestedPageDualScrollView`：主列表全宽，副列表位于左侧裁剪容器；维持副列表原点和高度，保留原生拖动 / 减速。
- `NestedPagePagingGestureGuard`：内部辅助，只排除外层横向分页，不驱动 offset。

不负责商品、分类、数据源、Cell、分组标题吸顶、选中高亮，也不接管 `UIScrollViewDelegate` 或 `NestedPageViewControllerDelegate`。

## 接入

以下对应 `FoodMenuViewController` 中的实际接法。先创建两个列表，并在加载子页前注入 `pager`；页面强持有容器和协调器。

```swift
private lazy var dualScrollView = NestedPageDualScrollView(
    primaryScrollView: products,
    secondaryScrollView: categoryTableView,
    secondaryWidth: 92,
    sharedContentView: sharedCarousel // 可选；需要展开共享区且保留阅读位置时提供
)

private lazy var dualCoordinator = NestedPageDualScrollCoordinator(
    pageViewController: pager,
    contentView: dualScrollView,
    expandedHeaderHeight: headerHeight, // 与 pager.headerHeight 一致：店铺封面 + Tab
    pinnedHeaderHeight: (pager?.stickyOffset ?? 0) + 44, // 系统导航栏底边 + Tab
    sharedContentHeight: 144  // 主列表内容开头仍保留等高占位；没有时传 0
)

var nestedPageContentScrollView: UIScrollView { products }

override func loadView() {
    view = dualScrollView
}
```

1. 在 `viewDidLoad` 配置两个列表的 delegate、数据源、样式和回弹选项后，调用 `dualCoordinator.layoutContent()`；再注册本页的横向内容：

   ```swift
   dualCoordinator.prioritizeHorizontalScrolling(in: [sharedCarousel, productCarousel])
   ```

   注册接受普通 `UIScrollView` / `UICollectionView`，同一实例重复注册不会增加手势。它保证内部起拖时外层不横向翻页，但内部横纵方向识别仍由各滚动视图负责；`FoodCarouselView` 保留了自己的方向判断。不要让主列表的纵向 pan 等待轮播 pan 失败。

2. 在 `viewDidLayoutSubviews` 调用 `dualCoordinator.layoutContent()`。如果导航栏高度或安全区变化，先用 `updatePinnedHeaderHeight(pager.stickyOffset + 44)` 同步新的吸顶底边。副列表内容量变化后也需要重新布局，以更新短内容 bottom inset。主列表的商品行等应自行给左侧副列表留出空间；只有公共区域占满整行。

3. 在页面原有的两个滚动代理回调中转发，业务自身的逻辑继续保留：

   ```swift
   func scrollViewDidScroll(_ scrollView: UIScrollView) {
       dualCoordinator.scrollViewDidScroll(scrollView)
       // 业务仍自行更新选中项等。
   }

   func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
       dualCoordinator.scrollViewWillBeginDragging(scrollView)
   }
   ```

4. 由外层页面测量 Tab 在 `dualScrollView` 坐标系中的实际底边，再调用：

   ```swift
   dualCoordinator.updateVisibleHeaderHeight(tabBottom)
   ```

   主列表滚动、分页切换完成、`updateLayouts()` 及页面布局后均要更新。`FoodOrderingViewController.synchronizeHeader()` 展示了这个桥接入口；不能只传 `isSticked`，也不能通过主列表 offset 猜测头部是否展开。

5. 在切页完成或程序化跳转前调用 `stopMotion()`。它停止两列和已注册横向内容；协调器还会观察外层横向 offset，在切页开始时停止副列表惯性。

其他接口：

- `resetSecondaryPosition()`：仅将副列表移到当前可见区域顶部，不重置主列表。
- `expandSharedHeader(animated:onUpdate:)`：展开核心头部和共享内容，保留两列相对可见区域顶部的阅读位置，不受 `keepsContentScrollPosition` 影响。`animated` 默认 false；传 true 时用 0.32 秒 ease-out 动画同步展开。`onUpdate` 在每帧两列补偿完成后调用，业务可在此更新分组布局或高亮。共享内容高度大于 0 时必须提供 `sharedContentView`。本方法只操作当前双列表页，不负责切页。
- `prepareForPrimaryContentSelection()`：业务主动跳到某个分组前调用，先收起显式展开的共享区，再由业务滚到目标位置。
- `revealSecondaryRect(_:)`：接收副列表内容坐标中的 rect；显示业务选中的项，但拖动 / 减速期间不会抢用户的位置。
- `visibleHeaderHeight`：当前头部实际底边，可用于业务分组标题吸顶。
- `visibleSharedHeight`：头部底边加剩余共享内容高度，即副列表裁剪起点。

## 边界和生命周期

- 所有方法在主线程调用，一组视图配一个协调器；协调器寿命与子页一致。销毁时撤销分页观察并移除附加手势，不清空业务 delegate。
- 主列表是子页唯一注册给核心的 scrollView。副列表通过主列表驱动共享头部，不另外实现核心的吸顶逻辑，也不要求位于第 0 个 Tab。
- 主列表内容从 y = 0 开始的 `sharedContentHeight` 属于共享区域；右侧独立轮播 / 独立标题不计入此高度。传入 `sharedContentView` 时这段内容只保留等高占位，真实视图由容器展示，不能同时挂在复用 cell 上。
- 共享视图仍挂在主列表内，因此纵拖使用主列表原生 pan；独立裁剪层控制可见高度。显式展开时补偿两列 offset，再次上滑先收共享区；下滑先消费独立阅读位置，不能在保存的位置提前展开轮播。
- 展开动画使用单一 `CADisplayLink` 更新实际几何，按原阅读锚点计算每帧绝对 offset，并将中间高度对齐屏幕像素，避免累计舍入漂移。用户拖动、切页、`stopMotion()`、尺寸变化或离屏时中断在当前位置；页面释放时销毁时钟，不保留动画引用环。启用系统「减弱动态效果」或视图未显示时立即展开。
- 动画中的核心回调仍可能落在两列补偿之间；业务计算分类前应检查 `isUpdatingSharedHeader`，在 `onUpdate` 中再统一更新。外层页面离屏前应调用 `stopMotion()`。
- 副列表的 inset / offset / frame 由协调器管理；主列表的 inset 由核心及页面业务管理。不能同时再用其他联动代码修改副列表几何。
- 当前提炼范围是固定展开头部尺寸、固定左栏宽度、主列表全宽的双列表场景；吸顶边界支持随导航栏布局更新。动态修改展开头部 / 公共区域高度、右侧副列表、任意多列表和固定不折叠头部不在此版本的接入约定内。
- 保留主列表位置时，允许头部展开但主列表独立内容仍在深处。此时副列表只回到当前可见区域顶部，不强行拖回主列表。关闭回弹不会关闭正常的共享区域展开 / 收起。

## 验证

`FoodOrderingDemo` scheme 包含原有外卖页面单元测试和真实模拟器手势测试；`NestedPageDualScrollCoordinatorTests` 额外使用普通滚动视图验证非第 0 页、自定义几何、程序化偏移、内容高度变化、选中项可见性、delegate 所有权、重复手势注册和释放清理。

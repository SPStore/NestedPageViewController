import UIKit
import NestedPageViewController
import JXCategoryView

/// 双列表实验：共享店铺头部 / 全宽轮播，右侧另有独立轮播，分类保留原生拖拽和减速。
/// 进入页面时读取设置页的位置保留开关，其他配置保持固定，避免改变双列表的实验条件。
final class FoodOrderingViewController: UIViewController, NestedPageViewControllerDataSource, NestedPageViewControllerDelegate {
    private let pager = NestedPageViewController()
    private let cover = FoodShopCoverView()
    private let tabStrip = FoodOrderingTabStrip()
    private let menu = FoodMenuViewController()
    private let cartLabel = UILabel()
    private let cart = UIView()
    private var lastPagerSize = CGSize.zero
    private var itemCount = 0
    private var returnsToTopAfterTabClick = false

    deinit {
        tabStrip.contentScrollView = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "外卖点餐双列表"
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "重置", style: .plain, target: self, action: #selector(reset)),
            UIBarButtonItem(title: "短分类", style: .plain, target: self, action: #selector(toggleCategories))
        ]

        tabStrip.delegate = self

        pager.dataSource = self
        pager.delegate = self
        pager.headerBounces = false
        pager.keepsContentScrollPosition = NestedPageConfig.shared.keepsContentScrollPosition
        menu.pager = pager
        menu.onAdd = { [weak self] in
            guard let self else { return }
            self.itemCount += 1
            self.updateCart()
        }
        addChild(pager)
        view.addSubview(pager.view)
        pager.didMove(toParent: self)
        tabStrip.contentScrollView = pager.containerScrollView
        view.addSubview(cart)
        cart.backgroundColor = .secondarySystemBackground
        cartLabel.font = .systemFont(ofSize: 15, weight: .medium)
        cartLabel.accessibilityIdentifier = "food.cart"
        cart.addSubview(cartLabel)
        updateCart()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabStrip.contentScrollView = pager.containerScrollView
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // 第三方强持有分页容器，而 Tab 挂在其子树内；离屏时主动拆开引用环和 KVO。
        // 再次显示（包括取消返回手势）时重新绑定，不丢失当前选中页。
        tabStrip.contentScrollView = nil
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        menu.stopMotion()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let top = view.safeAreaInsets.top
        let bottom = view.bounds.height - view.safeAreaInsets.bottom - 58
        cart.frame = CGRect(x: 0, y: bottom, width: view.bounds.width, height: view.bounds.height - bottom)
        cartLabel.frame = CGRect(x: 20, y: 0, width: view.bounds.width - 40, height: 58)
        pager.view.frame = CGRect(x: 0, y: top, width: view.bounds.width, height: max(0, bottom - top))
        if lastPagerSize != pager.view.bounds.size {
            lastPagerSize = pager.view.bounds.size
            if pager.viewController(at: 0) != nil { pager.updateLayouts() }
        }
        synchronizeHeader()
    }

    private func updateCart() {
        cartLabel.text = itemCount == 0 ? "购物车空空的　·　商品可点击 + 加入" : "已选 \(itemCount) 件商品　·　本地交互示例"
    }

    @objc private func reset() {
        menu.stopMotion()
        pager.scrollToPage(at: 0, animated: false)
        pager.updateLayouts()
        // updateLayouts 期间组件暂停滚动回调；先刷新共享区域与 inset，再按新边界重置分类。
        synchronizeHeader()
        menu.resetCategoryPosition()
    }

    @objc private func toggleCategories() {
        menu.usesShortCategories.toggle()
        navigationItem.rightBarButtonItems?.last?.title = menu.usesShortCategories ? "长分类" : "短分类"
        reset()
    }

    private func synchronizeHeader() {
        guard menu.isViewLoaded, tabStrip.superview != nil else { return }
        // 使用实际坐标，不依赖 isSticked 的历史回报语义；切页和回弹也走相同入口。
        let bottom = tabStrip.convert(tabStrip.bounds, to: menu.view).maxY
        menu.updateSharedHeader(visibleHeight: bottom)
        tabStrip.showsBackToTop = bottom <= FoodMenuViewController.tabHeight + 0.5
    }

    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int { 3 }
    func pageViewController(_ pageViewController: NestedPageViewController, viewControllerAt index: Int) -> NestedPageScrollable? {
        index == 0 ? menu : FoodInfoViewController(isReviews: index == 1)
    }
    func coverView(in pageViewController: NestedPageViewController) -> UIView? { cover }
    func heightForCoverView(in pageViewController: NestedPageViewController) -> CGFloat { FoodMenuViewController.coverHeight }
    func tabStrip(in pageViewController: NestedPageViewController) -> UIView? { tabStrip }
    func heightForTabStrip(in pageViewController: NestedPageViewController) -> CGFloat { FoodMenuViewController.tabHeight }
    func pageViewController(_ pageViewController: NestedPageViewController, contentScrollViewDidScroll scrollView: UIScrollView, headerOffset: CGFloat, isSticked: Bool) {
        synchronizeHeader()
    }
    func pageViewController(_ pageViewController: NestedPageViewController, didScrollToPageAt index: Int) {
        menu.stopMotion()
        synchronizeHeader()
    }
}

extension FoodOrderingViewController: JXCategoryViewDelegate {
    func categoryView(_ categoryView: JXCategoryBaseView!, canClickItemAt index: Int) -> Bool {
        // 保存点击前的吸顶状态：第三方切页后，核心可能已调整共享头部位置。
        returnsToTopAfterTabClick = index == 0 && tabStrip.showsBackToTop
        return true
    }

    func categoryView(_ categoryView: JXCategoryBaseView!, didClickSelectedItemAt index: Int) {
        let shouldReturnToTop = returnsToTopAfterTabClick
        returnsToTopAfterTabClick = false
        guard index == 0, shouldReturnToTop else { return }
        // JX 已切到点餐页；只展开共享区域，不重置左右列表的阅读位置。
        menu.expandSharedHeader(animated: true)
    }
}

private final class FoodInfoViewController: UIViewController, NestedPageScrollable, UITableViewDataSource {
    private let table = UITableView(frame: .zero, style: .plain)
    private let isReviews: Bool
    var nestedPageContentScrollView: UIScrollView { table }
    init(isReviews: Bool) {
        self.isReviews = isReviews
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        table.dataSource = self
        table.rowHeight = 76
        table.frame = view.bounds
        table.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        table.accessibilityIdentifier = isReviews ? "food.reviews" : "food.merchant"
        view.addSubview(table)
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { isReviews ? 24 : 4 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.textLabel?.text = isReviews ? "顾客 \(indexPath.row + 1)　★★★★★" : ["营业时间", "商家地址", "配送说明", "食材承诺"][indexPath.row]
        cell.detailTextLabel?.text = isReviews ? "饭菜很香，包装整洁，下次还来。" : ["每日 10:00—21:30", "幸福路 18 号", "下单后现做，尽快送达", "每日采购新鲜食材"][indexPath.row]
        return cell
    }
}

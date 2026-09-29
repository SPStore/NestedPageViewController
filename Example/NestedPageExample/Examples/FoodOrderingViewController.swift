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
    private let navigationBackground = UIView()
    private lazy var navigationBackgroundHeight = navigationBackground.heightAnchor.constraint(equalToConstant: 0)
    private var lastPagerSize = CGSize.zero
    private var lastCoverHeight: CGFloat = 0
    private var itemCount = 0
    private var returnsToTopAfterTabClick = false

    deinit {
        tabStrip.contentScrollView = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = nil
        navigationItem.title = ""
        navigationItem.largeTitleDisplayMode = .never
        extendedLayoutIncludesOpaqueBars = true
        setupNavigationBar()
        cover.onFulfillmentModeChanged = { [weak self] in
            guard let self else { return }
            self.lastCoverHeight = self.heightForCoverView(in: self.pager)
            self.updatePagerLayouts()
            if !self.pager.keepsContentScrollPosition { self.menu.resetCategoryPosition() }
        }
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "重置", style: .plain, target: self, action: #selector(reset)),
            UIBarButtonItem(title: "短分类", style: .plain, target: self, action: #selector(toggleCategories))
        ]

        tabStrip.delegate = self

        pager.dataSource = self
        pager.delegate = self
        pager.headerBounces = false
        pager.stickyOffset = view.safeAreaInsets.top
        if #available(iOS 26.0, *) {
            pager.containerScrollView.topEdgeEffect.isHidden = true
        }
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
        cart.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.19, green: 0.15, blue: 0.10, alpha: 1)
                : UIColor(red: 1, green: 0.96, blue: 0.89, alpha: 1)
        }
        cartLabel.font = .systemFont(ofSize: 15, weight: .medium)
        cartLabel.accessibilityIdentifier = "food.cart"
        cart.addSubview(cartLabel)
        // 在分页内容之上、系统导航栏之下覆盖完整顶部，不依赖系统栏的背景形状。
        navigationBackground.backgroundColor = .systemBackground
        navigationBackground.alpha = 0
        navigationBackground.isUserInteractionEnabled = false
        navigationBackground.accessibilityIdentifier = "food.navigationBackground"
        view.addSubview(navigationBackground)
        pager.view.translatesAutoresizingMaskIntoConstraints = false
        cart.translatesAutoresizingMaskIntoConstraints = false
        cartLabel.translatesAutoresizingMaskIntoConstraints = false
        navigationBackground.translatesAutoresizingMaskIntoConstraints = false
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            // 封面延伸到屏幕顶部，列表左右和购物车文字仍遵守安全区。
            pager.view.topAnchor.constraint(equalTo: view.topAnchor),
            pager.view.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            pager.view.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            pager.view.bottomAnchor.constraint(equalTo: cart.topAnchor),
            // 背景铺满底部和两侧安全区，58 点内容区仍位于底部安全区之上。
            cart.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cart.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cart.topAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -58),
            cart.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cartLabel.topAnchor.constraint(equalTo: cart.safeAreaLayoutGuide.topAnchor),
            cartLabel.leadingAnchor.constraint(equalTo: cart.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            cartLabel.trailingAnchor.constraint(equalTo: cart.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            cartLabel.bottomAnchor.constraint(equalTo: cart.safeAreaLayoutGuide.bottomAnchor),
            // 背景必须覆盖屏幕顶边和两侧，不能约束到 safeArea，否则外屏仍会露出封面。
            navigationBackground.topAnchor.constraint(equalTo: view.topAnchor),
            navigationBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationBackgroundHeight
        ])
        updateCart()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        tabStrip.contentScrollView = pager.containerScrollView
        synchronizeHeader()
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
        // NavigationController 是共享的，离开点餐页时恢复其他示例的全局颜色。
        navigationController?.navigationBar.tintColor = .label
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let navigationBottom: CGFloat
        if let navigationBar = navigationController?.navigationBar {
            navigationBottom = max(0, navigationBar.convert(navigationBar.bounds, to: pager.view).maxY)
        } else {
            navigationBottom = view.safeAreaInsets.top
        }
        cover.topContentInset = navigationBottom
        navigationBackgroundHeight.constant = navigationBottom
        let coverHeight = heightForCoverView(in: pager)
        if lastPagerSize != pager.view.bounds.size || pager.stickyOffset != navigationBottom || lastCoverHeight != coverHeight {
            lastPagerSize = pager.view.bounds.size
            lastCoverHeight = coverHeight
            pager.stickyOffset = navigationBottom
            if pager.viewController(at: 0) != nil { updatePagerLayouts() }
        }
        synchronizeHeader()
    }

    private func setupNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        // 系统栏始终透明，只由页面背景层驱动渐变，避免两层半透明颜色叠加。
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        navigationItem.compactScrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .white
    }

    private func updateCart() {
        cartLabel.text = itemCount == 0 ? "购物车空空的　·　商品可点击 + 加入" : "已选 \(itemCount) 件商品　·　本地交互示例"
    }

    private func updatePagerLayouts() {
        menu.performHeaderLayoutUpdate { pager.updateLayouts() }
        // 核心布局期间暂停了滚动回调，完成后同步轮播、左栏与导航栏。
        synchronizeHeader()
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
        let pinnedHeight = pager.stickyOffset + FoodMenuViewController.tabHeight
        tabStrip.showsBackToTop = bottom <= pinnedHeight + 0.5
        let collapseDistance = max(1, pager.headerHeight - FoodMenuViewController.tabHeight - pager.stickyOffset)
        let progress = min(max((pager.headerHeight - bottom) / collapseDistance, 0), 1)
        navigationBackground.alpha = progress
        // 深色封面展开时为白色，随封面收起连续过渡为黑色。
        navigationController?.navigationBar.tintColor = UIColor(white: 1 - progress, alpha: 1)
    }

    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int { 3 }
    func pageViewController(_ pageViewController: NestedPageViewController, viewControllerAt index: Int) -> NestedPageScrollable? {
        index == 0 ? menu : FoodInfoViewController(isReviews: index == 1)
    }
    func coverView(in pageViewController: NestedPageViewController) -> UIView? { cover }
    func heightForCoverView(in pageViewController: NestedPageViewController) -> CGFloat {
        cover.preferredHeight(for: pageViewController.view.bounds.width)
    }
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
        table.translatesAutoresizingMaskIntoConstraints = false
        table.accessibilityIdentifier = isReviews ? "food.reviews" : "food.merchant"
        if #available(iOS 26.0, *) {
            table.topEdgeEffect.isHidden = true
        }
        view.addSubview(table)
        NSLayoutConstraint.activate([
            // 共享封面挂在当前子列表上，不能再为导航栏预留一遍顶部安全区。
            table.topAnchor.constraint(equalTo: view.topAnchor),
            table.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
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

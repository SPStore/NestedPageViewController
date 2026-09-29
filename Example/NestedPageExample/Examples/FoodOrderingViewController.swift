import UIKit
import NestedPageViewController

/// 双列表实验：商品列表承接公共头部，分类列表保留自己的原生拖拽和减速。
/// 本示例使用固定配置，避免设置页中的 headerAlwaysFixed 等选项改变实验条件。
final class FoodOrderingViewController: UIViewController, NestedPageViewControllerDataSource, NestedPageViewControllerDelegate {
    private let pager = NestedPageViewController()
    private let cover = UIView()
    private let tabStrip = NestedPageTabStripView(titles: ["点餐", "评价", "商家"])
    private let menu = FoodMenuViewController()
    private let cartLabel = UILabel()
    private let cart = UIView()
    private var lastPagerSize = CGSize.zero
    private var itemCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "外卖点餐双列表"
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "重置", style: .plain, target: self, action: #selector(reset)),
            UIBarButtonItem(title: "短分类", style: .plain, target: self, action: #selector(toggleCategories))
        ]

        let name = UILabel()
        name.text = "巷口小馆 · 现做家常菜"
        name.font = .boldSystemFont(ofSize: 23)
        name.accessibilityIdentifier = "food.shop"
        let details = UILabel()
        details.text = "4.9 分  ·  约 30 分钟  ·  配送费 ¥2\n\n热饭热菜，认真做好每一餐"
        details.numberOfLines = 0
        details.font = .systemFont(ofSize: 14)
        details.textColor = .secondaryLabel
        let tip = UILabel()
        tip.text = "左右两栏都可上滑收起店铺信息"
        tip.font = .systemFont(ofSize: 13)
        let stack = UIStackView(arrangedSubviews: [name, details, tip])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        cover.backgroundColor = .secondarySystemBackground
        cover.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cover.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: cover.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: cover.centerYAnchor)
        ])
        var configuration = tabStrip.configuration
        configuration.titleColor = .secondaryLabel
        configuration.titleSelectedColor = .label
        configuration.backgroundColor = .systemBackground
        configuration.indicatorColor = .systemOrange
        tabStrip.configuration = configuration

        pager.dataSource = self
        pager.delegate = self
        pager.headerBounces = false
        pager.keepsContentScrollPosition = false
        menu.pager = pager
        menu.onAdd = { [weak self] in
            guard let self else { return }
            self.itemCount += 1
            self.updateCart()
        }
        addChild(pager)
        view.addSubview(pager.view)
        pager.didMove(toParent: self)
        tabStrip.linkedScrollView = pager.containerScrollView
        view.addSubview(cart)
        cart.backgroundColor = .secondarySystemBackground
        cartLabel.font = .systemFont(ofSize: 15, weight: .medium)
        cartLabel.accessibilityIdentifier = "food.cart"
        cart.addSubview(cartLabel)
        updateCart()
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
        menu.resetCategoryPosition()
        synchronizeHeader()
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

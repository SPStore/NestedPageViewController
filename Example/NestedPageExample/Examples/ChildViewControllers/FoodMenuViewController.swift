import UIKit
import NestedPageViewController

final class FoodMenuViewController: UIViewController, NestedPageScrollable {
    static let tabHeight: CGFloat = 48
    static let sharedCarouselHeight: CGFloat = 144
    static let productCarouselHeight: CGFloat = 120
    private let categoryWidth: CGFloat = 92
    private let showsCarousels: Bool
    private var carouselHeight: CGFloat { showsCarousels ? Self.sharedCarouselHeight : 0 }
    private var leadingSectionCount: Int { showsCarousels ? 2 : 0 }
    private var headerHeight: CGFloat { pager?.headerHeight ?? Self.tabHeight }
    private var pinnedHeaderHeight: CGFloat { Self.tabHeight + (pager?.stickyOffset ?? 0) }
    private var selectedCategory = 0
    private var categoryScrollTarget: Int?
    private var lastLayoutSize = CGSize.zero
    private var isUpdatingHeaderLayout = false

    weak var pager: NestedPageViewController?
    var onAdd: (() -> Void)?
    var usesShortCategories = false {
        didSet {
            guard isViewLoaded else { return }
            stopMotion()
            selectedCategory = 0
            products.reloadData()
            categoryTableView.reloadData()
            view.setNeedsLayout()
        }
    }
    private let allCategories = ["招牌热销", "超值套餐", "下饭小炒", "鲜香炖菜", "时令蔬菜", "经典盖饭", "面食米粉", "暖心汤品", "香酥小食", "清爽凉菜", "精品主食", "现制饮品", "甜品水果", "儿童餐", "双人分享", "加料专区"]
    private var names: [String] { usesShortCategories ? Array(allCategories.prefix(4)) : allCategories }
    private let categoryTableView: UITableView
    private let sharedCarousel = FoodCarouselView(style: .shared)
    private let productCarousel = FoodCarouselView(style: .products)
    private let productLayout = FoodProductLayout()
    private lazy var products = UICollectionView(frame: .zero, collectionViewLayout: productLayout)
    private lazy var dualScrollView = NestedPageDualScrollView(
        primaryScrollView: products, secondaryScrollView: categoryTableView, secondaryWidth: categoryWidth,
        sharedContentView: showsCarousels ? sharedCarousel : nil
    )
    private lazy var dualCoordinator = NestedPageDualScrollCoordinator(
        pageViewController: pager, contentView: dualScrollView,
        expandedHeaderHeight: headerHeight, pinnedHeaderHeight: pinnedHeaderHeight, sharedContentHeight: carouselHeight,
        allowsSecondaryTopBounce: false
    )
    var nestedPageContentScrollView: UIScrollView { products }

    init(categoryTable: UITableView = UITableView(frame: .zero, style: .plain), showsCarousels: Bool = true) {
        categoryTableView = categoryTable
        self.showsCarousels = showsCarousels
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        view = dualScrollView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        products.backgroundColor = .systemBackground
        products.dataSource = self
        products.delegate = self
        products.alwaysBounceVertical = false
        products.accessibilityIdentifier = "food.products"
        products.register(FoodProductCell.self, forCellWithReuseIdentifier: "product")
        products.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "carousel")
        products.register(FoodSectionHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "section")
        productLayout.minimumLineSpacing = 0
        productLayout.minimumInteritemSpacing = 0
        productLayout.sectionInset = UIEdgeInsets(top: 0, left: categoryWidth + 12, bottom: 12, right: 12)
        productLayout.categoryWidth = categoryWidth
        productLayout.leadingSectionCount = leadingSectionCount
        dualScrollView.secondaryContainerView.backgroundColor = .secondarySystemBackground
        categoryTableView.backgroundColor = .secondarySystemBackground
        categoryTableView.dataSource = self
        categoryTableView.delegate = self
        categoryTableView.rowHeight = 60
        categoryTableView.estimatedRowHeight = 0
        categoryTableView.separatorStyle = .none
        categoryTableView.showsVerticalScrollIndicator = false
        categoryTableView.bounces = false
        categoryTableView.alwaysBounceVertical = false
        categoryTableView.accessibilityIdentifier = "food.categories"
        if #available(iOS 26.0, *) {
            products.topEdgeEffect.isHidden = true
            categoryTableView.topEdgeEffect.isHidden = true
        }
        dualCoordinator.layoutContent()
        // 首次商品布局尚未生成分组标题时，也要保证左栏有明确的初始选中项。
        selectCategory(at: 0)
        if showsCarousels {
            dualCoordinator.prioritizeHorizontalScrolling(in: [sharedCarousel, productCarousel])
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 组件加载子页时会统一设置商品列表的 bounces，因此在其后的布局阶段关闭回弹。
        products.bounces = false
        guard !isUpdatingHeaderLayout else { return }
        let changed = lastLayoutSize != view.bounds.size
        lastLayoutSize = view.bounds.size
        if changed {
            productLayout.itemSize = CGSize(width: max(1, view.bounds.width - categoryWidth - 24), height: 104)
            productLayout.headerReferenceSize = CGSize(width: view.bounds.width, height: 36)
        }
        dualCoordinator.updateHeaderHeights(expanded: headerHeight, pinned: pinnedHeaderHeight)
        dualCoordinator.layoutContent()
        // 最后一个商品分组不足一屏时才补足空间，保证点击分类也能把标题滚到 tab 下方。
        let lastHeight = CGFloat(productCount(in: names.count - 1)) * 104 + 36 + 12
        let bottom = max(view.safeAreaInsets.bottom, view.bounds.height - pinnedHeaderHeight - lastHeight)
        if products.contentInset.top == headerHeight {
            pager?.setContentBottomInset(bottom, for: products)
        }
        updateSelectedCategory()
    }

    func updateSharedHeader(visibleHeight: CGFloat) {
        guard isViewLoaded, !isUpdatingHeaderLayout else { return }
        dualCoordinator.updateHeaderHeights(expanded: headerHeight, pinned: pinnedHeaderHeight)
        dualCoordinator.updateVisibleHeaderHeight(visibleHeight)
        // 跟随 Tab 的实际吸顶状态，切页、展开动画和布局更新也统一同步。
        // 非吸顶关闭全部回弹；吸顶开启后，由协调器限制顶部，仅保留底部回弹。
        let isPinned = dualCoordinator.visibleHeaderHeight <= pinnedHeaderHeight + 0.5
        categoryTableView.bounces = isPinned
        categoryTableView.alwaysBounceVertical = isPinned
        productLayout.visibleContentTop = dualCoordinator.visibleSharedHeight
        productLayout.invalidateLayout()
        updateSelectedCategory()
    }

    /// 核心会先更新 inset、临时回顶，再恢复阅读位置；业务层等这一过程结束后再同步。
    func performHeaderLayoutUpdate(_ update: () -> Void) {
        stopMotion()
        isUpdatingHeaderLayout = true
        defer {
            isUpdatingHeaderLayout = false
            if isViewLoaded { view.setNeedsLayout() }
        }
        update()
    }

    func resetCategoryPosition() {
        dualCoordinator.resetSecondaryPosition()
        selectedCategory = 0
        selectCategory(at: 0)
    }

    func expandSharedHeader(animated: Bool = false) {
        categoryScrollTarget = nil
        // 每一帧都先完成两列补偿，再计算分类，避免中间状态抢走左栏位置。
        dualCoordinator.expandSharedHeader(animated: animated) { [weak self] in
            guard let self else { return }
            self.updateSharedHeader(visibleHeight: self.dualCoordinator.visibleHeaderHeight)
        }
    }

    func stopMotion() {
        guard isViewLoaded else { return }
        categoryScrollTarget = nil
        dualCoordinator.stopMotion()
    }

    private func productCount(in section: Int) -> Int { section == names.count - 1 ? 8 : 4 + section % 3 }

    private func selectCategory(at section: Int) {
        let index = IndexPath(row: section, section: 0)
        // 程序化联动显式清掉旧选中项，避免快速更新或布局期间留下多个高亮。
        for previous in categoryTableView.indexPathsForSelectedRows ?? [] where previous != index {
            categoryTableView.deselectRow(at: previous, animated: false)
        }
        categoryTableView.selectRow(at: index, animated: false, scrollPosition: .none)
    }

    private func centerSelectedCategory() {
        let index = IndexPath(row: selectedCategory, section: 0)
        dualCoordinator.centerSecondaryRect(categoryTableView.rectForRow(at: index))
    }

    private func updateSelectedCategory() {
        guard !isUpdatingHeaderLayout, !dualCoordinator.isUpdatingSharedHeader, categoryScrollTarget == nil,
              productLayout.headerReferenceSize.height > 0,
              productLayout.headerCount == names.count,
              products.contentInset.top == headerHeight,
              products.bounds.width > categoryWidth else { return }
        let readingY = products.contentOffset.y + dualCoordinator.visibleSharedHeight + 1
        let section = (0..<names.count).last {
            guard let y = productLayout.originalHeaderY(at: $0 + leadingSectionCount) else { return false }
            return y <= readingY
        } ?? 0
        let index = IndexPath(row: section, section: 0)
        guard section != selectedCategory || categoryTableView.indexPathsForSelectedRows != [index] else { return }
        selectedCategory = section
        selectCategory(at: section)
        dualCoordinator.revealSecondaryRect(categoryTableView.rectForRow(at: index))
    }

}

extension FoodMenuViewController: UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { names.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "category") ?? UITableViewCell(style: .default, reuseIdentifier: "category")
        cell.backgroundColor = .secondarySystemBackground
        cell.textLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        cell.textLabel?.numberOfLines = 2
        cell.textLabel?.text = names[indexPath.row]
        let selection = UIView()
        selection.backgroundColor = products.backgroundColor
        cell.selectedBackgroundView = selection
        cell.accessibilityIdentifier = "food.category.\(indexPath.row)"
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        stopMotion()
        selectedCategory = indexPath.row
        categoryScrollTarget = indexPath.row
        selectCategory(at: indexPath.row)
        dualCoordinator.prepareForPrimaryContentSelection()
        products.layoutIfNeeded()
        guard let headerY = productLayout.originalHeaderY(at: indexPath.row + leadingSectionCount) else {
            categoryScrollTarget = nil
            return
        }
        let target = headerY - pinnedHeaderHeight
        if abs(products.contentOffset.y - target) < 0.5 {
            categoryScrollTarget = nil
            centerSelectedCategory()
        } else {
            products.setContentOffset(CGPoint(x: 0, y: target), animated: true)
        }
    }
    func numberOfSections(in collectionView: UICollectionView) -> Int { names.count + leadingSectionCount }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        section < leadingSectionCount ? 1 : productCount(in: section - leadingSectionCount)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if showsCarousels && indexPath.section == 0 {
            return CGSize(width: max(1, collectionView.bounds.width), height: carouselHeight)
        }
        let height = showsCarousels && indexPath.section == 1 ? Self.productCarouselHeight : 104
        return CGSize(width: max(1, collectionView.bounds.width - categoryWidth - 24), height: height)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        showsCarousels && section == 0 ? .zero : UIEdgeInsets(top: 0, left: categoryWidth + 12, bottom: 12, right: 12)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        section < leadingSectionCount ? .zero : CGSize(width: collectionView.bounds.width, height: 36)
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section < leadingSectionCount {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "carousel", for: indexPath)
            // 第 0 组只保留共享区占位；真实轮播由业务容器独立展示，不随 cell 复用消失。
            if indexPath.section == 0 {
                cell.contentView.subviews.forEach { $0.removeFromSuperview() }
                return cell
            }
            let carousel = productCarousel
            if carousel.superview !== cell.contentView {
                cell.contentView.subviews.forEach { $0.removeFromSuperview() }
                cell.contentView.addSubview(carousel)
            }
            carousel.frame = cell.contentView.bounds
            carousel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            return cell
        }
        let category = indexPath.section - leadingSectionCount
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "product", for: indexPath) as! FoodProductCell
        cell.configure(name: "\(names[category]) · \(indexPath.item + 1) 号餐", price: 16 + category + indexPath.item, index: IndexPath(item: indexPath.item, section: category))
        cell.onAdd = { [weak self] in self?.onAdd?() }
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "section", for: indexPath) as! FoodSectionHeader
        header.label.text = names[indexPath.section - leadingSectionCount]
        return header
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        dualCoordinator.scrollViewDidScroll(scrollView)
        // 主列表交给核心回调 updateSharedHeader 后再计算分类；此刻头部补偿可能尚未完成。
    }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        categoryScrollTarget = nil
        dualCoordinator.scrollViewWillBeginDragging(scrollView)
    }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if scrollView === products {
            let shouldCenterCategory = categoryScrollTarget != nil
            categoryScrollTarget = nil
            updateSelectedCategory()
            // 只响应分类点击，不在用户手动滚动商品或中途接管后强行移动左栏。
            if shouldCenterCategory { centerSelectedCategory() }
        }
    }
}

private final class FoodProductLayout: UICollectionViewFlowLayout {
    // 分组标题吸在 Tab 与当前可见共享轮播之后，不能覆盖重新展开的共享内容。
    var visibleContentTop: CGFloat = 0
    var categoryWidth: CGFloat = 92
    var leadingSectionCount = 0
    private var originalHeaders: [UICollectionViewLayoutAttributes] = []
    var headerCount: Int { originalHeaders.count }

    override func prepare() {
        super.prepare()
        // contentOffset 回调可能发生在 invalidateLayout 与下一次 prepare 之间。
        // 保留最近一次完整布局的原始分组位置，分类高亮不能依赖此刻可能为空的 superclass 缓存。
        originalHeaders = (leadingSectionCount..<max(leadingSectionCount, collectionView?.numberOfSections ?? 0)).compactMap {
            super.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: $0))?.copy() as? UICollectionViewLayoutAttributes
        }
    }

    func originalHeaderY(at section: Int) -> CGFloat? {
        originalHeaders.first { $0.indexPath.section == section }?.frame.minY
    }
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool { true }
    override func layoutAttributesForSupplementaryView(ofKind kind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = originalHeaders.first(where: { $0.indexPath == indexPath })?.copy() as? UICollectionViewLayoutAttributes,
              let collectionView, kind == UICollectionView.elementKindSectionHeader else { return nil }
        let nextY = indexPath.section + 1 < collectionView.numberOfSections ? (originalHeaderY(at: indexPath.section + 1) ?? collectionViewContentSize.height) : collectionViewContentSize.height
        attributes.frame.origin.y = min(max(attributes.frame.minY, collectionView.contentOffset.y + visibleContentTop), nextY - attributes.frame.height)
        attributes.frame.origin.x = categoryWidth + 12
        attributes.frame.size.width = max(1, collectionView.bounds.width - categoryWidth - 24)
        attributes.zIndex = 10
        return attributes
    }
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var result = (super.layoutAttributesForElements(in: rect) ?? []).filter { $0.representedElementKind != UICollectionView.elementKindSectionHeader }
        for section in 0..<(collectionView?.numberOfSections ?? 0) {
            if let header = layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: section)), header.frame.intersects(rect) { result.append(header) }
        }
        return result
    }
}

private final class FoodProductCell: UICollectionViewCell {
    private let name = UILabel()
    private let price = UILabel()
    private let detail = UILabel()
    private let add = UIButton(type: .system)
    var onAdd: (() -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        name.font = .systemFont(ofSize: 15, weight: .medium)
        name.adjustsFontSizeToFitWidth = true
        detail.text = "新鲜现做  ·  月售 100+"
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .secondaryLabel
        price.font = .systemFont(ofSize: 18, weight: .semibold)
        price.textColor = .systemOrange
        add.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        add.tintColor = .systemOrange
        add.addTarget(self, action: #selector(addItem), for: .touchUpInside)
        [name, detail, price, add].forEach(contentView.addSubview)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(name: String, price: Int, index: IndexPath) {
        self.name.text = name
        self.price.text = "¥\(price)"
        add.accessibilityLabel = "加入\(name)"
        add.accessibilityIdentifier = "food.add.\(index.section).\(index.item)"
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        name.frame = CGRect(x: 0, y: 8, width: bounds.width, height: 24)
        detail.frame = CGRect(x: 0, y: 35, width: bounds.width, height: 18)
        price.frame = CGRect(x: 0, y: 61, width: bounds.width - 48, height: 30)
        add.frame = CGRect(x: bounds.width - 44, y: 54, width: 44, height: 44)
    }
    @objc private func addItem() { onAdd?() }
}

private final class FoodSectionHeader: UICollectionReusableView {
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        label.font = .boldSystemFont(ofSize: 15)
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
    }
}

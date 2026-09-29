import UIKit
import NestedPageViewController

final class FoodMenuViewController: UIViewController, NestedPageScrollable {
    static let coverHeight: CGFloat = 200
    static let tabHeight: CGFloat = 44
    static let sharedCarouselHeight: CGFloat = 220
    static let productCarouselHeight: CGFloat = 120
    private let categoryWidth: CGFloat = 92
    private let showsCarousels: Bool
    private var carouselHeight: CGFloat { showsCarousels ? Self.sharedCarouselHeight : 0 }
    private var leadingSectionCount: Int { showsCarousels ? 2 : 0 }
    private var headerHeight: CGFloat { Self.coverHeight + Self.tabHeight }
    private var visibleHeaderHeight: CGFloat = coverHeight + tabHeight
    private var visibleSharedHeight: CGFloat
    private var initialSharedHeight: CGFloat { headerHeight + carouselHeight }
    private var maximumSharedCollapse: CGFloat { Self.coverHeight + carouselHeight }
    private var collapsedSharedHeight: CGFloat { initialSharedHeight - visibleSharedHeight }
    private var productDepth: CGFloat { products.contentOffset.y + visibleSharedHeight - carouselHeight }
    private var categoryOffset: CGFloat
    private var isUpdatingCategories = false
    private var isDrivingFromCategories = false
    private var selectedCategory = 0
    private var categoryScrollTarget: Int?
    private var lastLayoutSize = CGSize.zero
    private var pagingObservation: NSKeyValueObservation?

    weak var pager: NestedPageViewController?
    var onAdd: (() -> Void)?
    var usesShortCategories = false {
        didSet {
            guard isViewLoaded else { return }
            stopMotion()
            selectedCategory = 0
            products.reloadData()
            categories.reloadData()
            view.setNeedsLayout()
        }
    }
    private let allCategories = ["招牌热销", "超值套餐", "下饭小炒", "鲜香炖菜", "时令蔬菜", "经典盖饭", "面食米粉", "暖心汤品", "香酥小食", "清爽凉菜", "精品主食", "现制饮品", "甜品水果", "儿童餐", "双人分享", "加料专区"]
    private var names: [String] { usesShortCategories ? Array(allCategories.prefix(4)) : allCategories }
    private let categoryContainer = UIView()
    private let categories: UITableView
    private let sharedCarousel = FoodCarouselView(style: .shared)
    private let productCarousel = FoodCarouselView(style: .products)
    private let productLayout = FoodProductLayout()
    private lazy var products = UICollectionView(frame: .zero, collectionViewLayout: productLayout)
    var nestedPageContentScrollView: UIScrollView { products }

    init(categoryTable: UITableView = UITableView(frame: .zero, style: .plain), showsCarousels: Bool = true) {
        categories = categoryTable
        self.showsCarousels = showsCarousels
        let initialHeight = Self.coverHeight + Self.tabHeight + (showsCarousels ? Self.sharedCarouselHeight : 0)
        visibleSharedHeight = initialHeight
        categoryOffset = -initialHeight
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
        view.addSubview(products)

        if showsCarousels {
            // 轮播横拖优先于外层横向分页，纵拖则交给商品列表；即使轮播到边缘也不误切 Tab。
            for carousel in [sharedCarousel, productCarousel] {
                pager?.containerScrollView.panGestureRecognizer.require(toFail: carousel.panGestureRecognizer)
                // 不对商品列表的纵向 pan 建立同样的等待关系，否则轮播区域的纵拖会被阻断。
                if let popGesture = navigationController?.interactivePopGestureRecognizer {
                    carousel.panGestureRecognizer.require(toFail: popGesture)
                }
            }
        }

        // 两个列表是兄弟视图。商品列表保持全宽，使组件的共享头部仍在正确的 x 坐标。
        categoryContainer.clipsToBounds = true
        categoryContainer.backgroundColor = .secondarySystemBackground
        view.addSubview(categoryContainer)
        categories.backgroundColor = .secondarySystemBackground
        categories.dataSource = self
        categories.delegate = self
        categories.rowHeight = 60
        categories.estimatedRowHeight = 0
        categories.separatorStyle = .none
        categories.showsVerticalScrollIndicator = false
        categories.contentInsetAdjustmentBehavior = .never
        categories.scrollsToTop = false
        categories.bounces = false
        categories.alwaysBounceVertical = false
        categories.accessibilityIdentifier = "food.categories"
        categories.contentInset.top = initialSharedHeight
        categories.contentOffset.y = -initialSharedHeight
        categoryContainer.addSubview(categories)
        if let popGesture = navigationController?.interactivePopGestureRecognizer {
            categories.panGestureRecognizer.require(toFail: popGesture)
        }
        // 非当前页不会收到主列表 delegate 回调。横向滚动开始即停止分类栏惯性。
        pagingObservation = pager?.containerScrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            self?.stopCategoryMotion()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 组件加载子页时会统一设置商品列表的 bounces，因此在其后的布局阶段关闭回弹。
        products.bounces = false
        let changed = lastLayoutSize != view.bounds.size
        lastLayoutSize = view.bounds.size
        products.frame = view.bounds
        if changed {
            productLayout.itemSize = CGSize(width: max(1, view.bounds.width - categoryWidth - 24), height: 104)
            productLayout.headerReferenceSize = CGSize(width: view.bounds.width, height: 36)
        }
        layoutCategoryViewport()
        updateCategoryInsets()
        // 为最后一个短商品分组补足空间，保证点击分类也能把标题滚到 tab 下方。
        let lastHeight = CGFloat(productCount(in: names.count - 1)) * 104 + 36 + 12
        let bottom = max(view.safeAreaInsets.bottom, view.bounds.height - Self.tabHeight - lastHeight)
        if products.contentInset.top == headerHeight {
            pager?.setContentBottomInset(bottom, for: products)
        }
        updateSelectedCategory()
    }

    func updateSharedHeader(visibleHeight: CGFloat) {
        guard isViewLoaded else { return }
        let newHeight = min(headerHeight, max(Self.tabHeight, visibleHeight))
        // Tab 吸顶后，公共轮播仍有一段可以收起；右侧小轮播不属于这段共享位移。
        let remainingCarousel = min(carouselHeight, max(0, carouselHeight - products.contentOffset.y - newHeight))
        let newSharedHeight = newHeight + remainingCarousel
        let delta = visibleSharedHeight - newSharedHeight
        visibleHeaderHeight = newHeight
        visibleSharedHeight = newSharedHeight
        // 展开前先放宽分类的滚动边界，避免新 offset 被旧的吸顶 inset 收回。
        updateCategoryInsets()
        // 右侧驱动：只同步店铺 + 公共轮播的位移，保留分类自己的阅读位置。
        // 左侧驱动：这部分位移已经包含在 UIKit 的原生 offset 中，不能再加一次。
        if !isDrivingFromCategories && abs(delta) > 0.001 {
            setCategoryOffset(categories.contentOffset.y + delta)
        }
        layoutCategoryViewport()
        productLayout.visibleHeaderHeight = newHeight
        productLayout.invalidateLayout()
        updateSelectedCategory()
    }

    private func layoutCategoryViewport() {
        isUpdatingCategories = true
        defer { isUpdatingCategories = false }
        categoryContainer.frame = CGRect(x: 0, y: visibleSharedHeight, width: categoryWidth, height: max(0, view.bounds.height - visibleSharedHeight))
        // 容器向上移动多少，内部列表就向下补偿多少：列表在根视图中的原点始终为 0。
        // bounds 高度不随头部折叠变化，避免拖拽中改变 UIKit 的减速几何。
        categories.frame = CGRect(x: 0, y: -visibleSharedHeight, width: categoryWidth, height: view.bounds.height)
        categoryOffset = categories.contentOffset.y
    }

    private func updateCategoryInsets() {
        isUpdatingCategories = true
        defer { isUpdatingCategories = false }
        // 右侧独立内容（含小轮播）未回顶时，分类不能强行拉回商品。否则先恢复公共轮播，再展开店铺。
        // keepsContentScrollPosition 开启后，头部可以展开而商品仍在深处；不能用“未吸顶”推断右侧已回顶。
        let mayExpandHeader = productDepth <= 0.5
        let top = mayExpandHeader ? initialSharedHeight : visibleSharedHeight
        let bottom = max(view.safeAreaInsets.bottom, view.bounds.height - categories.contentSize.height - Self.tabHeight)
        let inset = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
        if categories.contentInset != inset {
            let offset = categories.contentOffset
            categories.contentInset = inset
            if categories.contentOffset != offset { categories.contentOffset = offset }
        }
        categoryOffset = categories.contentOffset.y
    }

    private func setCategoryOffset(_ value: CGFloat) {
        isUpdatingCategories = true
        categories.setContentOffset(CGPoint(x: 0, y: value), animated: false)
        categoryOffset = categories.contentOffset.y
        isUpdatingCategories = false
    }

    private func categoriesDidScroll() {
        guard !isUpdatingCategories else { return }
        let previous = categoryOffset
        categoryOffset = categories.contentOffset.y
        guard pager?.currentIndex == 0,
              categories.isDragging || categories.isDecelerating else { return }
        let delta = categoryOffset - previous
        let localPosition = max(0, previous + visibleSharedHeight)
        let consumed: CGFloat
        if delta > 0 {
            // 顶部回弹恢复先走完越界距离，不能把弹簧回程当作一次收起头部的滚动。
            let beyondBounce = max(0, delta + min(0, previous + visibleSharedHeight))
            consumed = min(beyondBounce, maximumSharedCollapse - collapsedSharedHeight)
        } else if productDepth <= 0.5 {
            // 下拉先消耗分类已滚动的距离，剩余部分才展开公共头部。
            consumed = max(-collapsedSharedHeight, min(0, delta + localPosition))
        } else {
            consumed = 0
        }
        guard abs(consumed) > 0.001 else { return }
        isDrivingFromCategories = true
        products.setContentOffset(CGPoint(x: 0, y: products.contentOffset.y + consumed), animated: false)
        isDrivingFromCategories = false
        categoryOffset = categories.contentOffset.y
    }

    func resetCategoryPosition() {
        setCategoryOffset(-visibleSharedHeight)
        selectedCategory = 0
        selectCategory(at: 0)
    }

    private func stopCategoryMotion() {
        if categories.isDecelerating {
            if #available(iOS 17.4, *) { categories.stopScrollingAndZooming() }
            else { categories.setContentOffset(categories.contentOffset, animated: false) }
        }
        categoryOffset = categories.contentOffset.y
    }

    func stopMotion() {
        guard isViewLoaded else { return }
        stopCategoryMotion()
        categoryScrollTarget = nil
        sharedCarousel.stopMotion()
        productCarousel.stopMotion()
        if #available(iOS 17.4, *) { products.stopScrollingAndZooming() }
        else { products.setContentOffset(products.contentOffset, animated: false) }
    }

    private func productCount(in section: Int) -> Int { section == names.count - 1 ? 1 : 4 + section % 3 }

    private func selectCategory(at section: Int) {
        let index = IndexPath(row: section, section: 0)
        // 程序化联动显式清掉旧选中项，避免快速更新或布局期间留下多个高亮。
        for previous in categories.indexPathsForSelectedRows ?? [] where previous != index {
            categories.deselectRow(at: previous, animated: false)
        }
        categories.selectRow(at: index, animated: false, scrollPosition: .none)
    }

    private func updateSelectedCategory() {
        guard categoryScrollTarget == nil,
              productLayout.headerReferenceSize.height > 0,
              productLayout.headerCount == names.count,
              products.contentInset.top == headerHeight,
              products.bounds.width > categoryWidth else { return }
        let readingY = products.contentOffset.y + visibleHeaderHeight + 1
        let section = (0..<names.count).last {
            guard let y = productLayout.originalHeaderY(at: $0 + leadingSectionCount) else { return false }
            return y <= readingY
        } ?? 0
        let index = IndexPath(row: section, section: 0)
        guard section != selectedCategory || categories.indexPathsForSelectedRows != [index] else { return }
        selectedCategory = section
        selectCategory(at: section)
        // 用户正在拖分类时不抢它的位置。否则仅在选中项被裁剪时把它移入可见区域。
        guard !categories.isDragging, !categories.isDecelerating, !isDrivingFromCategories else { return }
        let row = categories.rectForRow(at: index)
        let top = categories.contentOffset.y + visibleSharedHeight
        let bottom = categories.contentOffset.y + categories.bounds.height
        if row.minY < top { setCategoryOffset(row.minY - visibleSharedHeight) }
        else if row.maxY > bottom { setCategoryOffset(row.maxY - categories.bounds.height) }
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
        selection.backgroundColor = .systemOrange.withAlphaComponent(0.18)
        cell.selectedBackgroundView = selection
        cell.accessibilityIdentifier = "food.category.\(indexPath.row)"
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        stopMotion()
        selectedCategory = indexPath.row
        categoryScrollTarget = indexPath.row
        selectCategory(at: indexPath.row)
        products.layoutIfNeeded()
        guard let headerY = productLayout.originalHeaderY(at: indexPath.row + leadingSectionCount) else {
            categoryScrollTarget = nil
            return
        }
        let target = headerY - Self.tabHeight
        if abs(products.contentOffset.y - target) < 0.5 { categoryScrollTarget = nil }
        else { products.setContentOffset(CGPoint(x: 0, y: target), animated: true) }
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
            let carousel = indexPath.section == 0 ? sharedCarousel : productCarousel
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
        if scrollView === categories { categoriesDidScroll() }
        else { updateSelectedCategory() }
    }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        categoryScrollTarget = nil
        if scrollView === products { stopCategoryMotion() }
        else {
            if #available(iOS 17.4, *) { products.stopScrollingAndZooming() }
            else { products.setContentOffset(products.contentOffset, animated: false) }
            categoryOffset = categories.contentOffset.y
        }
    }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if scrollView === products {
            categoryScrollTarget = nil
            updateSelectedCategory()
        }
    }
}

private final class FoodProductLayout: UICollectionViewFlowLayout {
    var visibleHeaderHeight: CGFloat = FoodMenuViewController.coverHeight + FoodMenuViewController.tabHeight
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
        attributes.frame.origin.y = min(max(attributes.frame.minY, collectionView.contentOffset.y + visibleHeaderHeight), nextY - attributes.frame.height)
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

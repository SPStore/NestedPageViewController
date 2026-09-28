import NestedPageViewController
import UIKit

/// 无自定义 scrollView / 最低高度 layout，直接验证组件对原生短列表的处理。
final class ShortContentViewController: NestedPageViewController, NestedPageViewControllerDataSource {
    private let pages = ShortContentPage.Kind.allCases.map { ShortContentPage(kind: $0) }
    private var isSelecting = false
    private var itemCount = 3
    private var hasBottomToolbar = false
    private let cover = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "短内容回归"
        dataSource = self
        keepsContentScrollPosition = true
        automaticallyAdjustsContainerInsets = true
        cover.numberOfLines = 0
        cover.textAlignment = .center
        cover.backgroundColor = .secondarySystemBackground
        cover.isUserInteractionEnabled = true
        cover.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleAutomaticRange)))
        updateCoverText()
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "选择", style: .plain, target: self, action: #selector(toggleSelection)),
            UIBarButtonItem(title: "数据", style: .plain, target: self, action: #selector(changeData)),
            UIBarButtonItem(title: "刷新", style: .plain, target: self, action: #selector(reloadLists)),
            UIBarButtonItem(title: "底部", style: .plain, target: self, action: #selector(toggleBottomInset))
        ]
    }

    @objc private func toggleSelection() {
        let scrollView = pages[currentIndex].nestedPageContentScrollView
        let previousOffset = scrollView.contentOffset
        isSelecting.toggle()
        navigationItem.rightBarButtonItems?.first?.title = isSelecting ? "取消" : "选择"
        cover.isHidden = isSelecting
        updateBusinessInsets()
        updateLayouts()
        reloadLists()
        scrollView.layoutIfNeeded()
        let minimum = -scrollView.adjustedContentInset.top
        let maximum = max(minimum, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
        scrollView.setContentOffset(
            CGPoint(x: previousOffset.x, y: min(maximum, max(minimum, previousOffset.y))), animated: false
        )
    }

    @objc private func changeData() {
        itemCount = itemCount == 3 ? 30 : (itemCount == 30 ? 0 : 3)
        title = "短内容回归（\(itemCount) 条）"
        reloadLists()
    }

    @objc private func reloadLists() {
        pages.forEach { $0.reload(count: itemCount) }
    }

    @objc private func toggleBottomInset() {
        hasBottomToolbar.toggle()
        updateBusinessInsets()
    }

    @objc private func toggleAutomaticRange() {
        autoAdjustsContentSizeMinimumHeight.toggle()
        updateCoverText()
    }

    private func updateCoverText() {
        let state = autoAdjustsContentSizeMinimumHeight ? "开启" : "关闭"
        cover.text = "原生 Table / Flow / Compositional\n选择 → 取消 → 反复切页\n自动补足：\(state)（点击切换）"
    }

    private func updateBusinessInsets() {
        for page in pages {
            setContentBottomInset(isSelecting || hasBottomToolbar ? 90 : 0, for: page.nestedPageContentScrollView)
        }
    }

    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int { return pages.count }
    func pageViewController(_ pageViewController: NestedPageViewController, viewControllerAt index: Int) -> NestedPageScrollable? {
        return pages[index]
    }
    func pageViewController(_ pageViewController: NestedPageViewController, shouldPreloadViewControllerAt index: Int) -> Bool {
        return true
    }
    func coverView(in pageViewController: NestedPageViewController) -> UIView? { return cover }
    func heightForCoverView(in pageViewController: NestedPageViewController) -> CGFloat { return isSelecting ? 0 : 204 }
    func heightForTabStrip(in pageViewController: NestedPageViewController) -> CGFloat { return isSelecting ? 0 : 44 }
    func titlesForTabStrip(in pageViewController: NestedPageViewController) -> [String]? {
        return ["Table", "Flow", "Compositional"]
    }
}

private final class ShortContentPage: UIViewController, NestedPageScrollable, UICollectionViewDataSource, UITableViewDataSource {
    enum Kind: CaseIterable { case table, flow, compositional }
    let nestedPageContentScrollView: UIScrollView
    private var itemCount = 3

    init(kind: Kind) {
        switch kind {
        case .table:
            nestedPageContentScrollView = UITableView(frame: .zero, style: .plain)
        case .flow, .compositional:
            let layout: UICollectionViewLayout
            if kind == .flow {
                let flow = UICollectionViewFlowLayout()
                flow.itemSize = CGSize(width: 280, height: 56)
                flow.minimumLineSpacing = 8
                layout = flow
            } else {
                let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(56))
                let item = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 8
                layout = UICollectionViewCompositionalLayout(section: section)
            }
            nestedPageContentScrollView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        nestedPageContentScrollView.frame = view.bounds
        nestedPageContentScrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        nestedPageContentScrollView.backgroundColor = .systemBackground
        view.addSubview(nestedPageContentScrollView)
        if let collectionView = nestedPageContentScrollView as? UICollectionView {
            collectionView.register(ShortContentCell.self, forCellWithReuseIdentifier: "cell")
            collectionView.dataSource = self
        } else if let tableView = nestedPageContentScrollView as? UITableView {
            tableView.rowHeight = 56
            tableView.estimatedRowHeight = 0
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
            tableView.dataSource = self
        }
    }

    func reload(count: Int) {
        itemCount = count
        (nestedPageContentScrollView as? UICollectionView)?.reloadData()
        (nestedPageContentScrollView as? UITableView)?.reloadData()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { return itemCount }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        (cell as? ShortContentCell)?.label.text = "文档 \(indexPath.item + 1)"
        return cell
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return itemCount }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = "文档 \(indexPath.row + 1)"
        return cell
    }
}

private final class ShortContentCell: UICollectionViewCell {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemBackground
        label.frame = contentView.bounds.insetBy(dx: 16, dy: 0)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

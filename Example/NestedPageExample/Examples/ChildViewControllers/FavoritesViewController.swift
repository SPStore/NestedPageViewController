//
//  FavoritesViewController.swift
//  NestedPageViewController
//
//  Created by 乐升平 on 2025/8/24.
//

import UIKit
import NestedPageViewController
import MJRefresh
import JXCategoryView

class FavoritesViewController: ChildBaseViewController {

    var headerHeight: CGFloat = 0 {
        didSet {
            self.flowLayout.headerHeight = headerHeight
        }
    }
    
    var headerOffset: CGFloat = 0.0 {
        didSet {
            self.flowLayout.headerOffset = headerOffset
        }
    }
    
    // 是否需要展示并吸顶sectionHeader
    var isShowAndPinHeader: Bool = false {
        didSet {
            self.flowLayout.customSectionHeadersPinToVisibleBounds = isShowAndPinHeader
        }
    }
    
    private lazy var flowLayout: PinnedHeaderFlowLayout = {
        let layout = PinnedHeaderFlowLayout()
        return layout;
    }()
    
    private lazy var collectionView: MyCollectionView = {
        let collectionView = MyCollectionView(frame: .zero, collectionViewLayout: self.flowLayout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .systemBackground
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "NumberCell")
        collectionView.register(SectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SectionHeader")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupRefresh()
    }
    
    private func setupCollectionView() {
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentTopAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func setupRefresh() {
        // 根据 refreshType 设置下拉刷新
        switch refreshType {
        case .none:
            // 无刷新，不添加任何刷新控件
            break
        case .partial:
            // 局部刷新
            collectionView.mj_header = MJRefreshNormalHeader { [weak self] in
                self?.performPartialRefresh()
            }
        case .global:
            // 全局刷新
            collectionView.mj_header = MJRefreshNormalHeader { [weak self] in
                self?.performGlobalRefresh()
            }
        }
        collectionView.mj_header?.ignoredScrollViewContentInsetTop = ignoredScrollViewContentInsetTop
    }
    
    private func performPartialRefresh() {
        // 模拟局部刷新逻辑
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // 这里可以实现具体的局部刷新逻辑
            print("FavoritesViewController - 执行局部刷新")
            self?.collectionView.reloadData()
            self?.collectionView.mj_header?.endRefreshing()
        }
    }
    
    private func performGlobalRefresh() {
        // 模拟全局刷新逻辑
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // 这里可以实现具体的全局刷新逻辑
            print("FavoritesViewController - 执行全局刷新")
            self?.collectionView.reloadData()
            self?.collectionView.mj_header?.endRefreshing()
        }
    }
}

// MARK: - UICollectionViewDataSource
extension FavoritesViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 100
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SectionHeader", for: indexPath) as! SectionHeaderView
            // 不需要额外配置，因为SectionHeaderView在初始化时已经设置好了JXCategoryTitleImageView
            return headerView
        }
        return UICollectionReusableView()
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NumberCell", for: indexPath)
        
        let labelTag = 1001
        var numberLabel = cell.contentView.viewWithTag(labelTag) as? UILabel
        
        if numberLabel == nil {
            cell.backgroundColor = .systemGray6
            cell.layer.cornerRadius = 8
            
            numberLabel = UILabel()
            numberLabel!.textAlignment = .center
            numberLabel!.font = UIFont.systemFont(ofSize: 20, weight: .medium)
            numberLabel!.textColor = .label
            numberLabel!.tag = labelTag
            numberLabel!.translatesAutoresizingMaskIntoConstraints = false
            
            cell.contentView.addSubview(numberLabel!)
            NSLayoutConstraint.activate([
                numberLabel!.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                numberLabel!.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
            ])
        }
        
        // 更新label文本
        numberLabel!.text = "\(indexPath.row)"
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension FavoritesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

// 布局配置通过代理方法实现，不要用layout在初始化时设置，因为要演示旋转，旋转后屏幕宽高发生了变化，itemSize需要通过代理的方式更新.
extension FavoritesViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let availableWidth = collectionView.bounds.width
        let totalHorizontalPadding: CGFloat = 10 + 10 + 10 // left + right + middle spacing
        let cellWidth = max(1, (availableWidth - totalHorizontalPadding) / 2)
        return CGSize(width: cellWidth, height: cellWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        // 根据isShowAndPinHeader属性决定是否显示header
        if isShowAndPinHeader {
            return CGSize(width: collectionView.bounds.width, height: 30)
        } else {
            // 返回零尺寸表示不显示header
            return CGSize.zero
        }
    }
}

// MARK: - Section Header View
class SectionHeaderView: UICollectionReusableView, JXCategoryViewDelegate {
    
    private let categoryView: JXCategoryTitleView = {
        let view = JXCategoryTitleView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // 配置基本属性
        view.titleFont = .systemFont(ofSize: 14)
        view.titleColor = .darkGray
        view.titleSelectedColor = .systemBlue
        view.isAverageCellSpacingEnabled = false
        return view
    }()
    
    // 用于展示内容的容器视图
    private let contentView = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        
        // 添加分类视图
        addSubview(categoryView)
        NSLayoutConstraint.activate([
            categoryView.topAnchor.constraint(equalTo: topAnchor),
            categoryView.leadingAnchor.constraint(equalTo: leadingAnchor),
            categoryView.trailingAnchor.constraint(equalTo: trailingAnchor),
            categoryView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // 配置数据
        setupCategoryData()
    }
    
    private func setupCategoryData() {
        let titles = ["我的收藏夹", "音乐", "视频", "合集", "话题", "影视综", "小说", "记录片"]
        categoryView.titles = titles
        categoryView.delegate = self
        categoryView.reloadData()
    }
    
    // MARK: - JXCategoryViewDelegate
    func categoryView(_ categoryView: JXCategoryBaseView!, didSelectedItemAt index: Int) {
        // 处理选择事件
        print("选中了分类: \(index)")
    }
}

// MARK: - NestedPageScrollable
extension FavoritesViewController: NestedPageScrollable {

    var nestedPageContentScrollView: UIScrollView {
        return collectionView
    }
}

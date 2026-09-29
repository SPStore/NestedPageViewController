//
//  PinnedCollectionHeaderViewController.swift
//  NestedPageExample
//
//  Created by 乐升平 on 2025/9/26.
//

import UIKit
import NestedPageViewController

class PinnedCollectionHeaderViewController: UIViewController {
    
    // MARK: - Properties
    
    var tabStripHeight = 40.0
    var coverHeight = 260.0
    
    private var nestedPageViewController = NestedPageViewController()
    private var coverView: UIView = ProfileCoverView(frame: .zero)
    private lazy var tabStripView: NestedPageTabStripView = {
        // 创建标签栏配置
        var tabStripConfig = NestedPageTabStripConfiguration()
        tabStripConfig.titles = childControllerTitles
        tabStripConfig.titleColor = .gray
        tabStripConfig.titleSelectedColor = .systemBlue
        tabStripConfig.titleFont = .systemFont(ofSize: 16, weight: .medium)
        tabStripConfig.backgroundColor = .systemBackground
        tabStripConfig.indicatorSize = CGSize(width: 50, height: 3)
                
        // 创建标签栏
        let view = NestedPageTabStripView(configuration: tabStripConfig)
        return view
    }()
    
    // MARK: - View Controllers
    
    private let childControllerTitles = ["作品", "推荐", "收藏", "喜欢"]
    
    private let favoritesVC = FavoritesViewController()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        setupNestedPageViewController()
        
        self.tabStripView.linkedScrollView = nestedPageViewController.containerScrollView
        
        // 添加导航栏右侧说明按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "说明",
            style: .plain,
            target: self,
            action: #selector(showInstructions)
        )
    }
    
    @objc private func showInstructions() {
        let alertController = UIAlertController(
            title: "说明",
            message: "子VC中的collectionView的sectionHeader吸顶，跟本框架无关，是在外部通过重写flowLayout的布局方法实现",
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(
            title: "我知道了",
            style: .default
        ))
        
        present(alertController, animated: true)
    }
    
    // MARK: - Setup

    private func setupNestedPageViewController() {
        nestedPageViewController.dataSource = self
        nestedPageViewController.delegate = self
        // 默认切到第3个tab
        nestedPageViewController.defaultPageIndex = 2
        
        // 应用全局配置
        NestedPageConfig.shared.applyConfig(to: nestedPageViewController)
        
        addChild(nestedPageViewController)
        view.addSubview(nestedPageViewController.view)
        
        // 使用frame布局而不是Auto Layout
        let safeAreaTop = view.safeAreaInsets.top
        nestedPageViewController.view.frame = CGRect(
            x: 0,
            y: safeAreaTop,
            width: view.bounds.width,
            height: view.bounds.height - safeAreaTop
        )
        
        nestedPageViewController.didMove(toParent: self)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 更新NestedPageViewController的frame
        let safeAreaTop = view.safeAreaInsets.top
        nestedPageViewController.view.frame = CGRect(
            x: 0,
            y: safeAreaTop,
            width: view.bounds.width,
            height: view.bounds.height - safeAreaTop
        )
    }
}

// MARK: - NestedPageViewControllerDataSource

extension PinnedCollectionHeaderViewController: NestedPageViewControllerDataSource {
    
    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int {
        return childControllerTitles.count
    }
    
    func pageViewController(_ pageViewController: NestedPageViewController, viewControllerAt index: Int) -> NestedPageScrollable? {
        guard index >= 0 && index < childControllerTitles.count else { return nil }
        
        switch index {
        case 0:
            return PostsViewController()
        case 1:
            return LikesViewController()
        case 2:
            favoritesVC.isShowAndPinHeader = true
            favoritesVC.headerHeight = coverHeight + tabStripHeight
            return favoritesVC
        case 3:
            return RecommendsViewController()
        default:
            return nil
        }
    }
    
    func coverView(in pageViewController: NestedPageViewController) -> UIView? {
        return coverView
    }
    
    func heightForCoverView(in pageViewController: NestedPageViewController) -> CGFloat {
        return coverHeight
    }
    
    func tabStrip(in pageViewController: NestedPageViewController) -> UIView? {
        return self.tabStripView
    }
    
    func heightForTabStrip(in pageViewController: NestedPageViewController) -> CGFloat {
        return tabStripHeight
    }
}

extension PinnedCollectionHeaderViewController: NestedPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: NestedPageViewController, contentScrollViewDidScroll scrollView: UIScrollView, headerOffset: CGFloat, isSticked: Bool) {
        
        self.favoritesVC.headerOffset = headerOffset
        
    }
    
}

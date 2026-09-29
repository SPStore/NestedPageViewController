//
//  PartialRefreshViewController.swift
//  NestedPageViewController
//
//  Created by 乐升平 on 2025/8/30.
//

import UIKit
import NestedPageViewController

class PartialRefreshViewController: UIViewController {
    
    // MARK: - Properties
    
    private var nestedPageViewController = NestedPageViewController()
    private var lastPageSize = CGSize.zero
    private var coverView: UIView = ProfileCoverView(frame: .zero)
    
    // MARK: - View Controllers
    
    private let childControllerTitles = ["作品", "推荐", "收藏", "喜欢"]
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        setupNestedPageViewController()
    }
    
    // MARK: - Setup

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = nestedPageViewController.view.bounds.size
        guard size != lastPageSize else { return }
        lastPageSize = size
        // 安全区约束变化后同步组件内部的分页、头部和滚动范围。
        if nestedPageViewController.viewController(at: nestedPageViewController.currentIndex) != nil {
            nestedPageViewController.updateLayouts()
        }
    }

    private func setupNestedPageViewController() {
        nestedPageViewController.dataSource = self
        nestedPageViewController.delegate = self
        // 必须禁用头部弹性效果，才能看到局部刷新
        nestedPageViewController.headerBounces = false
        
        // 应用全局配置
        NestedPageConfig.shared.applyConfig(to: nestedPageViewController)
        
        addChild(nestedPageViewController)
        view.addSubview(nestedPageViewController.view)
        
        let safeArea = view.safeAreaLayoutGuide
        nestedPageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nestedPageViewController.view.topAnchor.constraint(equalTo: safeArea.topAnchor),
            nestedPageViewController.view.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            nestedPageViewController.view.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            nestedPageViewController.view.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
        ])
        
        nestedPageViewController.didMove(toParent: self)
    }
    
}

// MARK: - NestedPageViewControllerDataSource

extension PartialRefreshViewController: NestedPageViewControllerDataSource {
    
    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int {
        return childControllerTitles.count
    }
    
    func pageViewController(_ pageViewController: NestedPageViewController, viewControllerAt index: Int) -> NestedPageScrollable? {
        guard index >= 0 && index < childControllerTitles.count else { return nil }
        
        switch index {
        case 0:
            let postsVc = PostsViewController()
            postsVc.refreshType = .partial
            return postsVc
        case 1:
            let likesVc = LikesViewController()
            likesVc.refreshType = .partial
            return likesVc
        case 2:
            let favoritesVc = FavoritesViewController()
            favoritesVc.refreshType = .partial
            return favoritesVc
        case 3:
            let recommendsVc = RecommendsViewController()
            recommendsVc.refreshType = .partial
            return recommendsVc
        default:
            return nil
        }
    }
    
    func coverView(in pageViewController: NestedPageViewController) -> UIView? {
        return coverView
    }
    
    func heightForCoverView(in pageViewController: NestedPageViewController) -> CGFloat {
        return 260.0
    }
    
    func tabStrip(in pageViewController: NestedPageViewController) -> UIView? {
        return nil  // 使用内置的标签栏
    }
    
    func heightForTabStrip(in pageViewController: NestedPageViewController) -> CGFloat {
        return 40.0
    }
    
    func titlesForTabStrip(in pageViewController: NestedPageViewController) -> [String]? {
        return childControllerTitles
    }
}

// MARK: - NestedPageViewControllerDelegate

extension PartialRefreshViewController: NestedPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: NestedPageViewController, didScrollToPageAt index: Int) {

    }
}

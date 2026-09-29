//
//  GlobalRefreshViewController.swift
//  NestedPageExample
//
//  Created by 乐升平 on 2025/8/31.
//

import UIKit
import NestedPageViewController

class GlobalRefreshViewController: UIViewController {
    
    // MARK: - Properties
    
    private var nestedPageViewController = NestedPageViewController()
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
    
    private func setupNestedPageViewController() {
        nestedPageViewController.dataSource = self
        
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

extension GlobalRefreshViewController: NestedPageViewControllerDataSource {
    
    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int {
        return childControllerTitles.count
    }
    
    func pageViewController(_ pageViewController: NestedPageViewController, viewControllerAt index: Int) -> NestedPageScrollable? {
        guard index >= 0 && index < childControllerTitles.count else { return nil }
        
        switch index {
        case 0:
            let postsVc = PostsViewController()
            postsVc.refreshType = .global
            // 默认刷新是在头部的下面，为了使刷新移到最顶端，需要忽略contentScrollView的inset.top
            postsVc.ignoredScrollViewContentInsetTop = nestedPageViewController.headerHeight
            return postsVc
        case 1:
            let likesVc = LikesViewController()
            likesVc.refreshType = .global
            likesVc.ignoredScrollViewContentInsetTop = nestedPageViewController.headerHeight
            return likesVc
        case 2:
            let favoritesVc = FavoritesViewController()
            favoritesVc.refreshType = .global
            favoritesVc.ignoredScrollViewContentInsetTop = nestedPageViewController.headerHeight
            return favoritesVc
        case 3:
            let recommendsVc = RecommendsViewController()
            recommendsVc.refreshType = .global
            recommendsVc.ignoredScrollViewContentInsetTop = nestedPageViewController.headerHeight
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

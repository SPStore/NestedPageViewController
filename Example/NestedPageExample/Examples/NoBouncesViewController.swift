//
//  NoBouncesViewController.swift
//  NestedPageExample
//
//  Created by 乐升平 on 2025/9/4.
//

import UIKit
import NestedPageViewController

class NoBouncesViewController: NestedPageViewController {
    
    // MARK: - Properties
    
    private var coverView: UIView = ProfileCoverView(frame: .zero)
    
    // MARK: - View Controllers
    
    private let childControllerTitles = ["作品", "推荐", "收藏", "喜欢"]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground

        setupNestedPageViewController()
    }
    
    override func viewDidLayoutSubviews() {
        let safeTop = view.safeAreaInsets.top
        containerInsets = UIEdgeInsets(top: safeTop, left: 0, bottom: 0, right: 0)
        
        // 由于本示例是采用继承的方式， 需要在super之前设置containerInsets，因为NestedPageViewController所有的布局都是在viewDidLayoutSubviews完成的，如果先super，再设置containerInsets内部不再更新布局。
        super.viewDidLayoutSubviews()
    }
    
    // MARK: - Setup

    private func setupNestedPageViewController() {
        
        dataSource = self
        
        bounces = false
                        
        // 应用全局配置
        NestedPageConfig.shared.applyConfig(to: self)
    }
}

// MARK: - NestedPageViewControllerDataSource

extension NoBouncesViewController: NestedPageViewControllerDataSource {
    
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
            return FavoritesViewController()
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

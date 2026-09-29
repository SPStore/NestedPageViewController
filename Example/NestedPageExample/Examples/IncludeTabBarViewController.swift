//
//  IncludeTabBarViewController.swift
//  NestedPageExample
//
//  Created by 乐升平 on 2025/9/4.
//

import UIKit
import NestedPageViewController

class IncludeTabBarViewController: NestedPageViewController {
    
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
    
    // MARK: - Setup
    
    private func setupNestedPageViewController() {
        
        dataSource = self
        
        // 由于是继承方式，self.view默认是全屏的，通过设置automaticallyAdjustsContainerInsets = true，内部会自动设置容器顶部和底部的安全距离。等效于设置containerInsets = UIEdgeInsets(safeTop, 0, safeBottom, 0)
        automaticallyAdjustsContainerInsets = true
                
        // 应用全局配置
        NestedPageConfig.shared.applyConfig(to: self)
    }
}

// MARK: - NestedPageViewControllerDataSource

extension IncludeTabBarViewController: NestedPageViewControllerDataSource {
    
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

//
//  ScrollsToTopViewController.swift
//  NestedPageExample
//
//  Created by 乐升平 on 2025/9/3.
//

import UIKit
import NestedPageViewController

class ScrollsToTopViewController: UIViewController {
    
    // MARK: - Properties
    
    private var nestedPageViewController = NestedPageViewController()
    private var coverView: UIView = UIView()
    private var coverBgImageView: UIImageView = UIImageView()
    
    // MARK: - View Controllers
    
    private let childControllerTitles = ["作品", "推荐", "收藏", "喜欢"]
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        self.title = nil
        // 添加导航栏右侧按钮
        let scrollToTopButton = UIBarButtonItem(title: "滚到顶部", style: .plain, target: self, action: #selector(scrollToTopButtonTapped))
        navigationItem.rightBarButtonItem = scrollToTopButton
        
        let _ = createCoverView()
        setupNestedPageViewController()
    }
    
    @objc private func scrollToTopButtonTapped() {
        self.nestedPageViewController.scrollToTop(animated: true)
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
        
    private func createCoverView() -> UIView {
        let customCoverView = ProfileCoverView(frame: .zero)
                
        coverView = customCoverView
        coverBgImageView = customCoverView.bgImageView
        return customCoverView
    }
}

// MARK: - NestedPageViewControllerDataSource

extension ScrollsToTopViewController: NestedPageViewControllerDataSource {
    
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

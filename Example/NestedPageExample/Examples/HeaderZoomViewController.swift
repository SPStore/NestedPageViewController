//
//  HeaderZoomViewController.swift
//  NestedPageViewController
//
//  Created by 乐升平 on 2025/8/28.
//

import UIKit
import NestedPageViewController

class HeaderZoomViewController: UIViewController {
    
    // MARK: - Properties
    
    private var nestedPageViewController = NestedPageViewController()
    private var coverView: UIView = ProfileCoverView(frame: .zero)
    private var customNavigationBar = UIView()
    private var navigationContentView = UIView()
    private var backButton = UIButton(type: .system)
    
    // MARK: - View Controllers
    
    private let childControllerTitles = ["作品", "推荐", "收藏", "喜欢"]
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        setupNestedPageViewController()
        
        setupCustomNavigationBar()
        setupBackButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 隐藏系统导航栏
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 恢复系统导航栏
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - Setup
    
    private func setupCustomNavigationBar() {
        
        customNavigationBar.backgroundColor = .systemBackground
        customNavigationBar.alpha = 0.0
        view.addSubview(customNavigationBar)
        
        navigationContentView.backgroundColor = .clear
        customNavigationBar.addSubview(navigationContentView)
        
        // 创建标题标签
        let titleLabel = UILabel()
        titleLabel.text = self.title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
        titleLabel.textColor = .label
        navigationContentView.addSubview(titleLabel)
        
        // 使用frame布局
        layoutCustomNavigationBar()
    }
    
    private func layoutCustomNavigationBar() {
        let safeAreaTop = view.safeAreaInsets.top
        let navBarHeight: CGFloat = 44
        let totalNavBarHeight = safeAreaTop + navBarHeight
        
        // 设置导航栏容器frame（从屏幕顶部开始）
        customNavigationBar.frame = CGRect(
            x: 0,
            y: 0,
            width: view.bounds.width,
            height: totalNavBarHeight
        )
        
        // 设置导航内容视图frame（考虑安全区域）
        navigationContentView.frame = CGRect(
            x: 0,
            y: safeAreaTop,
            width: view.bounds.width,
            height: navBarHeight
        )
        
        // 获取标题标签
        guard let titleLabel = navigationContentView.subviews.first(where: { $0 is UILabel }) as? UILabel else {
            return
        }
        
        // 设置标题标签frame（相对于navigationContentView）
        titleLabel.sizeToFit()
        titleLabel.frame = CGRect(
            x: (view.bounds.width - titleLabel.frame.width) / 2,
            y: (navBarHeight - titleLabel.frame.height) / 2,
            width: titleLabel.frame.width,
            height: titleLabel.frame.height
        )
    }

    private func setupBackButton() {
        // 创建固定的返回按钮，样式与原导航栏按钮完全一致
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .systemBlue
        backButton.backgroundColor = .clear
        backButton.contentHorizontalAlignment = .leading
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        // 直接添加到控制器的view上，确保始终可见
        view.addSubview(backButton)
    }

    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setupNestedPageViewController() {
        nestedPageViewController.dataSource = self
        nestedPageViewController.delegate = self
                                
        // 应用全局配置
        NestedPageConfig.shared.applyConfig(to: nestedPageViewController)
        
        addChild(nestedPageViewController)
        view.addSubview(nestedPageViewController.view)
        nestedPageViewController.didMove(toParent: self)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
                
        // 更新自定义导航栏布局
        layoutCustomNavigationBar()
        
        // 更新返回按钮布局
        layoutBackButton()
        
        // 更新NestedPageViewController的frame，需要考虑自定义导航栏的高度
        nestedPageViewController.view.frame = CGRect(
            x: 0,
            y: 0,
            width: view.bounds.width,
            height: view.bounds.height
        )
        
        let safeAreaTop = view.safeAreaInsets.top
        let navBarHeight: CGFloat = 44
        // 调整吸顶位置偏移，由于nestedPageViewController.view是全屏的，默认只有到达屏幕最顶端才会吸顶，这里设置吸顶位置在导航栏的下方
        nestedPageViewController.stickyOffset = safeAreaTop + navBarHeight
    }
    
    private func layoutBackButton() {
        let safeAreaTop = view.safeAreaInsets.top
        let navBarHeight: CGFloat = 44
              
        let buttonWidth = 40.0
        let buttonHeight = 30.0
        // 设置位置与原导航栏中的返回按钮完全一致
        backButton.frame = CGRect(
            x: 16,
            y: safeAreaTop + (navBarHeight - buttonHeight) / 2,
            width: buttonWidth,
            height: buttonHeight
        )
    }
}

// MARK: - NestedPageViewControllerDataSource

extension HeaderZoomViewController: NestedPageViewControllerDataSource {
    
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

// MARK: - NestedPageViewControllerDelegate

extension HeaderZoomViewController: NestedPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: NestedPageViewController, didScrollToPageAt index: Int) {
        print("切换到第 \(index) 页")
    }
    
    func pageViewController(_ pageViewController: NestedPageViewController,
                            contentScrollViewDidScroll scrollView: UIScrollView,
                            headerOffset: CGFloat,
                            isSticked: Bool) {
        if let coverView = self.coverView as? ProfileCoverView {
                        
            let coverHeight = heightForCoverView(in: nestedPageViewController)
            let tabHeight = heightForTabStrip(in: nestedPageViewController)
            let headerHeight = coverHeight + tabHeight
            
            // bgImageView的y值，抵消scrollView偏移
            var frame = coverView.frame
            // -scrollView.contentOffset.y - tabHeight：表示的是scrollView顶部，到tab的顶部之间的距离
            frame.size.height = max(-scrollView.contentOffset.y - tabHeight, coverHeight)
            frame.origin.y = min(headerOffset, 0)
            // 细节：这里不要直接设置bgImageView.frame = frame，计算bgImageView.frame交给coverView的layoutSubviews去做，如果这里计算，会再次触发coverView的layoutSubviews，最终这里设置的frame被覆盖。
            coverView.bgImageViewFrame = frame
            
            let scrollDistance = headerHeight - customNavigationBar.frame.height - tabHeight
            customNavigationBar.alpha = min(max(headerOffset / scrollDistance, 0.0), 1.0)
        }
    }
    

}

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
    private var lastPageSize = CGSize.zero
    private var coverView: UIView = ProfileCoverView(frame: .zero)
    private var lastNavigationProgress: CGFloat?
    
    // MARK: - View Controllers
    
    private let childControllerTitles = ["作品", "推荐", "收藏", "喜欢"]
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        // 导航栏背景变为不透明时，封面仍延伸到屏幕顶部。
        extendedLayoutIncludesOpaqueBars = true
        setupNavigationBar()
        setupNestedPageViewController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - Setup
    
    private func setupNavigationBar() {
        navigationItem.largeTitleDisplayMode = .never
        updateNavigationBar(progress: 0)
    }

    private func updateNavigationBar(progress: CGFloat) {
        let progress = min(max(progress, 0), 1)
        guard progress != lastNavigationProgress else { return }
        lastNavigationProgress = progress
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(progress)
        // 系统会在转场中调整 titleView.alpha，使用标题外观颜色控制渐显。
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label.withAlphaComponent(progress)]
        // 配置到当前页面的 navigationItem，返回其他页面时由系统恢复其外观。
        // 各状态保持一致，避免系统的滚动边缘切换打断连续渐变。
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        navigationItem.compactScrollEdgeAppearance = appearance
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = nestedPageViewController.view.bounds.size
        let stickyOffset: CGFloat
        if let navigationBar = navigationController?.navigationBar {
            stickyOffset = max(0, navigationBar.convert(navigationBar.bounds, to: nestedPageViewController.view).maxY)
        } else {
            stickyOffset = view.safeAreaInsets.top
        }
        guard size != lastPageSize || nestedPageViewController.stickyOffset != stickyOffset else { return }
        lastPageSize = size
        // 系统导航栏高度会随设备和布局变化，吸顶位置使用实际坐标。
        nestedPageViewController.stickyOffset = stickyOffset
        if nestedPageViewController.viewController(at: nestedPageViewController.currentIndex) != nil {
            nestedPageViewController.updateLayouts()
        }
    }

    private func setupNestedPageViewController() {
        nestedPageViewController.dataSource = self
        nestedPageViewController.delegate = self
                                
        // 应用全局配置
        NestedPageConfig.shared.applyConfig(to: nestedPageViewController)
        nestedPageViewController.stickyOffset = view.safeAreaInsets.top
        if #available(iOS 26.0, *) {
            nestedPageViewController.containerScrollView.topEdgeEffect.isHidden = true
        }
        
        addChild(nestedPageViewController)
        view.addSubview(nestedPageViewController.view)
        nestedPageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            // 缩放封面延伸到屏幕顶部，其余三边仍遵守安全区。
            nestedPageViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            nestedPageViewController.view.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            nestedPageViewController.view.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            nestedPageViewController.view.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
        ])
        nestedPageViewController.didMove(toParent: self)
    }
}

// MARK: - NestedPageViewControllerDataSource

extension HeaderZoomViewController: NestedPageViewControllerDataSource {
    
    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int {
        return childControllerTitles.count
    }
    
    func pageViewController(_ pageViewController: NestedPageViewController, viewControllerAt index: Int) -> NestedPageScrollable? {
        guard index >= 0 && index < childControllerTitles.count else { return nil }
        
        let controller: ChildBaseViewController & NestedPageScrollable
        switch index {
        case 0:
            controller = PostsViewController()
        case 1:
            controller = LikesViewController()
        case 2:
            controller = FavoritesViewController()
        case 3:
            controller = RecommendsViewController()
        default:
            return nil
        }
        // 封面挂在子列表上，子列表也必须从顶部开始，避免再次留出安全区。
        controller.usesTopSafeArea = false
        if #available(iOS 26.0, *) {
            // 背景渐变由本页驱动，避免系统滚动边缘模糊提前遮住封面。
            controller.nestedPageContentScrollView.topEdgeEffect.isHidden = true
        }
        return controller
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
            
            let scrollDistance = max(1, headerHeight - nestedPageViewController.stickyOffset - tabHeight)
            updateNavigationBar(progress: headerOffset / scrollDistance)
        }
    }
    

}

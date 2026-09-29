//
//  CustomTabStripViewController2.swift
//  NestedPageExample
//
//  Created by 乐升平 on 2025/9/4.
//

import UIKit
import NestedPageViewController
import JXCategoryView

class CustomTabStripViewController2: UIViewController {
    
    // MARK: - Properties
    
    private var nestedPageViewController = NestedPageViewController()
    private var lastPageSize = CGSize.zero
    private var coverView = UIView()
    private var coverBgImageView = UIImageView()
    private var categoryView = JXCategoryTitleView()
    
    // MARK: - View Controllers
    
    private let childControllerTitles = ["热点", "电影", "电视剧", "汽车", "动漫", "游戏", "科技", "体育", "知识", "少儿", "综艺"]
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        categoryView.titles = childControllerTitles
        categoryView.backgroundColor = .white
        categoryView.titleSelectedColor = .orange
        categoryView.titleColor = .black
        categoryView.isTitleColorGradientEnabled = true
        categoryView.isTitleLabelZoomEnabled = true
        categoryView.isAverageCellSpacingEnabled = false
        categoryView.cellSpacing = 30
        categoryView.titleFont = UIFont.systemFont(ofSize: 15)
        categoryView.isContentScrollViewClickTransitionAnimationEnabled = true

        let lineView = JXCategoryIndicatorLineView()
        lineView.indicatorColor = .orange
        lineView.indicatorWidth = 10
        lineView.verticalMargin = 4
        lineView.lineStyle = .lengthenOffset

        categoryView.indicators = [lineView]
        
        let _ = createCoverView()
        setupNestedPageViewController()
        
        categoryView.contentScrollView = nestedPageViewController.containerScrollView
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
    
        
    private func createCoverView() -> UIView {
        let customCoverView = ProfileCoverView(frame: .zero)
                
        coverView = customCoverView
        coverBgImageView = customCoverView.bgImageView
        return customCoverView
    }
}

// MARK: - NestedPageViewControllerDataSource

extension CustomTabStripViewController2: NestedPageViewControllerDataSource {
    
    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int {
        return childControllerTitles.count
    }
    
    func pageViewController(_ pageViewController: NestedPageViewController, viewControllerAt index: Int) -> NestedPageScrollable? {
        guard index >= 0 && index < childControllerTitles.count else { return nil }
        
        let title = childControllerTitles[index]
        let controller = DefaultListViewController()
        controller.title = title
        return controller
    }
    
    func coverView(in pageViewController: NestedPageViewController) -> UIView? {
        return coverView
    }
    
    func heightForCoverView(in pageViewController: NestedPageViewController) -> CGFloat {
        return 260.0
    }
    
    func tabStrip(in pageViewController: NestedPageViewController) -> UIView? {
        return categoryView  // 使用内置的标签栏
    }
    
    func heightForTabStrip(in pageViewController: NestedPageViewController) -> CGFloat {
        return 40.0
    }
}

// MARK: - NestedPageViewControllerDelegate

extension CustomTabStripViewController2: NestedPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: NestedPageViewController, didScrollToPageAt index: Int) {

    }
}

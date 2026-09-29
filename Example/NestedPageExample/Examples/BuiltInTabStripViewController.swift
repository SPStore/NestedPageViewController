//
//  BuiltInTabStripViewController.swift
//  NestedPageExample
//
//  Created by 乐升平 on 2025/9/6.
//

import UIKit
import NestedPageViewController

class BuiltInTabStripViewController: UIViewController {
    
    // MARK: - Properties
    
    private var nestedPageViewController = NestedPageViewController()
    private var lastPageSize = CGSize.zero
    private var coverView: UIView = ProfileCoverView(frame: .zero)
    private lazy var tabStripView: NestedPageTabStripView = {
        // 创建标签栏配置
        var tabStripConfig = NestedPageTabStripConfiguration()
        tabStripConfig.titles = childControllerTitles
        tabStripConfig.titleColor = .gray
        tabStripConfig.titleSelectedColor = .systemBlue
        tabStripConfig.titleFont = .systemFont(ofSize: 16, weight: .medium)
        tabStripConfig.backgroundColor = .systemBackground
        tabStripConfig.contentEdgeInsets = UIEdgeInsets(top: 0, left: 50, bottom: 0, right: 50)
        tabStripConfig.indicatorColor = .systemYellow
        tabStripConfig.indicatorSize = CGSize(width: 50, height: 30)
        tabStripConfig.indicatorSizeCornerRadius = 15
        tabStripConfig.indicatorVerticalMargin = 5
                
        // 创建标签栏
        tabStripView = NestedPageTabStripView(configuration: tabStripConfig)
        return tabStripView
    }()
    
    // MARK: - View Controllers
    
    private let childControllerTitles = ["作品", "收藏", "喜欢"]
    
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

extension BuiltInTabStripViewController: NestedPageViewControllerDataSource {
    
    // MARK: - NestedPageViewControllerDataSource
    
    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int {
        return childControllerTitles.count
    }
    
    func pageViewController(_ pageViewController: NestedPageViewController, viewControllerAt index: Int) -> NestedPageScrollable? {
        guard index >= 0 && index < childControllerTitles.count else { return nil }
        
        switch index {
        case 0:
            return PostsViewController()
        case 1:
            return RecommendsViewController()
        case 2:
            return FavoritesViewController()
        case 3:
            return LikesViewController()
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
        // 将tabStripView与NestedPageViewController的containerScrollView关联，实现联动
        tabStripView.linkedScrollView = pageViewController.containerScrollView
        return tabStripView
    }
    
    func heightForTabStrip(in pageViewController: NestedPageViewController) -> CGFloat {
        return 40.0
    }
    
    func titlesForTabStrip(in pageViewController: NestedPageViewController) -> [String]? {
        return nil  // 由于我们自己创建了tabStripView，这里返回nil
    }
}

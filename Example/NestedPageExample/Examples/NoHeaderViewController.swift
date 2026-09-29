//
//  NoHeaderViewController.swift
//  NestedPageExample
//
//  Created by 乐升平 on 2025/9/25.
//

import UIKit
import NestedPageViewController

class NoHeaderViewController: UIViewController {
    
    // MARK: - Properties
    
    private var nestedPageViewController = NestedPageViewController()
    private var lastPageSize = CGSize.zero
    
    private lazy var tabStripView: NestedPageTabStripView = {
        var config = NestedPageTabStripConfiguration()
        config.titles = ["作品", "推荐"]
        config.titleColor = .secondaryLabel
        config.titleFont = .boldSystemFont(ofSize: 17)
        config.titleSelectedColor = .label
        config.indicatorSize = CGSize(width: 20, height: 3)
        config.spacing = 20
        let tabStripView = NestedPageTabStripView(configuration: config)
        return tabStripView
    }()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.titleView = self.tabStripView
        view.backgroundColor = .systemBackground
                
        setupNestedPageViewController()
        
        tabStripView.linkedScrollView = nestedPageViewController.containerScrollView
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
        // 默认展示第2页
        nestedPageViewController.defaultPageIndex = 1
        
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

extension NoHeaderViewController: NestedPageViewControllerDataSource {
    
    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int {
        return 2
    }
    
    func pageViewController(_ pageViewController: NestedPageViewController, viewControllerAt index: Int) -> NestedPageScrollable? {
        switch index {
        case 0:
            let vc = DefaultListViewController()
            vc.title = tabStripView.configuration.titles[0]
            return vc
        case 1:
            let vc = DefaultListViewController()
            vc.title = tabStripView.configuration.titles[1]
            return vc
        default:
            return nil
        }
    }
    
    func pageViewController(_ pageViewController: NestedPageViewController, shouldPreloadViewControllerAt index: Int) -> Bool {
        return true
    }
}

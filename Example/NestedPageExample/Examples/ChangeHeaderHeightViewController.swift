//
//  ChangeHeaderHeightViewController.swift
//  NestedPageExample
//
//  Created by 乐升平 on 2025/9/26.
//

import UIKit
import NestedPageViewController

class ChangeHeaderHeightViewController: UIViewController {
    
    // MARK: - Properties
    
    var tabStripHeight = 40.0
    var coverViewHeight: CGFloat {
        return customCoverView.contentHeight
    }
    
    private var nestedPageViewController = NestedPageViewController()
    private var customCoverView = CustomCoverView(frame: .zero)
    private var coverView: UIView { return customCoverView }
    private lazy var tabStripView: NestedPageTabStripView = {
        // 创建标签栏配置
        var tabStripConfig = NestedPageTabStripConfiguration()
        tabStripConfig.titles = childControllerTitles
        tabStripConfig.titleColor = .gray
        tabStripConfig.titleSelectedColor = .systemBlue
        tabStripConfig.titleFont = .systemFont(ofSize: 16, weight: .medium)
        tabStripConfig.backgroundColor = .systemBackground
        tabStripConfig.indicatorSize = CGSize(width: 50, height: 3)
                
        // 创建标签栏
        let view = NestedPageTabStripView(configuration: tabStripConfig)
        return view
    }()
    
    // MARK: - View Controllers
    
    private let childControllerTitles = ["作品", "推荐", "收藏", "喜欢"]
    
    // MARK: - Lifecycle

override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        setupNestedPageViewController()
        
        self.tabStripView.linkedScrollView = nestedPageViewController.containerScrollView
        
        // 添加导航栏右侧按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "增高",
            style: .plain,
            target: self,
            action: #selector(changeCoverHeight)
        )
    }
    
    @objc private func changeCoverHeight() {
        // 切换数据源个数，在5和10之间切换
        let newCount = customCoverView.itemCount == 5 ? 10 : 5
        customCoverView.itemCount = newCount
        
        // 更新按钮标题
        let buttonTitle = newCount == 10 ? "恢复" : "增高"
        navigationItem.rightBarButtonItem?.title = buttonTitle
        
        performHeightChange(true)
    }
    
    private func performHeightChange(_ animated: Bool) {
        
        if animated {
            // 不能用reloadData，否则tableView的数据源刷新和updateLayouts动画不会同步，恢复高度时tableView底部会有一段留白
            customCoverView.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)

            customCoverView.layoutIfNeeded()
            
            UIView.animate(withDuration: 0.25) {
                self.nestedPageViewController.updateLayouts()
            }
        } else {
            customCoverView.tableView.reloadData()
            customCoverView.layoutIfNeeded()
            self.nestedPageViewController.updateLayouts()
        }
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

extension ChangeHeaderHeightViewController: NestedPageViewControllerDataSource {
    
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
        return coverViewHeight
    }
    
    func tabStrip(in pageViewController: NestedPageViewController) -> UIView? {
        return self.tabStripView
    }
    
    func heightForTabStrip(in pageViewController: NestedPageViewController) -> CGFloat {
        return tabStripHeight
    }
}

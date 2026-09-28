//
//  NestedPageChildManager.swift
//  NestedPageViewController
//
//  Created by 乐升平 on 2023/8/22.
//  Copyright © 2023 SPStore. All rights reserved.
//

import UIKit

/// 嵌套页面子控制器管理器，负责管理子控制器的创建、加载和生命周期管理
class NestedPageChildManager {
        
    weak var viewController: NestedPageViewController?
    weak var headerManager: NestedPageHeaderManager?
    weak var scrollCoordinator: NestedPageScrollCoordinator?
    
    /// 当前显示的子控制器索引
    var currentIndex: Int = 0
    
    var viewControllerMap: [Int: UIViewController & NestedPageScrollable] = [:]
    
    var currentContentScrollView: UIScrollView?

    var contentScrollViewY: CGFloat {
        if let currentContentScrollView {
            let contentScrollViewY = currentContentScrollView.convert(currentContentScrollView.bounds, to: viewController?.containerView).minY
            return contentScrollViewY
        }
        return 0.0
    }
        
    init(viewController: NestedPageViewController?, headerManager: NestedPageHeaderManager) {
        self.viewController = viewController
        self.headerManager = headerManager
    }
    
    // MARK: - ViewController Management
    
    func viewController(at index: Int) -> NestedPageScrollable? {
        return viewControllerMap[index]
    }
    
    @discardableResult
    func loadViewController(at index: Int) -> Bool {
        guard let viewController = viewController,
              let dataSource = viewController.dataSource,
              let headerManager = headerManager,
              let scrollCoordinator = scrollCoordinator,
              index >= 0 && index < dataSource.numberOfViewControllers(in: viewController) else {
            return false
        }
        
        var childViewController = self.viewController(at: index)
        if childViewController == nil {
            childViewController = dataSource.pageViewController(viewController, viewControllerAt: index)
            guard let childViewController = childViewController else { return false }
            
            viewController.addChild(childViewController)
            childViewController.view.frame = CGRect(x: CGFloat(index) * viewController.view.bounds.width, y: 0, width: viewController.containerScrollView.bounds.width, height: viewController.containerScrollView.bounds.height)
            childViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            viewController.containerScrollView.addSubview(childViewController.view)
            childViewController.didMove(toParent: viewController)
            
            // 保证先走viewDidLoad，再获取contentScrollView，contentScrollView可能在viewDidLoad中才初始化
            let contentScrollView = childViewController.nestedPageContentScrollView
            scrollCoordinator.observeScrollView(contentScrollView)
            contentScrollView.contentInsetAdjustmentBehavior = .never
            contentScrollView.showsVerticalScrollIndicator = viewController.showsVerticalScrollIndicator
            contentScrollView.showsHorizontalScrollIndicator = false
            contentScrollView.bounces = viewController.bounces
            headerManager.createAndAddPageHeader(at: index, contentScrollView: contentScrollView)
            
            // interactivePopGestureRecognizer和contentScrollView手势共存的情况下，防止侧滑返回时，contentScrollView同时能垂直滑动
            if let interactivePopGestureRecognizer =  viewController.navigationController?.interactivePopGestureRecognizer {
                contentScrollView.panGestureRecognizer.require(toFail: interactivePopGestureRecognizer)
            }
            
            viewControllerMap[index] = childViewController

            childViewController.view.setNeedsLayout()
            childViewController.view.layoutIfNeeded()
            
            // 外部可能想要设置自己的inset.bottom，如果外部设置的inset.bottom比安全区域还大，就保持外部设置的
            scrollCoordinator.updateContentInsets(for: contentScrollView)
            
            let initialOffsetY = scrollCoordinator.initialContentOffsetY(for: contentScrollView)
            contentScrollView.setContentOffset(CGPoint(x: 0, y: initialOffsetY), animated: false)
            return true
        }
        return false
    }
    
    @discardableResult
    func unloadViewController(at index: Int) -> Bool {
        // 不允许移除当前显示的控制器
        guard viewController(at: index) != nil else {
            return false
        }
        
        // 移除视图控制器
        if let childViewController = viewController(at: index) {
            removeChildViewController(childViewController)
            viewControllerMap.removeValue(forKey: index)
            
            headerManager?.removePageHeader(at: index)
            
            return true
        }
        
        return false
    }
    
    func loadViewControllers(at indexes: [Int]) {
        guard !indexes.isEmpty else { return }
        
        for index in indexes {
            loadViewController(at: index)
        }
    }
    
    func loadViewControllers() {
        guard let viewController = viewController,
              let dataSource = viewController.dataSource else { return }
        
        currentIndex = viewController.defaultPageIndex
        
        let count = dataSource.numberOfViewControllers(in: viewController)
        
        // 预加载需要预加载的视图控制器
        var pagesToPreload: [Int] = []
        
        // 首先添加当前页面索引，确保优先加载
        pagesToPreload.append(currentIndex)
        
        for index in 0..<count {
            if index != currentIndex && dataSource.pageViewController(viewController, shouldPreloadViewControllerAt: index) {
                pagesToPreload.append(index)
            }
        }
        
        // 加载所有需要预加载的页面
        if !pagesToPreload.isEmpty {
            loadViewControllers(at: pagesToPreload)
        }
        
        // 确保首次进入页面时currentContentScrollView有值
        if let childViewController = self.viewController(at: currentIndex) {
            currentContentScrollView = childViewController.nestedPageContentScrollView
        }
    }
    
    // MARK: - Layout Update
    
    func updateChildrenLayouts() {
        guard let viewController = viewController,
              let headerManager = headerManager else { return }
        
        let viewWidth = viewController.containerScrollView.bounds.width
        let viewHeight = viewController.containerScrollView.bounds.height
        
        // 遍历所有已加载的视图控制器，重置其scrollView
        for (index, childViewController) in viewControllerMap {
            childViewController.view.frame = CGRect(x: CGFloat(index) * viewWidth, y: 0, width: viewWidth, height: viewHeight)
            // 重置子视图控制器的视图状态
            childViewController.view.setNeedsLayout()
            childViewController.view.layoutIfNeeded()
            
            let contentScrollView = childViewController.nestedPageContentScrollView
            // 更新contentInset
            scrollCoordinator?.updateContentInsets(for: contentScrollView)
            
            // 重置contentOffset到初始位置（顶部）
            contentScrollView.setContentOffset(CGPoint(x: 0, y: -headerManager.pageHeaderHeight), animated: false)
        }
    }
    
    // MARK: - Reload
    
    func rebuildPages() {
        
        // 保存当前索引
        let currentIdx = currentIndex
        
        // 获取已加载的视图控制器索引
        let loadedIndexes = Array(viewControllerMap.keys)
        
        // 清理视图控制器
        for childViewController in viewControllerMap.values {
            removeChildViewController(childViewController)
        }
        viewControllerMap.removeAll()
        
        // 重新加载之前加载过的视图控制器
        loadViewControllers(at: loadedIndexes)
        
        // 恢复当前索引
        currentIndex = currentIdx
        if let childViewController = self.viewController(at: currentIdx) {
            currentContentScrollView = childViewController.nestedPageContentScrollView
        }
    }

    // MARK: - Cleanup
    
    func cleanupOldData() {
        currentContentScrollView = nil
        for childViewController in viewControllerMap.values {
            removeChildViewController(childViewController)
        }
        viewControllerMap.removeAll()
    }
    
    func removeChildViewController(_ child: UIViewController) {
        if let child = child as? NestedPageScrollable {
            scrollCoordinator?.stopObserving(child.nestedPageContentScrollView)
        }
        child.willMove(toParent: nil)
        child.view.removeFromSuperview()
        child.removeFromParent()
    }
}

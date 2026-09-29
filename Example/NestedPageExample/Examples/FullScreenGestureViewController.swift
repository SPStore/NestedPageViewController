//
//  FullScreenGestureViewController.swift
//  NestedPageExample
//
//  Created by 乐升平 on 2025/9/1.
//

import UIKit
import NestedPageViewController
import FDFullscreenPopGesture

class FullScreenGestureViewController: UIViewController {
    
    // MARK: - Properties
    
    private var nestedPageViewController = NestedPageViewController()
    private var coverView: UIView = ProfileCoverView(frame: .zero)
    
    // MARK: - View Controllers
    
    private let childControllerTitles = ["作品", "推荐", "收藏", "喜欢"]
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        setupNestedPageViewController()
        
        navigationController?.fd_fullscreenPopGestureRecognizer.delegate = self
    }
    
    // MARK: - Setup

    private func setupNestedPageViewController() {
        nestedPageViewController.dataSource = self
        nestedPageViewController.delegate = self
        
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

extension FullScreenGestureViewController: NestedPageViewControllerDataSource {
    
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

extension FullScreenGestureViewController: NestedPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: NestedPageViewController, didScrollToPageAt index: Int) {

    }
}

extension FullScreenGestureViewController: UIGestureRecognizerDelegate {
    
    /**
     shouldRequireFailureOf 与 shouldBeRequiredToFailBy的核心区别：

     shouldRequireFailureOf：
     从 gestureRecognizer 的角度 出发，
     表示 “我是不是要等对方失败？”

     shouldBeRequiredToFailBy：
     从 otherGestureRecognizer 的角度 出发，
     表示 “对方是不是要求我失败？”
     
     可以看到：不管哪个方法，返回 true 就是 other 优先，返回 false 就是 gestureRecognizer 优先。
     区别只在于“谁是主语”。
     */
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let translationX = pan.translation(in: pan.view).x
            if nestedPageViewController.currentIndex == 0 {
                if translationX > 0 {
                    // 向右滑：允许触发全屏返回
                    return true
                } else {
                    // 向左滑：让 scrollView 处理翻页
                    return false
                }
            }
        }
        
        let currentPoint = gestureRecognizer.location(in: coverView)
        // 手指触摸在头部，启用全屏返回
        if CGRectContainsPoint(coverView.bounds, currentPoint) {
            return true
        }
        return false
    }


}

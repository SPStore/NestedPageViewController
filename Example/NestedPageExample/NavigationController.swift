//
//  NavigationController.swift
//  NestedPageExample
//
//  Created by 乐升平 on 2025/9/1.
//

import UIKit

class NavigationController: UINavigationController, UIGestureRecognizerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        // 统一返回按钮和导航栏操作按钮，浅色为黑色，深色模式自动适配。
        navigationBar.tintColor = .label

        // 如果隐藏了系统导航栏，默认是不会再有测滑手势的，这里设置代理，就可以在即便隐藏导航栏的情况下，也能启用测滑手势
        interactivePopGestureRecognizer?.delegate = self
    }
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        
        // 全局禁用全屏返回，恢复系统边缘返回
        fd_fullscreenPopGestureRecognizer.isEnabled = false
        interactivePopGestureRecognizer?.isEnabled = true
        
        // FullScreenGestureViewController启用全屏返回
        if viewController is FullScreenGestureViewController {
            fd_fullscreenPopGestureRecognizer.isEnabled = true
            interactivePopGestureRecognizer?.isEnabled = false
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.viewControllers.count > 1
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
//    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        if otherGestureRecognizer.view is UIScrollView {
//            return true
//        }
//        return false
//    }
}

//
//  MainTabBarController.swift
//  NestedPageViewController
//
//  Created by 乐升平 on 2025/1/25.
//  Copyright © 2025 SPStore. All rights reserved.
//

import UIKit

class TabBarController: UITabBarController {
    private(set) lazy var exampleNavigationController = NavigationController(rootViewController: ExampleListViewController())
    private lazy var settingsNavigationController = NavigationController(rootViewController: SettingsViewController())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
        setupAppearance()
    }
    
    private func setupTabBar() {
        // 创建示例列表导航控制器
        exampleNavigationController.tabBarItem = UITabBarItem(
            title: "示例",
            image: UIImage(systemName: "list.bullet"),
            selectedImage: UIImage(systemName: "list.bullet.circle.fill")
        )
        
        // 创建设置页面导航控制器
        settingsNavigationController.tabBarItem = UITabBarItem(
            title: "设置",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )
        
        if #available(iOS 18.0, *) {
            // 用系统 Tab 模型表达入口，由 UIKit 适配底栏、侧栏和折叠屏竖栏。
            let exampleTab = makeTab(identifier: "examples", navigationController: exampleNavigationController)
            let settingsTab = makeTab(identifier: "settings", navigationController: settingsNavigationController)
            tabs = [exampleTab, settingsTab]
            selectedTab = exampleTab
        } else {
            viewControllers = [exampleNavigationController, settingsNavigationController]
            selectedIndex = 0
        }
    }

    @available(iOS 18.0, *)
    private func makeTab(identifier: String, navigationController: NavigationController) -> UITab {
        let item = navigationController.tabBarItem!
        let tab = UITab(title: item.title ?? "", image: item.image, identifier: identifier) { _ in
            navigationController
        }
        if #available(iOS 26.1, *) {
            tab.selectedImage = item.selectedImage
        }
        return tab
    }

    private func setupAppearance() {
        let appearance = UITabBarAppearance()
        if #available(iOS 26.0, *) {
            // 与 GoScanner 保持一致：玻璃容器由系统绘制，外层背景保持透明。
            appearance.configureWithTransparentBackground()
            tabBar.backgroundColor = .clear
            tabBar.isTranslucent = true
        } else {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .systemBackground
            tabBar.isTranslucent = false
        }
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = .systemBlue
    }
}

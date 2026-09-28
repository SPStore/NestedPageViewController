//
//  ExampleTypeModel.swift
//  NestedPageViewController
//
//  Created by 乐升平 on 2025/8/24.
//

import UIKit

enum CSActionType {
    case push
    case present
}

// 示例分组
struct ExampleGroup {
    var title: String
    var examples: [ExampleTypeModel]
    
    init(title: String, examples: [ExampleTypeModel]) {
        self.title = title
        self.examples = examples
    }
}

class ExampleTypeModel {
    var title: String
    var targetClass: UIViewController.Type
    var detailTitle: String?
    var action: CSActionType = .push
    
    init(title: String, targetClass: UIViewController.Type) {
        self.title = title
        self.targetClass = targetClass
    }
    
    static func model(title: String, targetClass: UIViewController.Type) -> ExampleTypeModel {
        return ExampleTypeModel(title: title, targetClass: targetClass)
    }
    
    // 返回所有示例（不分组，兼容旧代码）
    static func demoTypeList() -> [ExampleTypeModel] {
        var array: [ExampleTypeModel] = []
        
        // 获取分组数据
        let groups = demoGroups()
        
        // 将所有分组的示例合并到一个数组中
        for group in groups {
            array.append(contentsOf: group.examples)
        }
        
        return array
    }
    
    // 返回分组后的示例数据
    static func demoGroups() -> [ExampleGroup] {
        // 基础示例组
        let standardVC = ExampleTypeModel.model(title: "默认", targetClass: StandardViewController.self)
        let headerZoomVC = ExampleTypeModel.model(title: "头部缩放 + 导航栏隐藏（常见）", targetClass: HeaderZoomViewController.self)
        let partialRefreshVC = ExampleTypeModel.model(title: "局部下拉刷新", targetClass: PartialRefreshViewController.self)
        let globalRefreshVC = ExampleTypeModel.model(title: "全局下拉刷新", targetClass: GlobalRefreshViewController.self)
        let fixedHeaderVC = ExampleTypeModel.model(title: "头部始终固定不动", targetClass: FixedHeaderViewController.self)
        let scrollsToTopVC = ExampleTypeModel.model(title: "滚动到顶部", targetClass: ScrollsToTopViewController.self)
        let fullScreenGestureVC = ExampleTypeModel.model(title: "全屏返回手势", targetClass: FullScreenGestureViewController.self)
        let noBouncesVC = ExampleTypeModel.model(title: "无弹性效果", targetClass: NoBouncesViewController.self)
        noBouncesVC.detailTitle = "本示例采用继承方式"
        let includeTabBarVC = ExampleTypeModel.model(title: "显示底部tabBar", targetClass: IncludeTabBarViewController.self)
        includeTabBarVC.detailTitle = "本示例采用继承方式"
        let pinnedCollectionHeaderVC = ExampleTypeModel.model(title: "子VC的sectionHeader吸顶", targetClass: PinnedCollectionHeaderViewController.self)
        pinnedCollectionHeaderVC.detailTitle = "见第3个子vc中的collectionView的sectionHeader吸顶"
        let preloadVC = ExampleTypeModel.model(title: "预加载子视图控制器，默认选中第2个", targetClass: PreloadViewController.self)
        preloadVC.detailTitle = "无需等待页面切换结束才加载内容，减少了空白页面的等待时长"
        let changeHeaderHeightVC = ExampleTypeModel.model(title: "运行时修改头部高度", targetClass: ChangeHeaderHeightViewController.self)
        let shortContentVC = ExampleTypeModel.model(title: "短内容与反复切页回归", targetClass: ShortContentViewController.self)
        let noHeaderVc = ExampleTypeModel.model(title: "没有头部", targetClass: NoHeaderViewController.self)
        // 标签栏示例组
        let builtInTabStripVC = ExampleTypeModel.model(title: "简单定制内置tab栏", targetClass: BuiltInTabStripViewController.self)
        let customTabStripVC1 = ExampleTypeModel.model(title: "自定义tab栏1", targetClass: CustomTabStripViewController1.self)
        let customTabStripVC2 = ExampleTypeModel.model(title: "自定义tab栏2", targetClass: CustomTabStripViewController2.self)
        
        // OC示例组
        let ocExampleVC = ExampleTypeModel.model(title: "OC示例", targetClass: ObjcExmpleViewController.self)

        // 创建分组
        let basicGroup = ExampleGroup(title: "基础示例", examples: [
            standardVC,
            headerZoomVC,
            partialRefreshVC,
            globalRefreshVC,
            fixedHeaderVC,
            scrollsToTopVC,
            fullScreenGestureVC,
            noBouncesVC,
            includeTabBarVC,
            pinnedCollectionHeaderVC,
            changeHeaderHeightVC,
            shortContentVC,
            preloadVC,
            noHeaderVc,
        ])
        
        let tabStripGroup = ExampleGroup(title: "标签栏示例", examples: [
            builtInTabStripVC,
            customTabStripVC1,
            customTabStripVC2
        ])
        
        let ocGroup = ExampleGroup(title: "Objective-C 示例", examples: [
            ocExampleVC
        ])
        
        return [basicGroup, tabStripGroup, ocGroup]
    }
}

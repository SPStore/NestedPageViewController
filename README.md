<p align="center">
  <img src="https://raw.githubusercontent.com/SPStore/NestedPageViewController/master/Assets/NestedPageViewController_logo.png" title="NestedPageViewController logo" width="480">
</p>
<p align="center">
  一个用于iOS的嵌套页面视图控制器，提供平滑的滚动协调体验。
</p>
<p align="center">
  <a href="https://github.com/SPStore/NestedPageViewController"><img src="https://img.shields.io/badge/platform-iOS-blue.svg"></a>
  <a href="https://swift.org/"><img src="https://img.shields.io/badge/Swift-5.0-orange.svg"></a>
  <a href="https://developer.apple.com/ios/"><img src="https://img.shields.io/badge/iOS-13.0%2B-blue.svg"></a>
  <a href="https://github.com/SPStore/NestedPageViewController/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg"></a>
  <a href="https://cocoapods.org/pods/NestedPageViewController"><img src="https://img.shields.io/badge/pod-v2.0.0-brightgreen.svg"></a>
  <a href="https://swift.org/package-manager/"><img src="https://img.shields.io/badge/SPM-compatible-brightgreen.svg"></a>
</p>

## 功能特点

- [x] 支持头部视图、标签栏和多个子视图控制器
- [x] 支持内容滚动位置记录（该功能是设计本框架的最大动力来源）
- [x] 支持局部刷新和全局刷新
- [x] 支持子页面预加载（默认是滑动到指定页才加载）
- [x] 支持头部视图手指拖拽滚动并带动整体，可配置控制内容scrollView是否惯性滚动
- [x] 支持自定义标签栏
- [x] 支持旋转
- [x] 更多细节和功能请下载demo

## 功能演示

<table>
  <tr bgcolor="#f2f2f2">
    <td width="250" align="center"><strong>记录滚动位置</strong></td>
    <td width="250" align="center"><strong>局部刷新</strong></td>
    <td width="250" align="center"><strong>全局刷新</strong></td>
  </tr>
  <tr>
    <td><img src="https://github.com/SPStore/SPExmapleResurces/blob/main/NestedPageViewController/记录滚动位置.gif" width="250" alt="记录滚动位置"></td>
    <td><img src="https://github.com/SPStore/SPExmapleResurces/blob/main/NestedPageViewController/局部刷新.gif" width="250" alt="局部刷新"></td>
    <td><img src="https://github.com/SPStore/SPExmapleResurces/blob/main/NestedPageViewController/全局刷新.gif" width="250" alt="全局刷新"></td>
  </tr>
  <tr bgcolor="#f2f2f2">
    <td align="center"><strong>头部始终固定不动</strong></td>
    <td align="center"><strong>头部缩放+导航栏隐藏</strong></td>
    <td align="center"><strong>显示底部tabBar</strong></td>
  </tr>
  <tr>
    <td><img src="https://github.com/SPStore/SPExmapleResurces/blob/main/NestedPageViewController/头部始终固定不动.gif" width="250" alt="头部始终固定不动"></td>
    <td><img src="https://github.com/SPStore/SPExmapleResurces/blob/main/NestedPageViewController/头部缩放+隐藏导航栏.gif" width="250" alt="头部缩放+隐藏导航栏"></td>
    <td><img src="https://github.com/SPStore/SPExmapleResurces/blob/main/NestedPageViewController/显示系统tabBar.gif" width="250" alt="显示底部tabBar"></td>
  </tr>
    </tr>
    <tr bgcolor="#f2f2f2">
    <td align="center"><strong>子VC的sectionHeader吸顶</strong></td>
    <td align="center"><strong>运行时修改头部高度</strong></td>
    <td align="center"><strong>没有头部</strong></td>
  </tr>
  <tr>
    <td><img src="https://github.com/SPStore/SPExmapleResurces/blob/main/NestedPageViewController/子VC的sectionHeader吸顶.gif" width="250" alt="子VC的sectionHeader吸顶"></td>
    <td><img src="https://github.com/SPStore/SPExmapleResurces/blob/main/NestedPageViewController/运行时修改头部高度.gif" width="250" alt="运行时修改头部高度"></td>
    <td><img src="https://github.com/SPStore/SPExmapleResurces/blob/main/NestedPageViewController/没有头部.gif" width="250" alt="没有头部"></td>
  </tr>
  <tr bgcolor="#f2f2f2">
    <td align="center"><strong>滚到顶部</strong></td>
    <td align="center"><strong>自定义标签栏1</strong></td>
    <td align="center"><strong>自定义标签栏2</strong></td>
  </tr>
  <tr>
    <td><img src="https://github.com/SPStore/SPExmapleResurces/blob/main/NestedPageViewController/滚到顶部.gif" width="250" alt="滚到顶部"></td>
    <td><img src="https://github.com/SPStore/SPExmapleResurces/blob/main/NestedPageViewController/自定义标签栏1.gif" width="250" alt="自定义标签栏1"></td>
    <td><img src="https://github.com/SPStore/SPExmapleResurces/blob/main/NestedPageViewController/自定义标签栏2.gif" width="250" alt="自定义标签栏2"></td>
</table>

## 系统要求

- iOS 13.0+
- Swift 5.0+

## 安装

### Swift Package Manager

在Xcode中，选择 File > Swift Packages > Add Package Dependency，然后输入以下URL：

```
https://github.com/SPStore/NestedPageViewController.git
```

### CocoaPods

在你的Podfile中添加：

```ruby
pod 'NestedPageViewController'
```

然后运行：

```bash
pod install
```

注意：如果CocoaPods的方式安装，编译报错：Xcode error when building app: line 7: /resources-to-copy-Project.txt: Permission denied，或者其他类似权限问题，请在你的主工程中的Targets -> Build Settings -> User Script Sandboxing 改为No

## 使用方法

NestedPageViewController提供两种使用方式：添加子控制器方式和继承方式。

### 方式一：添加子控制器方式

```swift
import UIKit
import NestedPageViewController

class YourViewController: UIViewController {
    
    // MARK: - Properties
    
    private var nestedPageViewController = NestedPageViewController()
    private var coverView = YourHeaderView()
    private var customTabStrip = YourCustomTabStrip()
    
    // MARK: - View Controllers
    
    private let childControllerTitles = ["标签一", "标签二", "标签三", "标签四"]
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
                
        setupNestedPageViewController()
    }
    
    // MARK: - Setup
    
    private func setupNestedPageViewController() {
        nestedPageViewController.dataSource = self
        nestedPageViewController.delegate = self
        
        // 添加为子控制器
        addChild(nestedPageViewController)
        view.addSubview(nestedPageViewController.view)
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

extension YourViewController: NestedPageViewControllerDataSource {
    
    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int {
        return childControllerTitles.count
    }
    
    func pageViewController(_ pageViewController: NestedPageViewController, viewControllerAt index: Int) -> NestedPageScrollable? {
        guard index >= 0 && index < childControllerTitles.count else { return nil }
        
        switch index {
        case 0:
            return YourChildViewController1()  // 必须遵守NestedPageScrollable协议
        case 1:
            return YourChildViewController2()  // 必须遵守NestedPageScrollable协议
        case 2:
            return YourChildViewController3()  // 必须遵守NestedPageScrollable协议
        case 3:
            return YourChildViewController4()  // 必须遵守NestedPageScrollable协议
        default:
            return nil
        }
    }
    
    func coverView(in pageViewController: NestedPageViewController) -> UIView? {
        return coverView
    }
    
    func heightForCoverView(in pageViewController: NestedPageViewController) -> CGFloat {
        return 200.0
    }
    
    func tabStrip(in pageViewController: NestedPageViewController) -> UIView? {
        return customTabStrip  // 使用自定义标签栏
    }
    
    func heightForTabStrip(in pageViewController: NestedPageViewController) -> CGFloat {
        return 50.0
    }
    
    func titlesForTabStrip(in pageViewController: NestedPageViewController) -> [String]? {
        return nil  // 使用自定义标签栏时返回nil
    }
}

// MARK: - NestedPageViewControllerDelegate

extension YourViewController: NestedPageViewControllerDelegate {
    
    // 页面横向滚动到指定索引位置的回调方法
    func pageViewController(_ pageViewController: NestedPageViewController, didScrollToPageAt index: Int) {
        // 页面切换回调
        print("当前页面索引: \(index)")
    }
    
    // 内容垂直滚动视图的滚动状态变化回调方法
    func pageViewController(_ pageViewController: NestedPageViewController, contentScrollViewDidScroll scrollView: UIScrollView, headerOffset: CGFloat, isSticked: Bool) {
        // headerOffset: 头部相对contentScrollView顶部的偏移量
        // isSticked: 是否处于完全吸顶状态
        
        // 例如：根据滚动状态控制导航栏的显示/隐藏
        if isSticked {
            // 头部完全吸顶，可以显示导航栏标题
        } else {
            // 头部未完全吸顶，可以隐藏导航栏标题
        }
    }
}
```

### 方式二：继承方式

```swift
import UIKit
import NestedPageViewController

class YourNestedPageViewController: NestedPageViewController {
    
    // MARK: - Properties
    
    private var coverView = YourHeaderView()
    private var customTabStrip = YourCustomTabStrip()
    
    // MARK: - View Controllers
    
    private let childControllerTitles = ["标签一", "标签二", "标签三", "标签四"]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNestedPageViewController()
    }
    
    override func viewDidLayoutSubviews() {
        let safeTop = view.safeAreaInsets.top
        containerInsets = UIEdgeInsets(top: safeTop, left: 0, bottom: 0, right: 0)
        
        // 采用继承方式时，需要在super之前设置containerInsets
        super.viewDidLayoutSubviews()
    }
    
    // MARK: - Setup
    
    private func setupNestedPageViewController() {
        // 设置数据源
        dataSource = self
        
        // 设置代理（继承方式下，可以直接重写代理方法）
        delegate = self
    }
    
    // MARK: - NestedPageViewControllerDelegate
    
    // 页面横向滚动到指定索引位置的回调方法
    override func pageViewController(_ pageViewController: NestedPageViewController, didScrollToPageAt index: Int) {
        super.pageViewController(pageViewController, didScrollToPageAt: index)
        
        // 页面切换回调
        print("当前页面索引: \(index)")
    }
    
    // 内容垂直滚动视图的滚动状态变化回调方法
    override func pageViewController(_ pageViewController: NestedPageViewController, contentScrollViewDidScroll scrollView: UIScrollView, headerOffset: CGFloat, isSticked: Bool) {
        super.pageViewController(pageViewController, contentScrollViewDidScroll: scrollView, headerOffset: headerOffset, isSticked: isSticked)
        
        // headerOffset: 头部相对contentScrollView顶部的偏移量
        // isSticked: 是否处于完全吸顶状态
        
        // 例如：根据滚动状态控制导航栏的显示/隐藏
        if isSticked {
            // 头部完全吸顶，可以显示导航栏标题
        } else {
            // 头部未完全吸顶，可以隐藏导航栏标题
        }
    }
}

// MARK: - NestedPageViewControllerDataSource

extension YourNestedPageViewController: NestedPageViewControllerDataSource {
    
    func numberOfViewControllers(in pageViewController: NestedPageViewController) -> Int {
        return childControllerTitles.count
    }
    
    func pageViewController(_ pageViewController: NestedPageViewController, viewControllerAt index: Int) -> NestedPageScrollable? {
        guard index >= 0 && index < childControllerTitles.count else { return nil }
        
        switch index {
        case 0:
            return YourChildViewController1()  // 必须遵守NestedPageScrollable协议
        case 1:
            return YourChildViewController2()  // 必须遵守NestedPageScrollable协议
        case 2:
            return YourChildViewController3()  // 必须遵守NestedPageScrollable协议
        case 3:
            return YourChildViewController4()  // 必须遵守NestedPageScrollable协议
        default:
            return nil
        }
    }
    
    func coverView(in pageViewController: NestedPageViewController) -> UIView? {
        return coverView
    }
    
    func heightForCoverView(in pageViewController: NestedPageViewController) -> CGFloat {
        return 200.0
    }
    
    func tabStrip(in pageViewController: NestedPageViewController) -> UIView? {
        return customTabStrip  // 使用自定义标签栏
    }
    
    func heightForTabStrip(in pageViewController: NestedPageViewController) -> CGFloat {
        return 50.0
    }
    
    func titlesForTabStrip(in pageViewController: NestedPageViewController) -> [String]? {
        return nil  // 使用自定义标签栏时返回nil
    }
}
```

### Objective-C 使用方式

NestedPageViewController原本是用OC编写，考虑到swift是主流，于是改成了swift版本，OC工程要使用需要做一个桥接。

示例工程中提供了完整的 Objective-C 桥接示例，可以参考 `Example/NestedPageExample/Examples-OC` 目录下的实现。

## 性能报告

NestedPageViewController在性能方面进行了多项优化，确保在复杂的嵌套滚动场景下仍能保持流畅的用户体验。以下是demo中4个子控制下的性能评测：

### 内存占用
<img src="https://raw.githubusercontent.com/SPStore/NestedPageViewController/master/Assets/memory.png" width="600" alt="内存占用">

### CPU使用率
<img src="https://raw.githubusercontent.com/SPStore/NestedPageViewController/master/Assets/cpu.png" width="600" alt="CPU使用率">

## 实现原理
参见[实现原理](https://github.com/SPStore/NestedPageViewController/blob/master/docs/%E5%AE%9E%E7%8E%B0%E5%8E%9F%E7%90%86%E4%B8%8E%E9%9A%BE%E7%82%B9.md)

## 项目起源

本仓库的前身是我在8年前开发的一个名为**HVScrollView**的演示项目。当时由于经验有限，未能将其封装成一个通用组件。项目的思想萌芽实际上源自腾讯bugly发布的一篇关于[特斯拉组件](https://mp.weixin.qq.com/s/hBgvPBP12IQ1s65ru-paWw?poc_token=HKQ-wmijwa5omN1v5VYZzODMGBnfZCGOXPjKXLr6)的文章，该文章介绍了iOS高性能PageController的实现原理。

时光荏苒，8年过去了，我积累了更多的开发经验和技术沉淀，现在将这个想法重新实现并开源，希望能为iOS开发社区提供一个更加完善、易用的嵌套滚动解决方案。NestedPageViewController在保留原有思想精髓的基础上，进一步优化了性能和用户体验，为现代iOS应用提供了更加流畅的页面嵌套滚动效果。

## 参与贡献

由于本人工作繁忙，可能无法投入大量时间进行持续的更新迭代。我们非常欢迎有兴趣的开发者加入到项目中来，通过提交Pull Request的方式参与贡献。无论是功能改进、bug修复、文档完善还是性能优化，您的每一份贡献都将帮助这个项目变得更好。

如果您有任何问题或建议，也欢迎通过Issues进行讨论，或直接联系作者邮箱：lesp163@163.com。让我们一起打造更好的NestedPageViewController！


## 许可证

NestedPageViewController 使用 MIT 许可证。详情请查看 LICENSE 文件。

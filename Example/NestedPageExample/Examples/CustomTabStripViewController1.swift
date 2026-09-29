//
//  CustomTabStripViewController.swift
//  NestedPageExample
//
//  Created by 乐升平 on 2025/9/4.
//

import UIKit
import NestedPageViewController
import JXCategoryView

class CustomTabStripViewController1: UIViewController {
    
    // MARK: - Properties
    
    private var nestedPageViewController = NestedPageViewController()
    private var lastPageSize = CGSize.zero
    private var coverView = UIView()
    private var coverBgImageView = UIImageView()
    private var categoryView = JXCategoryTitleImageView()
    
    var lastSelectedIndex: Int = 0
    
    // MARK: - View Controllers
    
    private let childControllerTitles = ["作品", "推荐", "收藏"]
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        categoryView.titles = childControllerTitles
        categoryView.imageSize = CGSize(width: 16, height: 16)
        // 一开始仅有标题
        categoryView.imageTypes = [
            NSNumber(value: JXCategoryTitleImageType.onlyTitle.rawValue),
            NSNumber(value: JXCategoryTitleImageType.onlyTitle.rawValue),
            NSNumber(value: JXCategoryTitleImageType.onlyTitle.rawValue)
        ]
        // 一开始不给图片，只显示标题
        categoryView.imageInfoArray = [NSNull(), NSNull(), NSNull()]
        categoryView.selectedImageInfoArray = [NSNull(), NSNull(), NSNull()]

        categoryView.loadImageBlock = { imageView, info in
            if let image = info as? UIImage {
                imageView?.image = image
                imageView?.frame.size = self.categoryView.imageSize
            } else if let name = info as? String {
                imageView?.image = UIImage(named: name)
            } else {
                imageView?.frame.size = .zero
                imageView?.image = nil  // 没有就不展示
            }
        }

        categoryView.backgroundColor = .white
        categoryView.tintColor = .gray
        categoryView.titleSelectedColor = .orange
        categoryView.titleColor = .black
        categoryView.isTitleColorGradientEnabled = true
        categoryView.isTitleLabelZoomEnabled = true
        categoryView.isAverageCellSpacingEnabled = false
        categoryView.cellSpacing = 30
        // 这个属性控制点击tab切换时，是否有滚动动画
        categoryView.isContentScrollViewClickTransitionAnimationEnabled = false
        categoryView.delegate = self

        let lineView = JXCategoryIndicatorLineView()
        lineView.indicatorColor = .orange
        lineView.indicatorWidth = JXCategoryViewAutomaticDimension
        lineView.verticalMargin = 4

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

extension CustomTabStripViewController1: NestedPageViewControllerDataSource {
    
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
        return categoryView  // 使用内置的标签栏
    }
    
    func heightForTabStrip(in pageViewController: NestedPageViewController) -> CGFloat {
        return 40.0
    }
}

// MARK: - NestedPageViewControllerDelegate

extension CustomTabStripViewController1: NestedPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: NestedPageViewController, didScrollToPageAt index: Int) {

    }
    
    func pageViewController(_ pageViewController: NestedPageViewController,
                            contentScrollViewDidScroll scrollView: UIScrollView,
                            headerOffset: CGFloat,
                            isSticked: Bool) {
        
        let currentImage = categoryView.imageInfoArray[0]

        if isSticked {
            if let arrowUpImage = UIImage(systemName: "arrow.up"), currentImage is NSNull {
                categoryView.imageInfoArray[0] = arrowUpImage
                categoryView.selectedImageInfoArray[0] = arrowUpImage
                categoryView.imageTypes[0] = NSNumber(value: JXCategoryTitleImageType.rightImage.rawValue)
                categoryView.reloadData()
            }
        } else {
            if !(currentImage is NSNull) {
                categoryView.imageInfoArray[0] = NSNull()
                categoryView.selectedImageInfoArray[0] = NSNull()
                categoryView.imageTypes[0] = NSNumber(value: JXCategoryTitleImageType.onlyTitle.rawValue)
                categoryView.reloadData()
            }
        }
    }
}

extension CustomTabStripViewController1: JXCategoryViewDelegate {
    
    func categoryView(_ categoryView: JXCategoryBaseView!, didSelectedItemAt index: Int) {
        if index == 2 {
            if let lockImage = UIImage(systemName: "lock.fill"),
               let titleImageView = categoryView as? JXCategoryTitleImageView {
                
                titleImageView.imageInfoArray[2] = lockImage
                titleImageView.selectedImageInfoArray[2] = lockImage
                titleImageView.imageTypes[2] = NSNumber(value: JXCategoryTitleImageType.rightImage.rawValue)
                titleImageView.reloadData()
            }
        } else {
            if let titleImageView = categoryView as? JXCategoryTitleImageView {
                
                titleImageView.imageInfoArray[2] = NSNull()
                titleImageView.selectedImageInfoArray[2] = NSNull()
                titleImageView.imageTypes[2] = NSNumber(value: JXCategoryTitleImageType.onlyTitle.rawValue)
                titleImageView.reloadData()
            }
        }
        lastSelectedIndex = index
    }
    
    func categoryView(_ categoryView: JXCategoryBaseView!, didClickSelectedItemAt index: Int) {
        // 第一个已经被选中了，再次点击第一个tab，并且当前已经吸顶状态，就滚到顶部
        if index == lastSelectedIndex, index == 0, nestedPageViewController.isSticked {
            nestedPageViewController.scrollToTop()
        }
        
    }
}

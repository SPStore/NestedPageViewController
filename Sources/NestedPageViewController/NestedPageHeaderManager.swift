//
//  NestedPageHeaderManager.swift
//  NestedPageViewController
//
//  Created by 乐升平 on 2023/8/22.
//  Copyright © 2023 SPStore. All rights reserved.
//

import UIKit

/// 嵌套页面头部管理器，负责管理头部视图的创建、布局和状态管理
class NestedPageHeaderManager {
        
    weak var viewController: NestedPageViewController?
    
    var headerContentView: UIView = UIView()
    var pageHeaderMap: [Int: UIView] = [:]
    var coverView: UIView?
    var tabStrip: UIView?
    var coverHeight: CGFloat = 0
    var tabHeight: CGFloat = 0.0
    var pageHeaderHeight: CGFloat = 0
    
    // 这个视图起到至关重要的作用（它是可不见的），不仅控制其余scrollView的偏移量，同时也更方便控制headerContentView的位置
    var pin: UIView = UIView()
    // pin视图的Y坐标
    var previousPinY: CGFloat = 0
    // pin视图的溢出高度
    var overflowPinHeight: CGFloat = 0
    // 是否保持吸顶（当子列表未滑动到吸顶状态就切换tab，再切回来，需要维持当前的"半吸顶"状态）
    var keepsStick: Bool = false
    
    lazy var fixedContainer: UIView = {
        // 这里借助NestedPageHeaderView，通过allowsSubviewHitTestOnly实现仅子视图交互，屏蔽自身交互
        // 屏蔽自身交互，是为了当headerContentView的父视图为pageHeader时，能穿透
        // 又要子控件能交互，是为了当headerContentView的父视图为fixedContainer时, headerContentView能交互。
        let fixedContainer = NestedPageHeaderView()
        fixedContainer.allowsSubviewHitTestOnly = true
    
        viewController?.containerView.addSubview(fixedContainer)
        return fixedContainer
    }()
    
    private lazy var fixedContainerLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        return layer
    }()
    
    var shimView: UIView?
    
    // MARK: - Initialization
    
    init(viewController: NestedPageViewController?) {
        self.viewController = viewController
        if viewController != nil {
            setupPin()
        }
    }
    
    // MARK: - Setup
    
    func setupAfterViewControllerSet() {
        setupPin()
    }
    
    private func setupPin() {
        guard let viewController = viewController else { return }
        pin.isHidden = true
        viewController.containerView.addSubview(pin)
    }
        
    // MARK: - Data Configuration
    
    func configureHeaderData() {
        // 获取数据源信息
        fetchHeaderHeights()
        
        // 清理旧的header子视图
        for subview in headerContentView.subviews {
            subview.removeFromSuperview()
        }
        
        guard let viewController = viewController,
              let dataSource = viewController.dataSource else { return }
        
        // 添加新的header子视图
        coverView = dataSource.coverView(in: viewController)
        if let coverView = coverView {
            headerContentView.addSubview(coverView)
        }
        if let tabStrip = dataSource.tabStrip(in: viewController) {
            headerContentView.addSubview(tabStrip)
            self.tabStrip = tabStrip
        } else if self.tabStrip == nil,
                  let titles = dataSource.titlesForTabStrip(in: viewController) {
            let tabStrip = NestedPageTabStripView(titles: titles)
            tabStrip.linkedScrollView = viewController.containerScrollView
            headerContentView.addSubview(tabStrip)
            self.tabStrip = tabStrip
        }
    }
    
    func fetchHeaderHeights() {
        guard let viewController = viewController,
              let dataSource = viewController.dataSource else { return }
        
        coverHeight = dataSource.heightForCoverView(in: viewController)
        tabHeight = dataSource.heightForTabStrip(in: viewController)
        pageHeaderHeight = coverHeight + tabHeight
        viewController.stickyOffset = max(0, min(coverHeight, viewController.stickyOffset))
    }
    
    // MARK: - Layout
    
    func layoutPageHeader() {
        guard let viewController = viewController else { return }
                
        for pageHeader in pageHeaderMap.values {
            let headerWidth = viewController.containerView.bounds.width
            pageHeader.frame = CGRect(x: 0, y: -pageHeaderHeight, width: headerWidth, height: pageHeaderHeight)
        }

        let contentScrollViewY = viewController.contentScrollViewY
        
        fixedContainer.frame = CGRect(x: 0, y: contentScrollViewY, width: viewController.containerView.bounds.width, height: pageHeaderHeight)
        fixedContainerLayer.frame = fixedContainer.bounds
        // 通过一个mask，对fixedContainer上边做裁剪
        let path = UIBezierPath(rect: fixedContainer.bounds)
        // 这里200是个buffer：如果子控件部分超出了fixedContainer的下边，则留200的距离不裁剪，这是因为在回弹过程中，headerContentView的y值是大于0的，下半部分如果全部裁剪，会导致回弹过程中，tab有一瞬间不可见。
        let topRect = CGRect(x: 0, y: 0, width: fixedContainer.bounds.size.width, height: fixedContainer.bounds.size.height + 200)
        path.append(UIBezierPath(rect: topRect))
        // 设置 mask 只裁剪上边
        fixedContainerLayer.path = path.cgPath
        fixedContainer.layer.mask = fixedContainerLayer
        // 由于contentScrollView在自己的控制器中的左上角未必是(0,0)，因为有安全区域，pin的顶部必须和contentScrollView顶部对齐
        pin.frame = CGRect(x: 0, y: contentScrollViewY, width: viewController.containerView.bounds.width, height: pageHeaderHeight)
        overflowPinHeight = 0
    }
    
    func layoutHeaderViews() {
        guard let viewController = viewController else { return }
        // 布局header子视图
        coverView?.frame = CGRect(x: 0, y: 0, width: viewController.containerView.bounds.width, height: coverHeight)
        tabStrip?.frame = CGRect(x: 0, y: coverHeight, width: viewController.containerView.bounds.width, height: tabHeight)
        tabStrip?.layoutIfNeeded()
        (tabStrip as? NestedPageTabStripView)?.layoutIndicator()
    }
    
    func updateHeaderContentViewFrame() {
        guard let viewController = viewController else { return }
        headerContentView.frame = CGRect(x: 0, y: 0, width: viewController.containerView.bounds.width, height: pageHeaderHeight)
    }
    
    // MARK: - Header Management
    
    func pageHeader(at index: Int) -> NestedPageHeaderView? {
        return pageHeaderMap[index] as? NestedPageHeaderView
    }
    
    func createAndAddPageHeader(at index: Int, contentScrollView: UIScrollView) {
        guard let viewController = viewController else { return }
        
        var pageHeader = self.pageHeader(at: index)
        if pageHeader == nil {
            pageHeader = NestedPageHeaderView()
            let headerWidth = viewController.containerView.bounds.width
            pageHeader?.frame = CGRect(x: 0, y: -pageHeaderHeight, width: headerWidth, height: pageHeaderHeight)
            pageHeaderMap[index] = pageHeader
            contentScrollView.addSubview(pageHeader!)
            
            // 等于fixedContainer，说明正在横向滚动，横向滚动时，必须保持父视图为fixedContainer
            if index == viewController.currentIndex, headerContentView.superview != fixedContainer {
                headerContentView.frame = CGRect(x: 0, y: 0, width: headerWidth, height: pageHeaderHeight)
                pageHeader?.addSubview(headerContentView)
            }
        }
    }

    // MARK: - Header Position Management
    
    func movePageHeaderToPageHeaderByPin(currentIndex: Int) {
        guard let viewController = viewController else { return }
        
        if let pageHeader = pageHeader(at: currentIndex) {
            let contentScrollViewY = viewController.contentScrollViewY
            // 满足这个条件，一定不是吸顶
            if pin.frame.minY > -(coverHeight - viewController.stickyOffset - contentScrollViewY) {
                let coveredFrame = pin.convert(pin.bounds, to: pageHeader)
                moveHeaderContentViewToPageHeader(pageHeader, updatingY: coveredFrame.minY)
            }
        }
    }
    
    func moveHeaderContentViewToPageHeader(_ pageHeader: UIView, updatingY y: CGFloat) {
        adjustHeaderContentViewY(y)
        if headerContentView.superview != pageHeader {
            pageHeader.addSubview(headerContentView)
        }
    }
    
    func movePageHeaderToFixedContainerByPin() {
        let headerContentViewFrame = pin.convert(pin.bounds, to: fixedContainer)
        moveHeaderContentViewToFixedContainer(updatingY: headerContentViewFrame.minY)
    }
    
    // 特意加一个固定不动的容器视图作为headerContentView的父视图，是为了方便对headerContentView超出父视图的部分剪切，该容器视图的y值必须和contentScrollView对齐，要的效果是超出contentScrollView的部分裁剪掉。
    func moveHeaderContentViewToFixedContainer(updatingY y: CGFloat) {
        guard let viewController = viewController else { return }
        let contentScrollViewY = viewController.contentScrollViewY
        
        adjustHeaderContentViewY(y)
        fixedContainer.frame = CGRect(x: 0, y: contentScrollViewY, width: viewController.containerView.bounds.width, height: pageHeaderHeight)
        if headerContentView.superview != fixedContainer {
            fixedContainer.addSubview(headerContentView)
        }
    }
    
    func adjustHeaderContentViewY(_ y: CGFloat) {
        guard let viewController = viewController else { return }
        headerContentView.frame = CGRect(x: 0, y: y, width: viewController.containerView.bounds.width, height: pageHeaderHeight)
    }
    
    func adjustPinY(_ y: CGFloat) {
        guard let viewController = viewController else { return }
        pin.frame = CGRect(x: 0, y: y, width: viewController.containerView.bounds.width, height: pageHeaderHeight)
    }
    
    // MARK: - Shim View Management
    
    func insertShimViewIfNeed(lastContentScrollView: UIScrollView?) {
        guard let viewController = viewController,
              let lastScrollView = lastContentScrollView,
              lastScrollView.isTopBouncing else { return }
        guard headerContentView.superview == fixedContainer else { return }

        let contentScrollViewY = viewController.contentScrollViewY
        /** 这里设置高度为contentOffset.y是一个细节，如果pageHeader的高度很短，假如固定shimView的高度为pageHeaderHeight，那么下拉到一定程度的时候，能看出这个shimView的视图颜色和背景色不一致，为了消除这个现象，让高度动态等于上一个scrollView的偏移量。lastScrollView.contentOffset.y其实就是scrollView的顶端到tabStrip底部的这段距离。*/
        let frame = CGRect(x: 0, y: contentScrollViewY, width: viewController.containerView.bounds.width, height: -lastScrollView.contentOffset.y)
        if let existingShim = shimView {
            existingShim.frame = frame
        } else {
            let newShim = UIView(frame: frame)
            // 颜色设置为上一个正在回弹的scrollView的背景色，没有就一直往上查找。
            newShim.backgroundColor = lastScrollView.firstNonNilBackgroundColor()
            viewController.containerView.insertSubview(newShim, belowSubview: fixedContainer)
            shimView = newShim
        }
    }

    func removeShimView() {
        shimView?.removeFromSuperview()
        shimView = nil
    }
    
    // MARK: - Cleanup
    
    func removePageHeader(at index: Int) {
        if let pageHeader = pageHeaderMap[index] {
            pageHeader.removeFromSuperview()
            pageHeaderMap.removeValue(forKey: index)
        }
    }
    
    func cleanupOldData() {
        for view in pageHeaderMap.values {
            view.removeFromSuperview()
        }
        pageHeaderMap.removeAll()
    }
}

fileprivate extension UIView {
    func firstNonNilBackgroundColor() -> UIColor? {
        var current: UIView? = self
        while let view = current {
            if let color = view.backgroundColor {
                return color
            }
            current = view.superview
        }
        return nil
    }
}

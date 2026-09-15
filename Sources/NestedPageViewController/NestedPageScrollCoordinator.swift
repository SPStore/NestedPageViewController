//
//  NestedPageScrollCoordinator.swift
//  NestedPageViewController
//
//  Created by 乐升平 on 2023/8/22.
//  Copyright © 2023 SPStore. All rights reserved.
//

import UIKit
import Combine

/// 嵌套页面滚动协调器，主要负责处理横向、竖向滚动和header之间的逻辑关系
class NestedPageScrollCoordinator {
        
    weak var viewController: NestedPageViewController?
    weak var headerManager: NestedPageHeaderManager?
    weak var childManager: NestedPageChildManager?
    
    var isSticked: Bool = false
        
    private var isHorizontalScrolling: Bool = false
    
    private var lastContentScrollView: UIScrollView?
    private var lastContentOffsetY: CGFloat = 0
    
    private var isWaitingForAnimationEnd: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
        
    // MARK: - Initialization
    
    init(viewController: NestedPageViewController?, headerManager: NestedPageHeaderManager, childManager: NestedPageChildManager) {
        self.viewController = viewController
        self.headerManager = headerManager
        self.childManager = childManager
    }
    
    func reset() {
        lastContentOffsetY = 0
        lastContentScrollView = nil
    }
    
    // MARK: - Vertical Scrolling Management
    
    private func contentScrollViewDidScroll(_ scrollView: UIScrollView) {
        guard shouldHandleCurrentScrollEvent(with: scrollView) else { return }
        
        guard let viewController = viewController,
              let headerManager = headerManager,
              let childManager else { return }
        
        let currentOffsetY = scrollView.contentOffset.y
        let supplementaryOffsetY = currentOffsetY + (headerManager.pageHeaderHeight)
                
        // 处理固定头部的情况
        if viewController.headerAlwaysFixed == true {
            let contentScrollViewY = viewController.contentScrollViewY
            headerManager.adjustPinY(contentScrollViewY)
            headerManager.movePageHeaderToPageHeaderByPin(currentIndex: childManager.currentIndex)
            return
        }
        
        // 更新紧贴状态
        if supplementaryOffsetY <= headerManager.overflowPinHeight  {
            headerManager.keepsStick = false
        }
        
        // 计算吸顶状态并通知代理
        let shouldFullStick = currentOffsetY >= -headerManager.tabHeight - viewController.stickyOffset

        if headerManager.keepsStick == true {
            // 半吸顶状态
            handlePartialStickScrolling(scrollView: scrollView, currentOffsetY: currentOffsetY)
        } else if shouldFullStick {
            // 完全吸顶状态
            handleFullStickScrolling(currentOffsetY: currentOffsetY)
        } else {
            // 正常滚动状态
            handleNormalScrolling(scrollView: scrollView, currentOffsetY: currentOffsetY, supplementaryOffsetY: supplementaryOffsetY)
        }
        
        // 同步其他滚动视图并更新状态
        syncScrollOtherContentScrollView()
        
        isSticked = headerManager.pin.frame.minY <= -headerManager.coverHeight
        let sy = childManager.currentContentScrollView?.convert(childManager.currentContentScrollView?.bounds ?? .zero, to: viewController.containerView).minY ?? 0.0
        let cy = headerManager.headerContentView.convert(headerManager.headerContentView.bounds, to: viewController.containerView).minY
        viewController.delegate?.pageViewController(viewController, contentScrollViewDidScroll: scrollView, headerOffset: -cy + sy, isSticked: isSticked)
                        
        lastContentOffsetY = currentOffsetY
    }
    
    private func handlePartialStickScrolling(scrollView: UIScrollView, currentOffsetY: CGFloat) {
        guard let viewController = viewController,
              let headerManager = headerManager,
              let childManager = childManager else { return }
        
        let pageHeader = headerManager.pageHeader(at: childManager.currentIndex)
        
        // 判断头部悬停时向上滚动，头部是否应该跟随移动
        let shouldHeaderMoveUpward = !viewController.headerMovesOnlyWhenTouchingHeaderDuringHover || (pageHeader?.isHitted ?? false)
        
        if currentOffsetY >= lastContentOffsetY && shouldHeaderMoveUpward {
            // 向上滑动
            // 此时pageHeader的父视图是pageHeader，本身就会跟随scrollView滚动
            // pin的frame需要跟着pageHeader同步走，需要用pin来判断是否吸顶
            let newPinFrame = headerManager.headerContentView.convert(headerManager.headerContentView.bounds, to: viewController.containerView)
            headerManager.adjustPinY(newPinFrame.minY)
            
            let contentScrollViewY = viewController.contentScrollViewY
            if newPinFrame.minY <= -(headerManager.coverHeight - viewController.stickyOffset - contentScrollViewY) {
                // 吸顶了
                handleFullStickScrolling(currentOffsetY: currentOffsetY)
            }
            // 注意一定要更新overflowPinHeight，否则下拉时pageHeader会一直吸顶，跟scrollView"脱钩"
            headerManager.overflowPinHeight = -(headerManager.pin.frame.minY - contentScrollViewY)
            headerManager.movePageHeaderToPageHeaderByPin(currentIndex: childManager.currentIndex)
        } else {
            // 向下滑动
            /**
             提升用户体验：来到这个分支，说明不是吸顶，而是吸在中间位置，此时希望减速过程中，能切换tab；
             因为这个时候头部视图静止不动，头部视图应该能交互才是更好的体验。
             */
            if scrollView.isDecelerating && !scrollView.isVerticalBouncing {
                // 切换父视图为self的目的是当contentScrollView在减速过程中，可以切换tab
                headerManager.movePageHeaderToFixedContainerByPin()
                // scrollView最后一次偏移量改变，isDecelerating仍然是true，这里需要延迟一帧判断
                DispatchQueue.main.async { [weak self] in
                    guard let self = self,
                          let _ = self.viewController,
                          let headerManager = self.headerManager else { return }
                    // 已经结束滚动了(判断isDragging是因为正在减速过程中，手指又开始触摸拖拽)
                    if scrollView.isDragging || !scrollView.isDecelerating {
                        // movePageHeaderToPageHeaderByPin方法内会重新获取pageHeader
                        // 也一定要重新获取pageHeader，因为异步来到这里，currentIndex可能变了
                        headerManager.movePageHeaderToPageHeaderByPin(currentIndex: childManager.currentIndex)
                    }
                }
            } else {
                headerManager.movePageHeaderToPageHeaderByPin(currentIndex: childManager.currentIndex)
            }
        }
    }
    
    private func handleFullStickScrolling(currentOffsetY: CGFloat) {
        guard let viewController = viewController,
              let headerManager = headerManager else { return }
        
        let contentScrollViewY = viewController.contentScrollViewY
        let pinY = -(headerManager.coverHeight - viewController.stickyOffset) + contentScrollViewY
        
        // 检查是否需要中断惯性滚动到吸顶位置
        if shouldInterruptScrollingToStickPosition(currentOffsetY: currentOffsetY, pinY: pinY) {
            viewController.currentContentScrollView?.setContentOffset(
                CGPoint(x: viewController.currentContentScrollView?.contentOffset.x ?? 0, y: -headerManager.tabHeight), 
                animated: false
            )
        }
        
        headerManager.adjustPinY(pinY)
        // 处于吸顶状态时，父视图切到self上，这样在contentScrollView滑动时，tab能切换
        headerManager.movePageHeaderToFixedContainerByPin()
    }
    
    private func handleNormalScrolling(scrollView: UIScrollView, currentOffsetY: CGFloat, supplementaryOffsetY: CGFloat) {
        guard let viewController = viewController,
              let headerManager = headerManager else { return }
        
        let contentScrollViewY = viewController.contentScrollViewY
        
        // 更新pin位置
        if currentOffsetY <= -headerManager.pageHeaderHeight {
            // pin视图不跟随scrollView继续下拉回弹，这么设计的目的是可以控制其余scrollView
            // 在当前scrollView的bouncing过程中，不发生偏移，这样切换tab不会出现其余scrollView还存在"悬挂"现象
            headerManager.adjustPinY(contentScrollViewY)
        } else {
            headerManager.adjustPinY(-supplementaryOffsetY + contentScrollViewY)
        }
                
        // 更新头部视图位置
        guard let pageHeader = headerManager.pageHeader(at: childManager?.currentIndex ?? 0) else { return }
        if viewController.headerBounces {
            headerManager.moveHeaderContentViewToPageHeader(pageHeader, updatingY: 0)
        } else {
            // bug修复： 局部下拉刷新时，由于外部可能会使用UIView动画设置scrollView的setContentOffset，这会导致在此处设置headerContentView的frame会闪跳
            // 解决思路：如果currentOffsetY < -headerManager.pageHeaderHeight，说明正在下拉刷新还未结束，此时固定headerContentView在fixedContainer上，这样就不会受到UIView动画的干扰
            if currentOffsetY < -headerManager.pageHeaderHeight {
                UIView.performWithoutAnimation {
                    headerManager.movePageHeaderToFixedContainerByPin()
                }
            } else {
                // 下拉刷新结束，准备回弹，准备回弹的过程中，又可能有UIView动画
                // 如果有UIView动画，那么等动画彻底结束再恢复到pageHeader上
                if UIView.inheritedAnimationDuration > 0 {
                    isWaitingForAnimationEnd = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + UIView.inheritedAnimationDuration) { [weak self] in
                        guard let self = self else { return }
                        // 防止回弹过程中，横向切换containerScrollView导致头部闪烁
                        if !isHorizontalScrolling {
                            headerManager.movePageHeaderToPageHeaderByPin(currentIndex: self.childManager?.currentIndex ?? 0)
                        }
                        self.isWaitingForAnimationEnd = false
                    }
                } else {
                    /** 虽然来到这里UIView.inheritedAnimationDuration是为0的，但并不代表不会有UIView动画，因为本方法是KVO监听的，是在UIView动画的下一个runloop中触发，可能来到这里的时候，动画已经结束了，但是新的UIView动画可能又立即开始了，此时会触发UIView.inheritedAnimationDuration > 0 这个分支，因此这里加一个isWaitingForAnimationEnd标记，永远保证新的UIView动画结束后，才恢复headerContentView的父视图为pageHeader */
                    if isWaitingForAnimationEnd == false {
                        // pin本身就是没有弹性的，直接根据pin确定headerContentView的位置
                        headerManager.movePageHeaderToPageHeaderByPin(currentIndex: childManager?.currentIndex ?? 0)
                    }
                }
            }
        }
    }

    /**
     同步其他子列表的滚动位置，这里通过 pin 的改变量控制其他scrollView 的滚动
     
     之所以不通过当前 scrollView 的改变量或者 headerContentView 的改变量来计算，是因为它们可能会跨越临界值，导致计算不准确
     
     有两种情况，其余 scrollView 的改变量必须为 0（即不发生偏移）：
     
     1. 当 headerContentView 在吸顶时
        - 在这种情况下，通过 headerContentView 的改变量也可以计算，但为了统一逻辑，仍然通过 pin 来控制。
     
     2. 当 scrollView 处于回弹状态时
        - 如果在回弹过程中直接设置其他 scrollView 的偏移，由于用户可能切换 tab，currentContentScrollView 可能已经变更，导致无法同步设置其余 scrollView 的偏移量，从而出现"悬挂"状态
     
     为了处理以上两种情况，引入 pin 视图：
        - 无论是吸顶还是回弹状态，当达到临界值时，pin 都保持固定不动
        - 由于 pin 的改变量为 0，因此可以保证其余 scrollView 的改变量也为 0，从而统一控制滚动行为
     */
    private func syncScrollOtherContentScrollView() {
        guard let viewController = viewController,
              let headerManager = headerManager,
              let childManager = childManager else { return }
        
        let currentPinY = headerManager.pin.frame.minY
        let deltaY = currentPinY - headerManager.previousPinY
        headerManager.previousPinY = currentPinY
                        
        for childViewController in childManager.viewControllerMap.values {
            let contentScrollView = childViewController.nestedPageContentScrollView
            guard contentScrollView != viewController.currentContentScrollView else {
                continue
            }
            
            var newOffset = contentScrollView.contentOffset
            newOffset.y -= deltaY
                      
            // 非吸顶状态时，如果keepsContentScrollPosition为false，其余scrollView偏移量全部恢复到初始值
            // abs(deltaY) > CGFloat.ulpOfOne（deltaY != 0）说明pin的y值发生了变化，发生变化就说明一定是非吸顶状态
            if !viewController.keepsContentScrollPosition && abs(deltaY) > CGFloat.ulpOfOne {
                newOffset.y = -(currentPinY + headerManager.pageHeaderHeight)
            }
            // 校准操作，防止旋转过程中或者其他异常，导致偏移量过大且无法回弹。正常情况下不会进入这个if语句。
            if newOffset.y < -headerManager.pageHeaderHeight {
                newOffset.y = -headerManager.pageHeaderHeight
            }
            contentScrollView.setContentOffset(newOffset, animated: false)
        }
    }
    
    private func shouldHandleCurrentScrollEvent(with scrollView: UIScrollView) -> Bool {
        guard let viewController,
              !viewController.isUpdatingLayouts,
              !isHorizontalScrolling,
              let currentContentScrollView = viewController.currentContentScrollView,
              scrollView == currentContentScrollView else {
            return false
        }
        return true
    }
    
    /// 检查是否需要中断惯性滚动到吸顶位置
    private func shouldInterruptScrollingToStickPosition(currentOffsetY: CGFloat, pinY: CGFloat) -> Bool {
        guard let viewController = viewController,
              let headerManager = headerManager,
              let currentContentScrollView = viewController.currentContentScrollView else {
            return false
        }
        
        //  headerManager.pin.frame.minY > pinY说明此时还未吸顶
        return currentContentScrollView.isDecelerating &&
               headerManager.pin.frame.minY > pinY &&
               viewController.interruptsScrollingWhenTransitioningToFullStick &&
               currentOffsetY > -headerManager.tabHeight
    }
    
    // MARK: - Horizontal Scrolling Management
    
    func handleHorizontalScrollDidScroll(_ scrollView: UIScrollView) {
        guard let viewController = viewController,
              let headerManager = headerManager,
              !viewController.isUpdatingLayouts,
              scrollView == viewController.containerScrollView else { return }
        
        guard viewController.isRotating == false else { return }

        isHorizontalScrolling = true
        
        if lastContentScrollView == nil {
            // 刚开始滑动的时候，currentContentScrollView还是上一个scrollView
            lastContentScrollView = viewController.currentContentScrollView
        }
        
        /**
          回弹过程不用终止，因为回弹过程headerContentView的父视图是pageHeader，不存在y值不更新的问题。
          比较contentSize是避免crash: 如果外部无意导致contentSize的宽度大于容器宽，那么lastContentScrollView就可以水平滚动，同时也会触发containerScrollView水平滚动，此时调用stopScrolling会导致死循环.
         */
        if let lastContentScrollView = lastContentScrollView,
           lastContentScrollView.isDecelerating && !lastContentScrollView.isVerticalBouncing && lastContentScrollView.contentSize.width <= viewController.view.bounds.width {
            /** 立即终止lastContentScrollView滚动，如果在上一个scrollView减速过程中切换，由于减速过程在contentScrollViewDidScroll:中headerContentView的父视图已经切到了self，此时横向切换后currentContentScrollView已变，不会再更新headerContentView的y值，导致headerContentView的y值与上一个lastContentScrollView的偏移"脱钩"了，最终的现象就是滑回上一个scrollView后，headerContentView与scrollView的top之间有比较多的间隙。
             */
            lastContentScrollView.stopScrolling()
        }
        
        var pageHeaderY: CGFloat = 0
        
        // 满足这个条件，说明lastContentScrollView还在回弹，为了动画衔接的更加丝滑，让headerContentViewY持续跟随lastContentScrollView偏移量走，否则直接设置frame.minY，会有一个轻微的抖动现象
        // 解决场景：上一个scrollView在使劲往下拽回弹过程中，立即切换tab。
        if let lastContentScrollView = lastContentScrollView,
           lastContentScrollView.isTopBouncing && !viewController.headerAlwaysFixed {
            pageHeaderY = -(lastContentScrollView.contentOffset.y + headerManager.pageHeaderHeight)
            // 这里再次回调，是为了让lastContentScrollView整个滚动周期，都能让外部接收到响应，比如计算头部缩放，如果这里不回调，那么回弹过程中切换tab，会导致外部的某些计算被终止。
            viewController.delegate?.pageViewController(viewController, contentScrollViewDidScroll: lastContentScrollView, headerOffset: -pageHeaderY, isSticked: false)
        } else {
            let frame = headerManager.headerContentView.convert(headerManager.headerContentView.bounds, to: headerManager.fixedContainer)
            pageHeaderY = frame.minY
        }
        // 将headerContentView的坐标从pageHeader上切换到fixedContainer中来
        headerManager.moveHeaderContentViewToFixedContainer(updatingY: pageHeaderY)
        
        /** 添加shimView是为了处理一种细节：当相邻的2个contentScrollView（或者说它们的根视图）的颜色不一致时，使劲下拉在回弹过程中切换tab，由于headerContentView此时还没恢复到顶，顶部有间隙，此时就可以看见相邻2个contentScrollView的不同颜色，为了遮盖这个现象，这里创建一个视图与contentScrollView顶部对齐，在contentScrollView之上，在headerContentView之下，跟正在回弹的那个contentScrollView保持一样的背景色。*/
        headerManager.insertShimViewIfNeed(lastContentScrollView: lastContentScrollView)
        
        handleScrollEndIfNeeded(scrollView)
    }
    
    // 手指拖拽 -> 松手 -> （如果有速度则继续减速）-> 完全静止
    func handleScrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let viewController = viewController else { return }
        if scrollView == viewController.containerScrollView {
            checkAndHandleScrollEnd(scrollView)
        }
    }
    
    // 手指拖拽 -> 松手 -> decelerate == false代表立即静止（无惯性减速，不会触发scrollViewDidEndDecelerating）
    func handleScrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard let viewController = viewController else { return }
        if !decelerate && scrollView == viewController.containerScrollView {
            checkAndHandleScrollEnd(scrollView)
        }
    }
    
    // 当调用setContentOffset(animated: true)时才会执行
    func handleScrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard let viewController = viewController else { return }
        // 17.4以下系统，在scrollViewDidScroll方法中调用handlePageChangeToIndex:
        if #available(iOS 17.4, *) {
            if scrollView == viewController.containerScrollView {
                checkAndHandleScrollEnd(scrollView)
            }
        }
    }
    
    private func handleScrollEndIfNeeded(_ scrollView: UIScrollView) {
        if #available(iOS 17.4, *) {
            // 当setContentOffset(animated: false) 时执行
            if !scrollView.isScrollAnimating {
                if !scrollView.isDragging && !scrollView.isDecelerating {
                    checkAndHandleScrollEnd(scrollView)
                }
            }
        } else { // 17.4以下系统
            // 当setContentOffset(animated:)时执行，不论动画true还是false. 17.4及其以上系统，动画为true时，由scrollViewDidEndScrollingAnimation方法执行结束滚动逻辑，动画为false时，由当前方法执行滚动结束逻辑
            if !scrollView.isDragging && !scrollView.isDecelerating {
                checkAndHandleScrollEnd(scrollView)
            }
        }
    }
    
    // 之所以每次滚动结束也要做一次检查，是因为在滚动结束的那一瞬间，可能又触发了新的滚动（滚动结束不代表分页结束），这会导致头部视图闪跳。
    // 一般2只手指同时操作容易出现，比如一只手点了第3个tab，同时另一只手立刻点第2个tab；或者手指横向滑动还未等分页结束，另一只手就点击tab。
    private func checkAndHandleScrollEnd(_ scrollView: UIScrollView) {
        let offsetX = scrollView.contentOffset.x
        let index = Int(offsetX / scrollView.bounds.width + 0.5)
        // 满足这个条件，当作滚到目标页了
        if abs(offsetX - CGFloat(index) * scrollView.bounds.width) < 0.01 {
            handleScrollEnd(withIndex: index)
        }
    }

    private func handleScrollEnd(withIndex index: Int) {
        guard let viewController = viewController,
              let headerManager = headerManager,
              let childManager = childManager,
              let dataSource = viewController.dataSource,
              index >= 0 && index < dataSource.numberOfViewControllers(in: viewController) else {
            return
        }
        
        if index != childManager.currentIndex {
            childManager.currentIndex = index
            childManager.loadViewController(at: index)
            
            if let childViewController = childManager.viewController(at: index) {
                childManager.currentContentScrollView = childViewController.nestedPageContentScrollView
            }
            
            // 超出内容scrollView的距离，所以需要减去scrollView的y值(contentScrollView顶部可能有安全区域)
            let contentScrollViewY = viewController.contentScrollViewY
            headerManager.overflowPinHeight = -(headerManager.pin.frame.minY - contentScrollViewY)
            // 记录一下是否保持吸顶状态
            let overflowOffsetY = (viewController.currentContentScrollView?.contentOffset.y ?? 0) + headerManager.pageHeaderHeight + viewController.stickyOffset
            if overflowOffsetY > headerManager.overflowPinHeight {
                headerManager.keepsStick = true
            } else {
                headerManager.keepsStick = false
            }
        }
        
        moveHeaderContentViewToPageHeader(at: index)
        
        viewController.delegate?.pageViewController(viewController, didScrollToPageAt: index)
        
        // 校准偏移量
        if let lastContentScrollView = lastContentScrollView, lastContentScrollView.isTopBouncing {
            lastContentScrollView.setContentOffset(CGPoint(x: lastContentScrollView.contentOffset.x, y: -(headerManager.pageHeaderHeight)), animated: false)
        }
        self.lastContentScrollView = viewController.currentContentScrollView
        lastContentOffsetY = viewController.currentContentScrollView?.contentOffset.y ?? 0
        isHorizontalScrolling = false
        
        headerManager.removeShimView()
    }
    
    private func moveHeaderContentViewToPageHeader(at index: Int) {
        guard let viewController = viewController,
              let headerManager = headerManager,
              let dataSource = viewController.dataSource,
              index >= 0 && index < dataSource.numberOfViewControllers(in: viewController) else {
            return
        }
        
        headerManager.movePageHeaderToPageHeaderByPin(currentIndex: index)
    }
    
    // MARK: - ScrollView Observation

    func observeScrollView(_ scrollView: UIScrollView?) {
        guard let scrollView = scrollView,
              let _ = viewController,
              let _ = headerManager else { return }
        
        // 观察contentOffset变化
        scrollView.publisher(for: \.contentOffset)
            .sink { [weak self, weak scrollView] _ in
                guard let self = self,
                        let scrollView = scrollView,
                      let headerManager = self.headerManager, scrollView.contentInset.top == headerManager.pageHeaderHeight else { return }
                self.contentScrollViewDidScroll(scrollView)
            }
            .store(in: &cancellables)
        
        // 观察contentSize变化
        scrollView.publisher(for: \.contentSize)
            .sink { [weak self, weak scrollView] newSize in
                guard let self = self, let scrollView = scrollView,
                      let viewController = self.viewController,
                      let headerManager = self.headerManager,
                      viewController.autoAdjustsContentSizeMinimumHeight else { return }
                         
                guard !scrollView.isDragging && !scrollView.isDecelerating else { return }

                let contentScrollViewY = viewController.contentScrollViewY
                let minContentSizeHeight = viewController.containerView.bounds.height - headerManager.tabHeight - contentScrollViewY - scrollView.contentInset.bottom - viewController.stickyOffset
                if minContentSizeHeight > newSize.height {
                    scrollView.contentSize.height = minContentSizeHeight
                }
                    
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Cleanup
    
    deinit {
        cancellables.removeAll()
    }
}

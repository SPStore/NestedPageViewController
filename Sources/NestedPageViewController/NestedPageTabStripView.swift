//
//  NestedPageTabStripView.swift
//  NestedPageViewController
//
//  Created by 乐升平 on 2023/1/24.
//  Copyright © 2023 SPStore. All rights reserved.
//
//  本组件作为分页控制器的内置标签栏，其设计本意是开箱即用，如果需要更复杂的标签栏样式，请自定义或者使用其它开源组件。

import UIKit

/// TabStrip的配置类
public struct NestedPageTabStripConfiguration: Hashable {
    
    /// 标题数组
    public var titles: [String] = []
    
    /// 普通状态下的标题颜色，默认：UIColor.gray
    public var titleColor: UIColor = .gray
    
    /// 选中状态下的标题颜色，默认：UIColor.black
    public var titleSelectedColor: UIColor = .black
    
    /// 标题字体，默认：UIFont.systemFont(ofSize: 16)
    public var titleFont: UIFont = .systemFont(ofSize: 16)
    
    /// 背景颜色，默认：UIColor.white
    public var backgroundColor: UIColor = .white
    
    /// 指示器颜色，默认：UIColor.systemYellow
    public var indicatorColor: UIColor = .systemYellow
    
    /// 指示器大小，默认：CGSize(width: 20, height: 3)
    public var indicatorSize: CGSize = CGSize(width: 20, height: 3)
    
    /// 指示器大小的圆角半径，默认：1.5
    public var indicatorSizeCornerRadius: CGFloat = 1.5
    
    /// 指示器与容器底部之间的距离
    public var indicatorVerticalMargin: CGFloat = 0
    
    /// 按钮之间的间距
    public var spacing: CGFloat = 0.0
    
    /// 内容边距，默认：UIEdgeInsets.zero
    public var contentEdgeInsets: UIEdgeInsets = .zero
    
    /// 公开初始化方法
    public init() {}
    
    // MARK: - Hashable Implementation
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(titles)
        hasher.combine(titleColor.hashValue)
        hasher.combine(titleSelectedColor.hashValue)
        hasher.combine(titleFont.hashValue)
        hasher.combine(backgroundColor.hashValue)
        hasher.combine(indicatorColor.hashValue)
        hasher.combine(indicatorSize.width)
        hasher.combine(indicatorSize.height)
        hasher.combine(indicatorSizeCornerRadius)
        hasher.combine(indicatorVerticalMargin)
        hasher.combine(spacing)
        hasher.combine(contentEdgeInsets.top)
        hasher.combine(contentEdgeInsets.left)
        hasher.combine(contentEdgeInsets.bottom)
        hasher.combine(contentEdgeInsets.right)
    }
    
    public static func == (lhs: NestedPageTabStripConfiguration, rhs: NestedPageTabStripConfiguration) -> Bool {
        return lhs.titles == rhs.titles &&
               lhs.titleColor == rhs.titleColor &&
               lhs.titleSelectedColor == rhs.titleSelectedColor &&
               lhs.titleFont == rhs.titleFont &&
               lhs.backgroundColor == rhs.backgroundColor &&
               lhs.indicatorColor == rhs.indicatorColor &&
               lhs.indicatorSize == rhs.indicatorSize &&
               lhs.indicatorSizeCornerRadius == rhs.indicatorSizeCornerRadius &&
               lhs.indicatorVerticalMargin == rhs.indicatorVerticalMargin &&
               lhs.spacing == rhs.spacing &&
               lhs.contentEdgeInsets == rhs.contentEdgeInsets
    }
}

public protocol NestedPageTabStripViewDelegate: AnyObject {
    
    /// 标题选中时的回调（点击或滚动选中）
    func tabStripView(_ tabStripView: NestedPageTabStripView, didSelectTabAt index: Int)
}

/// 内置的简单TabStrip视图
open class NestedPageTabStripView: UIView {
        
    // MARK: - Public Properties
    
    /// 便利构造器：使用标题数组初始化
    public convenience init(titles: [String]) {
        var config = NestedPageTabStripConfiguration()
        config.titles = titles
        self.init(configuration: config)
    }
    
    /// 使用配置初始化
    public init(configuration: NestedPageTabStripConfiguration) {
        self.configuration = configuration
        // 给一个最小宽高，防止stackView布局时，由于父视图宽高为0，但又设置了contentEdgeInsets或spacing而报约束警告
        super.init(
            frame: CGRect(
                x: 0,
                y: 0,
                width: configuration.contentEdgeInsets.left + configuration.contentEdgeInsets.right + configuration.spacing * CGFloat(configuration.titles.count),
                height: configuration.contentEdgeInsets.top + configuration.contentEdgeInsets.bottom
            )
        )
        setupViews()
        // 初始化完成后立即加载内容
        reloadContent()
    }
    
    public override init(frame: CGRect) {
        self.configuration = NestedPageTabStripConfiguration()
        super.init(frame: frame)
        setupViews()
        if !configuration.titles.isEmpty {
            reloadContent()
        }
    }
    
    public required init?(coder: NSCoder) {
        self.configuration = NestedPageTabStripConfiguration()
        super.init(coder: coder)
        setupViews()
        // 如果配置中已有标题，则立即刷新内容
        if !configuration.titles.isEmpty {
            reloadContent()
        }
    }
    
    public var titles: [String] {
        get { return configuration.titles }
        set {
            configuration.titles = newValue
            reloadContent()
        }
    }
    
    /// 配置对象，更新配置会触发UI重建
    /// 由于组件较轻量，采用直接重建而非精细化控制的方式
    public var configuration: NestedPageTabStripConfiguration {
        didSet {
            reloadContent()
        }
    }
    
    public weak var delegate: NestedPageTabStripViewDelegate?
    
    /// 当前选中的索引
    public private(set) var selectedIndex: Int = 0
    
    /// 关联的容器滚动视图（用于联动）
    public weak var linkedScrollView: UIScrollView? {
        didSet {
            if let oldScrollView = oldValue {
                oldScrollView.removeObserver(self, forKeyPath: "contentOffset")
            }
            
            if let newScrollView = linkedScrollView {
                newScrollView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var stackView = UIStackView()
    private var titleButtons: [UIButton] = []
    private var indicatorView = UIView()
    private var isScrollingProgrammatically = false
    private var stackViewConstraints: [NSLayoutConstraint] = []
    
    // MARK: - Setup
    
    private func setupViews() {
        
        addSubview(indicatorView)

        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .fill
        stackView.spacing = configuration.spacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
                        
        titleButtons = []
    }

    private func reloadContent() {
        
        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        
        for button in titleButtons {
            stackView.removeArrangedSubview(button)
            button.removeFromSuperview()
        }
        titleButtons.removeAll()
        
        for (index, title) in titles.enumerated() {
            let button = createTitleButton(with: title, index: index)
            stackView.addArrangedSubview(button)
            titleButtons.append(button)
        }
        
        updateAppearance()
        setNeedsLayout()
        layoutIfNeeded()
        self.layoutIndicator()
    }
    
    private func createTitleButton(with title: String, index: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(configuration.titleColor, for: .normal)
        button.titleLabel?.font = configuration.titleFont
        button.tag = index
        button.addTarget(self, action: #selector(titleButtonTapped(_:)), for: .touchUpInside)
        return button
    }
    
    // MARK: - Layout

    open override func layoutSubviews() {
        super.layoutSubviews()
        // 导航栏 titleView 等宿主会在初始化后才确定尺寸，先完成按钮布局再定位跟踪器。
        stackView.layoutIfNeeded()
        if let scrollView = linkedScrollView,
           scrollView.bounds.width > 0,
           titleButtons.count >= 2,
           !isLinkedScrollAnimating {
            // 尺寸变化或重新布局时保留横滑进度，不能直接吸附到选中的按钮。
            updateIndicatorPosition(with: scrollView.contentOffset.x, pageWidth: scrollView.bounds.width)
        } else {
            layoutIndicator()
        }
    }
    
    open override func updateConstraints() {
        super.updateConstraints()

        // 移除旧约束
        NSLayoutConstraint.deactivate(stackViewConstraints)
        stackViewConstraints.removeAll()
        
        // 创建新约束
        let newConstraints = [
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: configuration.contentEdgeInsets.top),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: configuration.contentEdgeInsets.left),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -configuration.contentEdgeInsets.right),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -configuration.contentEdgeInsets.bottom)
        ]
        
        // 保存并激活新约束
        stackViewConstraints = newConstraints
        NSLayoutConstraint.activate(stackViewConstraints)
    }

    public func layoutIndicator() {
        guard !titleButtons.isEmpty && selectedIndex < titleButtons.count else {
            return
        }
        
        let selectedButton = titleButtons[selectedIndex]
                
        // 将按钮的中心点从stackView坐标系转换到TabStripView坐标系
        let buttonCenterInTabStrip = stackView.convert(selectedButton.center, to: self)
                        
        let indicatorX = buttonCenterInTabStrip.x - configuration.indicatorSize.width / 2.0
        let indicatorY = bounds.height - configuration.indicatorSize.height - configuration.indicatorVerticalMargin

        indicatorView.frame = CGRect(x: indicatorX, y: indicatorY,
                                   width: configuration.indicatorSize.width,
                                   height: configuration.indicatorSize.height)
    }
        
    // MARK: - Public Methods
    
    /// 选中指定索引的标题
    open func selectTab(at index: Int, animated: Bool) {
        guard index >= 0 && index < titleButtons.count && index != selectedIndex else {
            return
        }
        
        if #available(iOS 17.4, *) {
            // 17.4系统开始，通过isScrollAnimating判断是否在执行setContentOffset动画
            // 这里不需要设置isScrollingProgrammatically
        } else {
            isScrollingProgrammatically = true
        }
        
        selectedIndex = index
        updateAppearance()
        updateIndicatorPosition(animated: animated)
        
        // 让关联的linkedScrollView滚动到对应页面
        scrollLinkedScrollView(to: index, animated: true)
        
        // 通知代理
        delegate?.tabStripView(self, didSelectTabAt: index)
        
        // 在scrollView滚动动画结束之后，重置isScrollingProgrammatically，这里对时间的要求不用太严格，只要能重置不要太晚即可。
        if #available(iOS 17.4, *) {
            // 17.4系统开始，通过isScrollAnimating判断是否在执行setContentOffset动画
            // 不需要重置isScrollingProgrammatically
        } else {
            let delay: TimeInterval = animated ? 0.3 : 0.01
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.isScrollingProgrammatically = false
            }
        }
    }
    
    // MARK: - Private Methods
    
    @objc private func titleButtonTapped(_ button: UIButton) {
        let index = button.tag
        selectTab(at: index, animated: true)
    }
    
    private func updateAppearance() {
        backgroundColor = configuration.backgroundColor
        indicatorView.backgroundColor = configuration.indicatorColor
        
        // 确保圆角半径不超过指示器尺寸的一半，避免出现异常的视觉效果
        let maxRadius = min(configuration.indicatorSize.width / 2.0, configuration.indicatorSize.height / 2.0)
        indicatorView.layer.cornerRadius = min(configuration.indicatorSizeCornerRadius, maxRadius)
        
        // 更新按钮外观
        for (index, button) in titleButtons.enumerated() {
            let isSelected = (index == selectedIndex)
            
            let color = isSelected ? configuration.titleSelectedColor : configuration.titleColor
            button.setTitleColor(color, for: .normal)
            button.titleLabel?.font = configuration.titleFont
        }
    }
    
    private func updateIndicatorPosition(animated: Bool) {
        let updateBlock = {
            self.layoutIndicator()
        }
        
        if animated {
            UIView.animate(withDuration: 0.25, animations: updateBlock)
        } else {
            updateBlock()
        }
    }
    
    private func scrollLinkedScrollView(to index: Int, animated: Bool) {
        guard let linkedScrollView = linkedScrollView,
              index >= 0 && index < titleButtons.count else {
            return
        }
        
        // 计算目标页面的偏移量
        let pageWidth = linkedScrollView.bounds.width
        let targetOffsetX = CGFloat(index) * pageWidth
        let targetOffset = CGPoint(x: targetOffsetX, y: linkedScrollView.contentOffset.y)
        
        // 滚动到目标位置
        linkedScrollView.setContentOffset(targetOffset, animated: animated)
    }
    
    // MARK: - Content ScrollView Support
    
    @objc public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset" && object as? UIScrollView == linkedScrollView {
            handleLinkedScrollViewDidScroll()
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    private var isLinkedScrollAnimating: Bool {
        if #available(iOS 17.4, *) {
            return linkedScrollView?.isScrollAnimating ?? false
        } else {
            return isScrollingProgrammatically
        }
    }

    private func handleLinkedScrollViewDidScroll() {
        guard let linkedScrollView = linkedScrollView,
              linkedScrollView.bounds.width > 0,
              !titleButtons.isEmpty,
              !isLinkedScrollAnimating else {
            return
        }
        
        let pageWidth = linkedScrollView.bounds.width
        let contentOffsetX = linkedScrollView.contentOffset.x
        
        // 计算当前页面索引（用于按钮状态更新）
        var currentIndex = Int(round(contentOffsetX / pageWidth))
        currentIndex = max(0, min(currentIndex, titleButtons.count - 1))
        
        // 更新按钮选中状态（只在索引变化时）
        if currentIndex != selectedIndex {
            selectedIndex = currentIndex
            updateAppearance()
            
            // 通知代理
            delegate?.tabStripView(self, didSelectTabAt: currentIndex)
        }
        
        // 实时更新指示器位置（跟随滚动进度）
        updateIndicatorPosition(with: contentOffsetX, pageWidth: pageWidth)
    }
    
    private func updateIndicatorPosition(with contentOffsetX: CGFloat, pageWidth: CGFloat) {
        guard titleButtons.count >= 2 && pageWidth > 0 else {
            return
        }
        
        // 计算滚动进度
        var progress = contentOffsetX / pageWidth
        progress = max(0, min(progress, CGFloat(titleButtons.count - 1)))
        
        // 获取当前页和下一页的索引
        let fromIndex = Int(floor(progress))
        let toIndex = Int(ceil(progress))
        
        // 确保索引范围有效
        let validFromIndex = max(0, min(fromIndex, titleButtons.count - 1))
        let validToIndex = max(0, min(toIndex, titleButtons.count - 1))
        
        // 计算插值比例
        let ratio = progress - CGFloat(fromIndex)
        
        // 获取两个按钮的位置
        let fromButton = titleButtons[validFromIndex]
        let toButton = titleButtons[validToIndex]
        
        let fromCenter = stackView.convert(fromButton.center, to: self)
        let toCenter = stackView.convert(toButton.center, to: self)
        
        // 插值计算指示器的X位置
        let indicatorCenterX = fromCenter.x + (toCenter.x - fromCenter.x) * ratio
        let indicatorX = indicatorCenterX - configuration.indicatorSize.width / 2.0
        let indicatorY = bounds.height - configuration.indicatorSize.height - configuration.indicatorVerticalMargin

        // 更新指示器位置
        indicatorView.frame = CGRect(x: indicatorX, y: indicatorY,
                                   width: configuration.indicatorSize.width,
                                   height: configuration.indicatorSize.height)
    }
    
    // MARK: - Dealloc
    
    deinit {
        if let linkedScrollView = linkedScrollView {
            linkedScrollView.removeObserver(self, forKeyPath: "contentOffset")
        }
    }
}

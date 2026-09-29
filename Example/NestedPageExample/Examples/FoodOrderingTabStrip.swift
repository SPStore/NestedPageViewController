import UIKit
import JXCategoryView

/// 基于已接入的 JXCategoryView 定制外卖 Tab，分页与指示器仍由第三方组件负责。
final class FoodOrderingTabStrip: JXCategoryTitleImageView {
    static let reviewCount = "1710"
    static let reviewCountFont = UIFont.systemFont(ofSize: 10)
    private let topImage = UIImage(systemName: "arrow.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
    private let titleIndicator = FoodTitleAlignedIndicatorLineView()
    private var arrowWidth: CGFloat { showsBackToTop ? imageSize.width + titleImageSpacing : 0 }
    private var reviewTrailingWidth: CGFloat {
        let isSelected = dataSource?.dropFirst().first?.isSelected ?? (selectedIndex == 1)
        let font = (isSelected ? titleSelectedFont : titleFont) ?? UIFont.systemFont(ofSize: 18)
        // 空格沿用主标题字号，评价数使用独立小字号；两者都不参与跟踪器居中。
        return (" " as NSString).size(withAttributes: [.font: font]).width
            + (Self.reviewCount as NSString).size(withAttributes: [.font: Self.reviewCountFont]).width
    }

    var showsBackToTop = false {
        didSet {
            guard oldValue != showsBackToTop else { return }
            let image: Any = showsBackToTop ? (topImage ?? UIImage()) : NSNull()
            imageInfoArray = [image, NSNull(), NSNull()]
            selectedImageInfoArray = imageInfoArray
            imageTypes[0] = NSNumber(value: (showsBackToTop ? JXCategoryTitleImageType.rightImage : .onlyTitle).rawValue)
            guard let first = dataSource?.first else { return }
            // 非吸顶时不占位，吸顶后才加上箭头及间距。只更新宽度模型与 Tab 布局，
            // 不调用 reloadData / refreshState，避免把正在横滑的分页吸回选中页。
            first.cellWidth = preferredCellWidth(at: 0)
            reloadCell(at: 0)
            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
            refreshIndicatorForCurrentPosition()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        titles = ["点餐", "评价 \(Self.reviewCount)", "商家"]
        titleFont = .systemFont(ofSize: 18)
        titleSelectedFont = .systemFont(ofSize: 18, weight: .semibold)
        titleColor = .secondaryLabel
        titleSelectedColor = .label
        backgroundColor = .systemBackground
        isAverageCellSpacingEnabled = false
        contentEdgeInsetLeft = 16
        contentEdgeInsetRight = 16
        cellSpacing = 24
        isContentScrollViewClickTransitionAnimationEnabled = false
        imageTypes = Array(repeating: NSNumber(value: JXCategoryTitleImageType.onlyTitle.rawValue), count: 3)
        imageSize = CGSize(width: 14, height: 14)
        titleImageSpacing = 4
        imageInfoArray = [NSNull(), NSNull(), NSNull()]
        selectedImageInfoArray = imageInfoArray
        loadImageBlock = { imageView, info in
            imageView?.image = info as? UIImage
            imageView?.tintColor = .label
        }
        let line = titleIndicator
        line.trailingWidthAtIndex = { [weak self] index in
            guard let self else { return 0 }
            switch index {
            case 0: return self.arrowWidth
            case 1: return self.reviewTrailingWidth
            default: return 0
            }
        }
        line.indicatorColor = .systemOrange
        line.indicatorWidth = 20
        line.indicatorHeight = 3
        // Tab 高度同步增加 4pt：跟踪器距底部 8pt，同时保持它与居中文字的距离不变。
        line.verticalMargin = 8
        indicators = [line]
        accessibilityIdentifier = "food.tabs"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func preferredCellClass() -> AnyClass! { FoodOrderingTabCell.self }

    override func preferredCellWidth(at index: Int) -> CGFloat {
        // 评价数使用独立小字号，不能采用第三方按整段主标题字号计算的宽度。
        switch index {
        case 0: return 36 + arrowWidth
        case 1: return 70
        default: return 36
        }
    }

    private func refreshIndicatorForCurrentPosition() {
        guard let dataSource, !dataSource.isEmpty else { return }
        let position: CGFloat
        if let scrollView = contentScrollView, scrollView.bounds.width > 0 {
            position = scrollView.contentOffset.x / scrollView.bounds.width
        } else {
            position = CGFloat(selectedIndex)
        }
        let progress = min(CGFloat(dataSource.count - 1), max(0, position))
        let left = Int(floor(progress))
        let right = min(left + 1, dataSource.count - 1)
        let model = JXCategoryIndicatorParamsModel()
        model.selectedIndex = left
        model.selectedCellFrame = getTargetCellFrame(left)
        model.leftIndex = left
        model.leftCellFrame = getTargetCellFrame(left)
        model.rightIndex = right
        model.rightCellFrame = getTargetCellFrame(right)
        model.percent = progress - CGFloat(left)
        titleIndicator.jx_refreshState(model)
        titleIndicator.jx_contentScrollViewDidScroll(model)
    }
}

/// 扣除主标题右侧的箭头、评价数等附加内容，点击及横滑均按主标题中心定位。
private final class FoodTitleAlignedIndicatorLineView: JXCategoryIndicatorLineView {
    var trailingWidthAtIndex: ((Int) -> CGFloat)?

    private func titleCenteredFrame(_ frame: CGRect, at index: Int) -> CGRect {
        frame.offsetBy(dx: -(trailingWidthAtIndex?(index) ?? 0) / 2, dy: 0)
    }

    override func jx_refreshState(_ model: JXCategoryIndicatorParamsModel!) {
        let original = model.selectedCellFrame
        defer { model.selectedCellFrame = original }
        model.selectedCellFrame = titleCenteredFrame(original, at: model.selectedIndex)
        super.jx_refreshState(model)
    }

    override func jx_selectedCell(_ model: JXCategoryIndicatorParamsModel!) {
        let original = model.selectedCellFrame
        defer { model.selectedCellFrame = original }
        model.selectedCellFrame = titleCenteredFrame(original, at: model.selectedIndex)
        super.jx_selectedCell(model)
    }

    override func jx_contentScrollViewDidScroll(_ model: JXCategoryIndicatorParamsModel!) {
        let left = model.leftCellFrame
        let right = model.rightCellFrame
        defer {
            model.leftCellFrame = left
            model.rightCellFrame = right
        }
        // 横滑时也在两个正确的中心之间插值，不能只在最终选中时挪动指示器。
        model.leftCellFrame = titleCenteredFrame(left, at: model.leftIndex)
        model.rightCellFrame = titleCenteredFrame(right, at: model.rightIndex)
        super.jx_contentScrollViewDidScroll(model)
    }
}

private final class FoodOrderingTabCell: JXCategoryTitleImageCell {
    override func reloadData(_ cellModel: JXCategoryBaseCellModel!) {
        super.reloadData(cellModel)
        guard let model = cellModel as? JXCategoryTitleImageCellModel else { return }
        accessibilityIdentifier = "food.tab.\(model.index)"
        accessibilityTraits = model.isSelected ? [.button, .selected] : [.button]
        if model.index == 1 {
            let text = NSMutableAttributedString(string: "评价 ", attributes: [.font: titleLabel.font!])
            text.append(NSAttributedString(string: FoodOrderingTabStrip.reviewCount, attributes: [
                .font: FoodOrderingTabStrip.reviewCountFont, .foregroundColor: UIColor.secondaryLabel
            ]))
            titleLabel.attributedText = text
            accessibilityLabel = "评价"
            accessibilityValue = "\(FoodOrderingTabStrip.reviewCount) 条评价"
        } else {
            accessibilityValue = model.index == 0 && model.imageInfo is UIImage ? "返回顶部" : nil
        }
        accessibilityHint = model.index == 0 && model.imageInfo is UIImage ? "展开店铺封面和共享轮播，保留两侧列表阅读位置" : nil
    }
}

import UIKit

/// 两处轮播共用的横向滚动视图。只承接横拖，纵拖留给外层商品列表。
final class FoodCarouselView: UIScrollView {
    enum Style { case shared, products }
    private let style: Style
    private let cards: [FoodPromoCard]
    private var lastSize = CGSize.zero

    init(style: Style) {
        self.style = style
        switch style {
        case .shared:
            cards = [
                FoodPromoCard(title: "秋日上新", subtitle: "应季鲜味\n好好吃饭", symbol: "leaf.fill", color: .systemGreen),
                FoodPromoCard(title: "招牌热销", subtitle: "现炒好味 · 每日推荐", symbol: "flame.fill", color: .systemOrange),
                FoodPromoCard(title: "超值双人餐", subtitle: "两个人的\n一桌好菜", symbol: "fork.knife", color: .systemIndigo),
                FoodPromoCard(title: "暖心煲汤", subtitle: "慢火炖煮\n暖胃暖心", symbol: "mug.fill", color: .systemBrown),
                FoodPromoCard(title: "清爽时蔬", subtitle: "每日采购\n新鲜现炒", symbol: "carrot.fill", color: .systemTeal),
                FoodPromoCard(title: "午间好食光", subtitle: "一人食\n也要丰盛", symbol: "sun.max.fill", color: .systemPink)
            ]
        case .products:
            cards = [
                FoodPromoCard(title: "好食材，放心吃", subtitle: "右侧专属轮播  1 / 3", symbol: "carrot.fill", color: .systemTeal),
                FoodPromoCard(title: "现炒现做", subtitle: "右侧专属轮播  2 / 3", symbol: "flame.fill", color: .systemOrange),
                FoodPromoCard(title: "一人食也丰盛", subtitle: "右侧专属轮播  3 / 3", symbol: "fork.knife", color: .systemPurple)
            ]
        }
        super.init(frame: .zero)
        contentInsetAdjustmentBehavior = .never
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        scrollsToTop = false
        isDirectionalLockEnabled = true
        alwaysBounceHorizontal = true
        isPagingEnabled = style == .products
        decelerationRate = style == .shared ? .normal : .fast
        let identifier = style == .shared ? "food.sharedCarousel" : "food.productCarousel"
        accessibilityIdentifier = identifier
        for (index, card) in cards.enumerated() {
            card.accessibilityIdentifier = "\(identifier).card.\(index)"
            addSubview(card)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer {
            let velocity = panGestureRecognizer.velocity(in: self)
            guard abs(velocity.x) > abs(velocity.y) else { return false }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != lastSize, bounds.width > 0, bounds.height > 0 else { return }
        let page = lastSize.width > 0 ? contentOffset.x / lastSize.width : 0
        lastSize = bounds.size
        let shared = style == .shared
        let width = shared ? min(168, bounds.width * 0.43) : bounds.width
        let spacing: CGFloat = shared ? 12 : 0
        for (index, card) in cards.enumerated() {
            card.frame = CGRect(x: spacing + CGFloat(index) * (width + spacing), y: shared ? 12 : 4,
                                width: width, height: max(0, bounds.height - (shared ? 24 : 8)))
        }
        contentSize = CGSize(width: CGFloat(cards.count) * (width + spacing) + spacing, height: bounds.height)
        let x = shared ? contentOffset.x : page * bounds.width
        contentOffset = CGPoint(x: max(0, min(x, contentSize.width - bounds.width)), y: 0)
    }

}

private final class FoodPromoCard: UIView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let icon = UIImageView()

    init(title: String, subtitle: String, symbol: String, color: UIColor) {
        super.init(frame: .zero)
        backgroundColor = color.withAlphaComponent(0.14)
        layer.cornerRadius = 16
        clipsToBounds = true
        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: 21)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.numberOfLines = 2
        subtitleLabel.textColor = .secondaryLabel
        icon.image = UIImage(systemName: symbol)
        icon.tintColor = color
        icon.contentMode = .scaleAspectFit
        [icon, titleLabel, subtitleLabel].forEach(addSubview)
        isAccessibilityElement = true
        accessibilityLabel = "\(title)，\(subtitle)"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let compact = bounds.height < 140
        titleLabel.frame = CGRect(x: 16, y: 14, width: max(0, bounds.width - 32), height: 28)
        subtitleLabel.frame = CGRect(x: 16, y: compact ? 48 : bounds.height - 46,
                                     width: max(0, bounds.width - (compact ? 78 : 32)), height: 34)
        let size: CGFloat = compact ? 36 : 70
        icon.frame = CGRect(x: bounds.width - size - 16, y: compact ? bounds.height - size - 12 : 58,
                            width: size, height: size)
    }
}

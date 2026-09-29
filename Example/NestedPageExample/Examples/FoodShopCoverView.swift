import UIKit

/// 本地绘制的暖色店铺封面，无网络图片依赖；底部信息卡与顶部品牌背景分层。
final class FoodShopCoverView: UIView {
    var topContentInset: CGFloat = 0 {
        didSet { if topContentInset != oldValue { setNeedsLayout() } }
    }
    override class var layerClass: AnyClass { CAGradientLayer.self }
    private let ornament = UIImageView(image: UIImage(systemName: "fork.knife.circle.fill"))
    private let slogan = UILabel()
    private let tagline = UILabel()
    private let information = UIView()
    private let logo = UILabel()
    private let name = UILabel()
    private let details = UILabel()
    private let delivery = UILabel()
    private let offer = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let gradient = layer as! CAGradientLayer
        gradient.colors = [UIColor(red: 0.27, green: 0.14, blue: 0.09, alpha: 1).cgColor,
                           UIColor(red: 0.62, green: 0.33, blue: 0.14, alpha: 1).cgColor]
        gradient.startPoint = .zero
        gradient.endPoint = CGPoint(x: 1, y: 1)
        clipsToBounds = true
        ornament.tintColor = UIColor(red: 1, green: 0.82, blue: 0.47, alpha: 0.26)
        ornament.contentMode = .scaleAspectFit
        ornament.transform = CGAffineTransform(rotationAngle: -.pi / 10)
        ornament.isAccessibilityElement = false
        slogan.text = "巷口有烟火"
        slogan.accessibilityIdentifier = "food.slogan"
        slogan.font = .systemFont(ofSize: 25, weight: .semibold)
        slogan.textColor = UIColor(red: 1, green: 0.90, blue: 0.70, alpha: 1)
        tagline.text = "一日三餐 · 现炒家常味"
        tagline.font = .systemFont(ofSize: 11, weight: .medium)
        tagline.textColor = .white.withAlphaComponent(0.8)
        information.backgroundColor = .systemBackground
        information.layer.cornerRadius = 16
        information.layer.cornerCurve = .continuous
        logo.text = "巷口\n小馆"
        logo.numberOfLines = 2
        logo.textAlignment = .center
        logo.font = .systemFont(ofSize: 16, weight: .heavy)
        logo.textColor = UIColor(red: 1, green: 0.90, blue: 0.70, alpha: 1)
        logo.backgroundColor = UIColor(red: 0.42, green: 0.20, blue: 0.12, alpha: 1)
        logo.layer.cornerRadius = 10
        logo.clipsToBounds = true
        name.text = "巷口小馆 · 现做家常菜"
        name.font = .systemFont(ofSize: 19, weight: .bold)
        name.adjustsFontSizeToFitWidth = true
        name.minimumScaleFactor = 0.7
        name.accessibilityIdentifier = "food.shop"
        details.text = "★ 4.9  ·  月售 3000+  ·  家常菜"
        details.textColor = .secondaryLabel
        details.font = .systemFont(ofSize: 11)
        delivery.text = "约 30 分钟送达  ·  配送费 ¥2"
        delivery.font = .systemFont(ofSize: 12, weight: .medium)
        offer.text = "  新客立减 ¥8   ·   满 30 减 6  "
        offer.font = .systemFont(ofSize: 11, weight: .medium)
        offer.textColor = .systemOrange
        offer.backgroundColor = .systemOrange.withAlphaComponent(0.10)
        offer.layer.cornerRadius = 5
        offer.clipsToBounds = true
        [ornament, slogan, tagline, information].forEach(addSubview)
        [logo, name, details, delivery, offer].forEach(information.addSubview)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        ornament.bounds = CGRect(x: 0, y: 0, width: 116, height: 116)
        let sloganTop = topContentInset + 24
        ornament.center = CGPoint(x: bounds.width - 64, y: sloganTop + 24)
        slogan.frame = CGRect(x: 20, y: sloganTop, width: max(0, bounds.width - 132), height: 32)
        tagline.frame = CGRect(x: 21, y: sloganTop + 35, width: max(0, bounds.width - 132), height: 16)
        let informationTop = sloganTop + 68
        information.frame = CGRect(x: 12, y: informationTop, width: max(0, bounds.width - 24), height: max(0, bounds.height - informationTop - 28))
        logo.frame = CGRect(x: 12, y: 12, width: 46, height: 46)
        let textWidth = max(0, information.bounds.width - 82)
        name.frame = CGRect(x: 68, y: 12, width: textWidth, height: 25)
        details.frame = CGRect(x: 68, y: 40, width: textWidth, height: 16)
        delivery.frame = CGRect(x: 12, y: 66, width: information.bounds.width - 24, height: 17)
        offer.frame = CGRect(x: 12, y: 90, width: min(192, information.bounds.width - 24), height: 20)
    }
}

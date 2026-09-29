import UIKit

/// 本地绘制的暖色店铺封面，无网络图片依赖；底部信息卡与顶部品牌背景分层。
final class FoodShopCoverView: UIView {
    enum FulfillmentMode: Int {
        case delivery, pickup
    }

    private(set) var fulfillmentMode: FulfillmentMode = .delivery
    var onFulfillmentModeChanged: (() -> Void)?
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
    private let fulfillmentControl = UISegmentedControl(items: ["外送", "自取"])
    private let delivery = UILabel()
    private let serviceDetail = UILabel()
    private let offer = UILabel()
    private let deliveryNote = UILabel()

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
        information.accessibilityIdentifier = "food.shopInformation"
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
        details.textColor = .secondaryLabel
        details.font = .systemFont(ofSize: 11)
        fulfillmentControl.selectedSegmentIndex = fulfillmentMode.rawValue
        fulfillmentControl.selectedSegmentTintColor = .systemOrange.withAlphaComponent(0.22)
        fulfillmentControl.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                                                  .foregroundColor: UIColor.label], for: .selected)
        fulfillmentControl.accessibilityIdentifier = "food.fulfillment"
        fulfillmentControl.addTarget(self, action: #selector(changeFulfillmentMode), for: .valueChanged)
        delivery.font = .systemFont(ofSize: 12, weight: .medium)
        delivery.numberOfLines = 0
        delivery.accessibilityIdentifier = "food.serviceSummary"
        serviceDetail.font = .systemFont(ofSize: 11)
        serviceDetail.textColor = .secondaryLabel
        serviceDetail.numberOfLines = 0
        serviceDetail.accessibilityIdentifier = "food.serviceDetail"
        offer.font = .systemFont(ofSize: 11, weight: .medium)
        offer.textColor = .systemOrange
        offer.backgroundColor = .systemOrange.withAlphaComponent(0.10)
        offer.layer.cornerRadius = 5
        offer.clipsToBounds = true
        offer.numberOfLines = 0
        deliveryNote.text = "热饭热菜，骑手送到家 · 支持预约配送"
        deliveryNote.font = .systemFont(ofSize: 11)
        deliveryNote.textColor = .secondaryLabel
        deliveryNote.numberOfLines = 0
        [ornament, slogan, tagline, information].forEach(addSubview)

        let titles = UIStackView(arrangedSubviews: [name, details])
        titles.axis = .vertical
        titles.spacing = 3
        let identity = UIStackView(arrangedSubviews: [logo, titles])
        identity.alignment = .center
        identity.spacing = 10
        let content = UIStackView(arrangedSubviews: [identity, fulfillmentControl, delivery, serviceDetail, offer, deliveryNote])
        content.axis = .vertical
        content.spacing = 10
        content.translatesAutoresizingMaskIntoConstraints = false
        information.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: information.topAnchor, constant: 12),
            content.leadingAnchor.constraint(equalTo: information.leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(equalTo: information.trailingAnchor, constant: -12),
            content.bottomAnchor.constraint(equalTo: information.bottomAnchor, constant: -12),
            logo.widthAnchor.constraint(equalToConstant: 46),
            logo.heightAnchor.constraint(equalToConstant: 46),
            fulfillmentControl.heightAnchor.constraint(equalToConstant: 34)
        ])
        updateInformation()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 封面高度由导航栏、品牌区和信息卡的实际内容共同决定，窄屏换行时也不裁剪。
    func preferredHeight(for width: CGFloat) -> CGFloat {
        let size = information.systemLayoutSizeFitting(
            CGSize(width: max(1, width - 24), height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel
        )
        return ceil(topContentInset + 24 + 68 + size.height + 16)
    }

    @objc private func changeFulfillmentMode() {
        guard let mode = FulfillmentMode(rawValue: fulfillmentControl.selectedSegmentIndex),
              mode != fulfillmentMode else { return }
        fulfillmentMode = mode
        updateInformation()
        onFulfillmentModeChanged?()
    }

    private func updateInformation() {
        let isDelivery = fulfillmentMode == .delivery
        details.text = isDelivery ? "★ 4.9  ·  月售 3000+  ·  家常菜" : "★ 4.9  ·  现点现做  ·  支持打包"
        delivery.text = isDelivery ? "约 30 分钟送达  ·  配送费 ¥2" : "约 15 分钟可取  ·  免配送费"
        serviceDetail.text = isDelivery ? "满 ¥20 起送  ·  配送范围 3 km" : "幸福路 18 号  ·  距您 800 m"
        offer.text = isDelivery ? "  新客立减 ¥8   ·   满 30 减 6  " : "  到店自取享 9 折   ·   无需排队  "
        deliveryNote.isHidden = !isDelivery
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ornament.bounds = CGRect(x: 0, y: 0, width: 116, height: 116)
        let sloganTop = topContentInset + 24
        ornament.center = CGPoint(x: bounds.width - 64, y: sloganTop + 24)
        slogan.frame = CGRect(x: 20, y: sloganTop, width: max(0, bounds.width - 132), height: 32)
        tagline.frame = CGRect(x: 21, y: sloganTop + 35, width: max(0, bounds.width - 132), height: 16)
        let informationTop = sloganTop + 68
        information.frame = CGRect(x: 12, y: informationTop, width: max(0, bounds.width - 24), height: max(0, bounds.height - informationTop - 16))
    }
}

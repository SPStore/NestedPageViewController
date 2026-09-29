//
//  SettingsViewController.swift
//  NestedPageViewController
//
//  Created by 乐升平 on 2025/1/25.
//  Copyright © 2025 SPStore. All rights reserved.
//

import UIKit
import NestedPageViewController

// 配置项数据模型
struct NestedPageConfigItem {
    let title: String
    let description: String
    let keyPath: String
    let type: ConfigType
    let defaultValue: Any
    
    enum ConfigType {
        case bool
        case float
    }
}

// 全局配置管理器
@objcMembers
class NestedPageConfig: NSObject {
    @objc static let shared = NestedPageConfig()
    
    // BOOL 类型配置
    @objc dynamic var keepsContentScrollPosition: Bool = true
    @objc dynamic var showsVerticalScrollIndicator: Bool = false
    @objc dynamic var bounces: Bool = true
    @objc dynamic var allowsSwipeToChangePage: Bool = true
    @objc dynamic var headerMovesOnlyWhenTouchingHeaderDuringHover: Bool = false
    @objc dynamic var interruptsScrollingWhenTransitioningToFullStick: Bool = false
    @objc dynamic var autoAdjustsContentSizeMinimumHeight: Bool = true
    
    private override init() {
        super.init()
        // 配置已通过属性默认值设置，无需额外加载
    }
    
    // 获取所有配置项
    func getAllConfigItems() -> [NestedPageConfigItem] {
        return [
            NestedPageConfigItem(
                title: "保持内容滚动位置",
                description: "切换页面及更新头部布局时是否保持子列表的滚动位置",
                keyPath: "keepsContentScrollPosition",
                type: .bool,
                defaultValue: true
            ),
            NestedPageConfigItem(
                title: "显示垂直滚动指示器",
                description: "是否显示垂直滚动条",
                keyPath: "showsVerticalScrollIndicator",
                type: .bool,
                defaultValue: false
            ),
            NestedPageConfigItem(
                title: "启用弹性效果",
                description: "控制列表到达顶部或底部后的回弹，修改后重新进入示例生效；关闭后无法下拉刷新",
                keyPath: "bounces",
                type: .bool,
                defaultValue: true
            ),
            NestedPageConfigItem(
                title: "允许滑动切换页面",
                description: "是否允许通过滑动手势切换页面",
                keyPath: "allowsSwipeToChangePage",
                type: .bool,
                defaultValue: true
            ),
            NestedPageConfigItem(
                title: "头部半悬停时需触摸头部头部才移动",
                description: "头部悬停在中间位置时，只有触摸头部区域向上滚动才会带动头部移动",
                keyPath: "headerMovesOnlyWhenTouchingHeaderDuringHover",
                type: .bool,
                defaultValue: false
            ),
            NestedPageConfigItem(
                title: "过渡到吸顶时中断惯性滚动",
                description: "从未完全吸顶过渡到完全吸顶时，是否中断内容滚动视图的惯性滚动",
                keyPath: "interruptsScrollingWhenTransitioningToFullStick",
                type: .bool,
                defaultValue: false
            ),
            NestedPageConfigItem(
                title: "自动调整内容视图最小高度",
                description: "确保内容视图的高度至少等于可见区域高度，防止内容过少时无法滚动到顶部",
                keyPath: "autoAdjustsContentSizeMinimumHeight",
                type: .bool,
                defaultValue: true
            )
        ]
    }
    
    // 注意：配置只在内存中保存，应用重启后会重置为默认值
    
    // 应用配置到NestedPageViewController
    @objc func applyConfig(to pageViewController: NestedPageViewController) {
        pageViewController.keepsContentScrollPosition = keepsContentScrollPosition
        pageViewController.showsVerticalScrollIndicator = showsVerticalScrollIndicator
        pageViewController.bounces = bounces
        pageViewController.allowsSwipeToChangePage = allowsSwipeToChangePage
        pageViewController.headerMovesOnlyWhenTouchingHeaderDuringHover = headerMovesOnlyWhenTouchingHeaderDuringHover
        pageViewController.interruptsScrollingWhenTransitioningToFullStick = interruptsScrollingWhenTransitioningToFullStick
        pageViewController.autoAdjustsContentSizeMinimumHeight = autoAdjustsContentSizeMinimumHeight
    }
}

class SettingsViewController: UIViewController {
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.delegate = self
        table.dataSource = self
        table.backgroundColor = .systemGroupedBackground
        table.register(BoolConfigCell.self, forCellReuseIdentifier: "BoolConfigCell")
        table.register(FloatConfigCell.self, forCellReuseIdentifier: "FloatConfigCell")
        return table
    }()
    
    private var configItems: [NestedPageConfigItem] = []
    private let config = NestedPageConfig.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadConfigItems()
    }
    
    private func setupUI() {
        title = "配置"
        view.backgroundColor = .systemGroupedBackground
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func loadConfigItems() {
        configItems = config.getAllConfigItems()
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension SettingsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return configItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = configItems[indexPath.row]
        
        switch item.type {
        case .bool:
            let cell = tableView.dequeueReusableCell(withIdentifier: "BoolConfigCell", for: indexPath) as! BoolConfigCell
            cell.configure(with: item, config: config)
            return cell
        case .float:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FloatConfigCell", for: indexPath) as! FloatConfigCell
            cell.configure(with: item, config: config)
            return cell
        }
    }
}

// MARK: - UITableViewDelegate
extension SettingsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let item = configItems[indexPath.row]
        return item.type == .float ? 80 : 60
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "NestedPageViewController 配置选项"
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "修改这些配置会影响所有使用 NestedPageViewController 的示例页面，冷启动后将恢复默认值"
    }
}

// MARK: - Custom Cells

// BOOL 类型配置单元格
class BoolConfigCell: UITableViewCell {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()
    
    private let switchControl: UISwitch = {
        let switchView = UISwitch()
        switchView.translatesAutoresizingMaskIntoConstraints = false
        return switchView
    }()
    
    private var configItem: NestedPageConfigItem?
    private var config: NestedPageConfig?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .systemBackground
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(switchControl)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: switchControl.leadingAnchor, constant: -16),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            switchControl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            switchControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        
        switchControl.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
    }
    
    @objc private func switchValueChanged() {
        guard let configItem = configItem,
              let config = config else { return }
        
        config.setValue(switchControl.isOn, forKey: configItem.keyPath)
        // 配置只在内存中保存，不持久化到沙盒
    }
    
    func configure(with item: NestedPageConfigItem, config: NestedPageConfig) {
        self.configItem = item
        self.config = config
        
        titleLabel.text = item.title
        descriptionLabel.text = item.keyPath
        
        let currentValue = config.value(forKey: item.keyPath) as? Bool ?? false
        switchControl.isOn = currentValue
    }
}

// CGFloat 类型配置单元格
class FloatConfigCell: UITableViewCell {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()
    
    private let textField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.borderStyle = .roundedRect
        field.keyboardType = .decimalPad
        field.textAlignment = .center
        field.font = .systemFont(ofSize: 16)
        return field
    }()
    
    private var configItem: NestedPageConfigItem?
    private var config: NestedPageConfig?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .systemBackground
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(textField)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: textField.leadingAnchor, constant: -16),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textField.widthAnchor.constraint(equalToConstant: 80),
            textField.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        textField.addTarget(self, action: #selector(textFieldDidEndEditing), for: .editingDidEnd)
        
        // 添加工具栏以便关闭键盘
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.items = [flexSpace, doneButton]
        textField.inputAccessoryView = toolbar
    }
    
    @objc private func dismissKeyboard() {
        textField.resignFirstResponder()
    }
    
    @objc private func textFieldDidChange() {
        validateAndSaveValue()
    }
    
    @objc private func textFieldDidEndEditing() {
        validateAndSaveValue()
    }
    
    private func validateAndSaveValue() {
        guard let configItem = configItem,
              let config = config,
              let text = textField.text,
              !text.isEmpty else { return }
        
        if let value = Double(text) {
            let clampedValue = max(0.0, min(100.0, value)) // 限制在0-100范围内
            let cgFloatValue = CGFloat(clampedValue)
            
            config.setValue(cgFloatValue, forKey: configItem.keyPath)
            // 配置只在内存中保存，不持久化到沙盒
            
            // 更新显示值（防止用户输入超出范围的值）
            if clampedValue != value {
                textField.text = String(format: "%.1f", clampedValue)
            }
        }
    }
    
    func configure(with item: NestedPageConfigItem, config: NestedPageConfig) {
        self.configItem = item
        self.config = config
        
        titleLabel.text = item.title
        descriptionLabel.text = item.keyPath
        
        let currentValue = config.value(forKey: item.keyPath) as? CGFloat ?? 0.0
        textField.text = String(format: "%.1f", currentValue)
    }
}

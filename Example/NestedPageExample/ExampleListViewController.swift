//
//  ExampleListViewController.swift
//  NestedPageViewController Examples
//
//  Created by 乐升平 on 2025/1/25.
//  Copyright © 2025 SPStore. All rights reserved.
//
//  示例入口：选择不同的使用方式进入对应示例

import UIKit
import NestedPageViewController

class ExampleListViewController: UIViewController {
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.delegate = self
        table.dataSource = self
        // 外屏可用宽度较窄，标题和说明换行后由内容决定行高。
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 60
        // 不再注册cell，将在cellForRowAt中创建带样式的cell
        table.backgroundColor = .systemGroupedBackground
        return table
    }()
    
    private var dataSource: [ExampleGroup] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }
    
    private func setupUI() {
        title = "示例列表"
        view.backgroundColor = .systemBackground
        
        navigationItem.backButtonTitle = ""   // 只保留返回箭头
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func loadData() {
        dataSource = ExampleTypeModel.demoGroups()
        tableView.reloadData()
    }

}

// MARK: - UITableViewDataSource
extension ExampleListViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource[section].examples.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return dataSource[section].title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 使用 subtitle 样式的 cell
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "ExampleCell")
        let model = dataSource[indexPath.section].examples[indexPath.row]
        
        cell.textLabel?.text = model.title
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.text = model.detailTitle
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.numberOfLines = 0
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ExampleListViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let model = dataSource[indexPath.section].examples[indexPath.row]
        let contentViewController = model.targetClass.init()
        contentViewController.title = model.title
        // 继承型示例的根视图由系统管理，使用外层容器约束其四边，不干预组件内部布局。
        let viewController: UIViewController
        if contentViewController is NoBouncesViewController || contentViewController is IncludeTabBarViewController {
            viewController = SafeAreaExampleHostViewController(contentViewController: contentViewController)
        } else {
            viewController = contentViewController
        }
        viewController.title = model.title
        switch model.action {
        case .push:
            // 如果不是IncludeTabBarViewController类型，才隐藏TabBar
            if !(contentViewController is IncludeTabBarViewController) {
                viewController.hidesBottomBarWhenPushed = true
            }
            navigationController?.pushViewController(viewController, animated: true)
        case .present:
            let navController = UINavigationController(rootViewController: viewController)
            present(navController, animated: true)
        }
    }
    
}

/// 为继承 NestedPageViewController 的示例提供安全区宿主，示例本身仍展示继承式用法。
final class SafeAreaExampleHostViewController: UIViewController {
    let contentViewController: UIViewController
    private var lastPageSize = CGSize.zero

    init(contentViewController: UIViewController) {
        self.contentViewController = contentViewController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        addChild(contentViewController)
        view.addSubview(contentViewController.view)
        contentViewController.view.translatesAutoresizingMaskIntoConstraints = false
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            contentViewController.view.topAnchor.constraint(equalTo: safeArea.topAnchor),
            contentViewController.view.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            contentViewController.view.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            contentViewController.view.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
        ])
        contentViewController.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let pager = contentViewController as? NestedPageViewController else { return }
        let size = pager.view.bounds.size
        guard size != lastPageSize else { return }
        lastPageSize = size
        if pager.viewController(at: pager.currentIndex) != nil { pager.updateLayouts() }
    }
}

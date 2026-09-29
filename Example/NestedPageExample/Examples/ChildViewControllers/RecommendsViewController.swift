//
//  RecommendsViewController.swift
//  NestedPageViewController
//
//  Created by 乐升平 on 2025/8/24.
//

import UIKit
import NestedPageViewController
import MJRefresh

class RecommendsViewController: ChildBaseViewController {
    
    private lazy var tableView: MyTableView = {
        let tableView = MyTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupRefresh()
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: contentTopAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func setupRefresh() {
        // 根据 refreshType 设置下拉刷新
        switch refreshType {
        case .none:
            // 无刷新，不添加任何刷新控件
            break
        case .partial:
            // 局部刷新
            tableView.mj_header = MJRefreshNormalHeader { [weak self] in
                self?.performPartialRefresh()
            }
        case .global:
            // 全局刷新
            tableView.mj_header = MJRefreshNormalHeader { [weak self] in
                self?.performGlobalRefresh()
            }
        }
        tableView.mj_header?.ignoredScrollViewContentInsetTop = ignoredScrollViewContentInsetTop
    }
    
    private func performPartialRefresh() {
        // 模拟局部刷新逻辑
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // 这里可以实现具体的局部刷新逻辑
            print("RecommendsViewController - 执行局部刷新")
            self?.tableView.reloadData()
            self?.tableView.mj_header?.endRefreshing()
        }
    }
    
    private func performGlobalRefresh() {
        // 模拟全局刷新逻辑
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // 这里可以实现具体的全局刷新逻辑
            print("RecommendsViewController - 执行全局刷新")
            self?.tableView.reloadData()
            self?.tableView.mj_header?.endRefreshing()
        }
    }
}

// MARK: - UITableViewDataSource
extension RecommendsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = "推荐 \(indexPath.row)"
        return cell
    }
}

// MARK: - UITableViewDelegate
extension RecommendsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - NestedPageScrollable
extension RecommendsViewController: NestedPageScrollable {
    var nestedPageContentScrollView: UIScrollView {
        return tableView
    }
}

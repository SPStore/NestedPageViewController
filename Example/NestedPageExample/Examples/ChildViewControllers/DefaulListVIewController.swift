//
//  DefaulListVIewController.swift
//  NestedPageExample
//
//  Created by 乐升平 on 2025/9/4.
//

import UIKit
import NestedPageViewController

class DefaulListVIewController: ChildBaseViewController {
    
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
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// MARK: - UITableViewDataSource
extension DefaulListVIewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 100
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = "\(self.title ?? "默认") \(indexPath.row)"
        return cell
    }
}

// MARK: - UITableViewDelegate
extension DefaulListVIewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - NestedPageScrollable
extension DefaulListVIewController: NestedPageScrollable {
    func contentScrollView() -> UIScrollView {
        return tableView
    }
}

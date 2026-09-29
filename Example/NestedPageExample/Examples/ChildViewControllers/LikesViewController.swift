//
//  LikesViewController.swift
//  NestedPageViewController
//
//  Created by 乐升平 on 2025/8/24.
//

import UIKit
import NestedPageViewController
import MJRefresh

class LikesViewController: ChildBaseViewController {
    
    private lazy var collectionView: MyCollectionView = {
        let layout = UICollectionViewFlowLayout()
        // 布局配置通过代理方法实现
        
        let collectionView = MyCollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .systemBackground
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "NumberCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupRefresh()
    }
    
    private func setupCollectionView() {
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentTopAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
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
            collectionView.mj_header = MJRefreshNormalHeader { [weak self] in
                self?.performPartialRefresh()
            }
        case .global:
            // 全局刷新
            collectionView.mj_header = MJRefreshNormalHeader { [weak self] in
                self?.performGlobalRefresh()
            }
        }
        collectionView.mj_header?.ignoredScrollViewContentInsetTop = ignoredScrollViewContentInsetTop
    }
    
    private func performPartialRefresh() {
        // 模拟局部刷新逻辑
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // 这里可以实现具体的局部刷新逻辑
            print("LikesViewController - 执行局部刷新")
            self?.collectionView.reloadData()
            self?.collectionView.mj_header?.endRefreshing()
        }
    }
    
    private func performGlobalRefresh() {
        // 模拟全局刷新逻辑
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // 这里可以实现具体的全局刷新逻辑
            print("LikesViewController - 执行全局刷新")
            self?.collectionView.reloadData()
            self?.collectionView.mj_header?.endRefreshing()
        }
    }
}

// MARK: - UICollectionViewDataSource
extension LikesViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 100
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NumberCell", for: indexPath)
        
        let labelTag = 1001
        var numberLabel = cell.contentView.viewWithTag(labelTag) as? UILabel
        
        if numberLabel == nil {
            cell.backgroundColor = .systemGray6
            cell.layer.cornerRadius = 8
            
            numberLabel = UILabel()
            numberLabel!.textAlignment = .center
            numberLabel!.font = UIFont.systemFont(ofSize: 20, weight: .medium)
            numberLabel!.textColor = .label
            numberLabel!.tag = labelTag
            numberLabel!.translatesAutoresizingMaskIntoConstraints = false
            
            cell.contentView.addSubview(numberLabel!)
            NSLayoutConstraint.activate([
                numberLabel!.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                numberLabel!.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
            ])
        }
        
        // 更新label文本
        numberLabel!.text = "\(indexPath.row)"
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension LikesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

// 布局配置通过代理方法实现，不要用layout在初始化时设置，因为要演示旋转，旋转后屏幕宽高发生了变化，itemSize需要通过代理的方式更新.
extension LikesViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let availableWidth = collectionView.bounds.width
        let totalHorizontalPadding: CGFloat = 10 + 10 + 10 + 10 // left + right + 2个middle spacing
        let cellWidth = max(1, (availableWidth - totalHorizontalPadding) / 3 - 1.0)
        return CGSize(width: cellWidth, height: cellWidth)
    }
}

// MARK: - NestedPageScrollable
extension LikesViewController: NestedPageScrollable {
    
    var nestedPageContentScrollView: UIScrollView {
        return collectionView
    }
}

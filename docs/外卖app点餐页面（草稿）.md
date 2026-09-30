----------------------------------
|                                |                                          
|                                |
|                                |
|                                |   cover
|                                |
|                                |
|                                |
----------------------------------
|       |       |       |        |   tab                                      
----------------------------------
|                                |                                          
|                                |   containerScrollView的header（可能有可能没有）
|                                |   这个containerScrollView不是指框架内的containerScrollView，是2个子scrollView的父视图
|                                |
----------------------------------
|      |                         |                                          
|      |                         |
|      |                         |
|      |                         |
|      |                         |                                          
|      |                         |
|      |                         |   左collectionView + 右collectionView
|      |                         |
|      |                         |                                          
|      |                         |
|      |                         |
|      |                         |
|      |                         |                                          
|      |                         |
|      |                         |
|      |                         |
|      |                         |                                          
|      |                         |
|      |                         |
|      |                         |
----------------------------------


类似美团、饿了吗的商品点餐页，在第一个tab下的子VC中有2个子scrollView，左边是分类，右边是列表。并切滑动cover区域时有一个小细节：如果左边或者右边子scrollView的偏移量是非初始状态，也就是contentOffset.y是大于0时，这时上下滑动cover的右边区域（手指触摸点的x值在右边子scrollView的区域内），会先滚动右边子scrollView，滑动cover的左边区域（手指触摸点的x值在左边子scrollView的区域内，会先滚动左边子scrollView

我给出一个实现思路（针对第一个子VC）：
最底部是一个容器scrollView（作为本框架中NestedPageScrollable协议里的的nestedPageContentScrollView），其上面添加了2个子scrollView，y值均为0即可，因为本框架会自动设置容器scrollView的contentInset.top和contentOffset.y，2个子scrollVIew会自动显示在tab栏的下方。

3个scrollView大致层级+约束关系如下：

View (Controller.view)
│
└── containerScrollView (UIScrollView)
    │  edges = view.edges
    │
    └── contentView (UIView)
        │  edges = containerScrollView.contentLayoutGuide.edges
        │  width = containerScrollView.frameLayoutGuide.width
        │
        ├── leftScrollView (UITableView/UICollectionView)
        │   top = contentView.top
        │   bottom = contentView.bottom
        │   leading = contentView.leading
        │   width = 30% screen width
        │
        └── rightScrollView (UITableView/UICollectionView)
            top = contentView.top
            bottom = contentView.bottom
            leading = leftTableView.trailing
            trailing = contentView.trailing
            width = 70% screen width

布局完成后，需要保证contentView的高度被撑开，这样containScrollView才会有contentSzie，可以手动计算contentView的高度，也可以重写子scrollView的intrinsicContentSize返回contentSize。
复杂的点在于containerView和2个子scrollView的滚动处理：
1、2个子scrollView禁用滚动，只处理容器scrollView的滚动。这种情况如果右边子scrollView是collectionView并且有多个分组时，sectionHeader需要吸顶，由于collectionView自身不能滚动，可能需要手动计算sectionHeader的吸顶位置
2、containerView和2个子scrollView的滚动可同时发生，但是在合适的时机需要锁定另一个scrollView的滚动...

以上思路只是一个初步思考，需要通过实践去验证，由于时间问题，该示例没有去完成，以后有机会再尝试尝试。



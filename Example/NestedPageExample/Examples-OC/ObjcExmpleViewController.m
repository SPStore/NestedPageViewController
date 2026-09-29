//
//  ObjcExmpleViewController.m
//  NestedPageExample
//
//  Created by 乐升平 on 2025/9/5.
//

#import "ObjcExmpleViewController.h"
#import "NestedPageExample-Swift.h"

@interface ChildViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, NestedPageScrollable>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, strong) NSArray<NSString *> *dataArray;
@end

@implementation ChildViewController

- (instancetype)init {
    self = [super init];
    if (self) {

        _backgroundColor = [UIColor systemBackgroundColor];
        
        // 生成一些示例数据
        NSMutableArray *data = [NSMutableArray array];
        for (int i = 1; i <= 30; i++) {
            [data addObject:[NSString stringWithFormat:@"项目 %d", i]];
        }
        _dataArray = [data copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = self.backgroundColor;
    
    // 使用标题更新数据数组
    NSMutableArray *data = [NSMutableArray array];
    for (int i = 1; i <= 30; i++) {
        [data addObject:[NSString stringWithFormat:@"%@ - 项目 %d", self.title, i]];
    }
    _dataArray = [data copy];
    
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 60;
    if (@available(iOS 26.0, *)) {
        _tableView.topEdgeEffect.hidden = YES;
    }
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    [self.view addSubview:_tableView];
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        // 封面挂在子列表上，列表顶部不能再次扣除导航栏安全区。
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor]
    ]];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = self.dataArray[indexPath.row];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSLog(@"选中了: %@", self.dataArray[indexPath.row]);
}

#pragma mark - NestedPageScrollable

- (nonnull UIScrollView *)nestedPageContentScrollView {
    return self.tableView;
}

@end

@interface ObjcExmpleViewController () <NestedPageViewControllerDataSourceObjc, NestedPageViewControllerDelegateObjc>
@property (nonatomic, strong) NestedPageViewControllerObjcBridge *pageViewControllerBridge;
@property (nonatomic, strong) NSArray<NSString *> *titles;
@property (nonatomic, strong) UIView *coverView;
@property (nonatomic) CGSize lastPageSize;
@end

@implementation ObjcExmpleViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)updateNavigationBarWithProgress:(CGFloat)progress {
    progress = MIN(MAX(progress, 0.0), 1.0);
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:progress];
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor.labelColor colorWithAlphaComponent:progress]};
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;
    self.navigationItem.compactScrollEdgeAppearance = appearance;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    [self updateNavigationBarWithProgress:0.0];
    
    // 设置标题数组
    self.titles = @[@"推荐", @"关注", @"热门", @"附近"];
    
    // 创建封面视图
    self.coverView = [[UIView alloc] init];
    self.coverView.backgroundColor = UIColor.systemPinkColor;
    self.coverView.accessibilityIdentifier = @"objc.cover";
    
    // 添加标题标签
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"ObjC桥接示例";
    titleLabel.font = [UIFont boldSystemFontOfSize:28];
    titleLabel.textColor = UIColor.whiteColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.coverView addSubview:titleLabel];
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.coverView.safeAreaLayoutGuide.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.coverView.safeAreaLayoutGuide.trailingAnchor constant:-20],
        [titleLabel.bottomAnchor constraintEqualToAnchor:self.coverView.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [titleLabel.heightAnchor constraintEqualToConstant:60]
    ]];
    
    // 创建并配置NestedPageViewController
    self.pageViewControllerBridge = [[NestedPageViewControllerObjcBridge alloc] init];
    self.pageViewControllerBridge.dataSource = self;
    self.pageViewControllerBridge.delegate = self;
    
    // 应用全局配置
    [[NestedPageConfig shared] applyConfigTo:self.pageViewControllerBridge.nestedPageViewController];
    self.pageViewControllerBridge.stickyOffset = self.view.safeAreaInsets.top;
    if (@available(iOS 26.0, *)) {
        self.pageViewControllerBridge.containerScrollView.topEdgeEffect.hidden = YES;
    }
    
    // 添加到父视图控制器
    [self.pageViewControllerBridge addToParentViewController:self];
    UIView *pageView = self.pageViewControllerBridge.nestedPageViewController.view;
    pageView.translatesAutoresizingMaskIntoConstraints = NO;
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        // 与 Swift 头部缩放示例一致：封面延伸到屏幕顶部。
        [pageView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [pageView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [pageView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
        [pageView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor]
    ]];
    
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIView *pageView = self.pageViewControllerBridge.nestedPageViewController.view;
    CGSize size = pageView.bounds.size;
    CGFloat stickyOffset = self.view.safeAreaInsets.top;
    if (self.navigationController.navigationBar != nil) {
        CGRect navigationFrame = [self.navigationController.navigationBar convertRect:self.navigationController.navigationBar.bounds
                                                                                toView:pageView];
        stickyOffset = MAX(0, CGRectGetMaxY(navigationFrame));
    }
    if (!CGSizeEqualToSize(size, self.lastPageSize) || fabs(self.pageViewControllerBridge.stickyOffset - stickyOffset) > 0.5) {
        self.lastPageSize = size;
        self.pageViewControllerBridge.stickyOffset = stickyOffset;
        // 安全区改变后同步已加载组件的内部布局。
        if (self.pageViewControllerBridge.nestedPageViewController.childViewControllers.count > 0) {
            [self.pageViewControllerBridge updateLayouts];
        }
    }
}

#pragma mark - NestedPageViewControllerDataSourceObjc

- (NSInteger)numberOfViewControllersIn:(NestedPageViewControllerObjcBridge *)pageViewController {
    return self.titles.count;
}

- (UIViewController<NestedPageScrollable> *)pageViewController:(NestedPageViewControllerObjcBridge *)pageViewController viewControllerAt:(NSInteger)index {
    ChildViewController *childVC = [[ChildViewController alloc] init];
    childVC.title = self.titles[index];
    
    return childVC;
}

- (UIView *)coverViewIn:(NestedPageViewControllerObjcBridge *)pageViewController {
    return self.coverView;
}

- (CGFloat)heightForCoverViewIn:(NestedPageViewControllerObjcBridge *)pageViewController {
    return 240.0;
}

- (UIView *)tabStripIn:(NestedPageViewControllerObjcBridge *)pageViewController {
    NestedPageTabStripConfigurationObjcBridge *config = [[NestedPageTabStripConfigurationObjcBridge alloc] init];
    config.titles = self.titles;
    config.titleColor = UIColor.grayColor;
    config.titleSelectedColor = UIColor.blackColor;
    config.backgroundColor = UIColor.whiteColor;
    config.indicatorColor = UIColor.redColor;
    
    NestedPageTabStripViewObjcBridge *tabStripBridge = [[NestedPageTabStripViewObjcBridge alloc] initWithConfiguration:config];
    tabStripBridge.linkedScrollView = self.pageViewControllerBridge.containerScrollView;
    return tabStripBridge.swiftTabStripView;
}

- (CGFloat)heightForTabStripIn:(NestedPageViewControllerObjcBridge *)pageViewController {
    return 40.0;
}

- (NSArray<NSString *> *)titlesForTabStripIn:(NestedPageViewControllerObjcBridge *)pageViewController {
    return nil;
}

#pragma mark - NestedPageViewControllerDelegateObjc

- (void)pageViewController:(NestedPageViewControllerObjcBridge *)pageViewController didScrollToPageAtIndex:(NSInteger)index {
    NSLog(@"滚动到页面: %@", self.titles[index]);
}

- (void)pageViewController:(NestedPageViewControllerObjcBridge *)pageViewController
contentScrollViewDidScroll:(UIScrollView *)scrollView
              headerOffset:(CGFloat)headerOffset
                 isSticked:(BOOL)isSticked {
    
    CGFloat coverHeight = [self heightForCoverViewIn:pageViewController];
    CGFloat tabHeight = [self heightForTabStripIn:pageViewController];
    CGFloat headerHeight = coverHeight + tabHeight;
    CGFloat scrollDistance = MAX(1, headerHeight - self.pageViewControllerBridge.stickyOffset - tabHeight);
    [self updateNavigationBarWithProgress:headerOffset / scrollDistance];
}

@end

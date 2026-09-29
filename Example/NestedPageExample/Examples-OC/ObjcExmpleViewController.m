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
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    [self.view addSubview:_tableView];
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
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

// 自定义导航栏相关
@property (nonatomic, strong) UIView *customNavigationBar;
@property (nonatomic, strong) UIView *navigationContentView;
@property (nonatomic, strong) UIButton *backButton;
@end

@implementation ObjcExmpleViewController

#pragma mark - 自定义导航栏

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 隐藏系统导航栏
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // 恢复系统导航栏
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)setupCustomNavigationBar {
    // 创建导航栏容器
    self.customNavigationBar = [[UIView alloc] init];
    self.customNavigationBar.backgroundColor = UIColor.systemBackgroundColor;
    self.customNavigationBar.alpha = 0.0; // 初始透明，滚动时显示
    [self.view addSubview:self.customNavigationBar];
    
    // 创建导航内容视图
    self.navigationContentView = [[UIView alloc] init];
    self.navigationContentView.backgroundColor = UIColor.clearColor;
    [self.customNavigationBar addSubview:self.navigationContentView];
    
    // 创建标题标签
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"ObjC桥接示例";
    titleLabel.font = [UIFont boldSystemFontOfSize:17];
    titleLabel.textColor = UIColor.labelColor;
    [self.navigationContentView addSubview:titleLabel];
    
    self.customNavigationBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.navigationContentView.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    UILayoutGuide *contentSafeArea = self.navigationContentView.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        // 只有导航栏背景延伸到状态栏，标题及按钮使用安全区。
        [self.customNavigationBar.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.customNavigationBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.customNavigationBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.customNavigationBar.bottomAnchor constraintEqualToAnchor:self.navigationContentView.bottomAnchor],
        [self.navigationContentView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [self.navigationContentView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [self.navigationContentView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
        [self.navigationContentView.heightAnchor constraintEqualToConstant:44],
        [titleLabel.centerXAnchor constraintEqualToAnchor:contentSafeArea.centerXAnchor],
        [titleLabel.centerYAnchor constraintEqualToAnchor:contentSafeArea.centerYAnchor],
        [titleLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentSafeArea.widthAnchor constant:-112]
    ]];
}

- (void)setupBackButton {
    // 创建固定的返回按钮
    self.backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.backButton setImage:[UIImage systemImageNamed:@"chevron.left"] forState:UIControlStateNormal];
    self.backButton.tintColor = UIColor.systemBlueColor;
    self.backButton.backgroundColor = UIColor.clearColor;
    self.backButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    [self.backButton addTarget:self action:@selector(backButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    // 直接添加到控制器的view上，确保始终可见
    [self.view addSubview:self.backButton];
    self.backButton.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.backButton.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [self.backButton.centerYAnchor constraintEqualToAnchor:self.navigationContentView.safeAreaLayoutGuide.centerYAnchor],
        [self.backButton.widthAnchor constraintEqualToConstant:40],
        [self.backButton.heightAnchor constraintEqualToConstant:30]
    ]];
}

- (void)backButtonTapped {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.whiteColor;
    
    // 设置标题数组
    self.titles = @[@"推荐", @"关注", @"热门", @"附近"];
    
    // 创建封面视图
    self.coverView = [[UIView alloc] init];
    self.coverView.backgroundColor = UIColor.systemPinkColor;
    
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
    // 容器已从安全区顶部开始，吸顶位置只需避开自定义导航内容。
    self.pageViewControllerBridge.stickyOffset = 44;
    
    // 添加到父视图控制器
    [self.pageViewControllerBridge addToParentViewController:self];
    UIView *pageView = self.pageViewControllerBridge.nestedPageViewController.view;
    pageView.translatesAutoresizingMaskIntoConstraints = NO;
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [pageView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [pageView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [pageView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
        [pageView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor]
    ]];
    
    // 设置自定义导航栏
    [self setupCustomNavigationBar];
    [self setupBackButton];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize size = self.pageViewControllerBridge.nestedPageViewController.view.bounds.size;
    if (!CGSizeEqualToSize(size, self.lastPageSize)) {
        self.lastPageSize = size;
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
    
    // 计算导航栏透明度
    CGFloat coverHeight = [self heightForCoverViewIn:pageViewController];
    CGFloat tabHeight = [self heightForTabStripIn:pageViewController];
    CGFloat headerHeight = coverHeight + tabHeight;
    
    // 注意：scrollView.contentOffset.y初始值为-headerHeight
    CGFloat headerOffsetY = headerOffset;
        
    // 计算导航栏透明度
    CGFloat scrollDistance = MAX(1, headerHeight - self.pageViewControllerBridge.stickyOffset - tabHeight);
    self.customNavigationBar.alpha = MIN(MAX(headerOffsetY / scrollDistance, 0.0), 1.0);
}

@end

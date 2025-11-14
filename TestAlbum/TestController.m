//
//  TestController.m
//  TestAlbum
//
//  Created by mm on 2025/11/14.
//

#import "TestController.h"

@interface TestController () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@property (nonatomic, assign) CGPoint startPoint;
@property (nonatomic, strong) UIView *backgroundMaskView;
@property (nonatomic, strong) UIView *contentContainerView;

@end

@implementation TestController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor clearColor];

    // 创建背景蒙层
    self.backgroundMaskView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.backgroundMaskView.backgroundColor = [UIColor blackColor];
    self.backgroundMaskView.alpha = 0;
    [self.view addSubview:self.backgroundMaskView];

    // 创建内容容器视图
    self.contentContainerView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.contentContainerView.backgroundColor = [UIColor whiteColor];
    self.contentContainerView.layer.cornerRadius = 0;
    self.contentContainerView.layer.masksToBounds = YES;
    [self.view addSubview:self.contentContainerView];

    // 添加导航栏（因为不再使用系统导航栏）
    UIView *navBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 88)];
    navBar.backgroundColor = [UIColor whiteColor];
    [self.contentContainerView addSubview:navBar];

    // 添加标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 44, self.view.bounds.size.width, 44)];
    titleLabel.text = @"TestController";
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [navBar addSubview:titleLabel];

    // 添加返回按钮
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    backButton.frame = CGRectMake(0, 44, 80, 44);
    [backButton setTitle:@"< 返回" forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(onBackButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [navBar addSubview:backButton];

    // 添加提示标签到内容容器
    UILabel *hintLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 160, self.contentContainerView.bounds.size.width - 40, 60)];
    hintLabel.text = @"向下滑动可以关闭页面\n支持整体缩小移动效果";
    hintLabel.textAlignment = NSTextAlignmentCenter;
    hintLabel.font = [UIFont systemFontOfSize:16];
    hintLabel.textColor = [UIColor grayColor];
    hintLabel.numberOfLines = 2;
    [self.contentContainerView addSubview:hintLabel];

    // 设置下拉手势
    [self setupPanGesture];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // 初始状态：内容视图在底部且缩小
    CGAffineTransform scaleTransform = CGAffineTransformMakeScale(0.95, 0.95);
    CGAffineTransform translateTransform = CGAffineTransformMakeTranslation(0, self.view.bounds.size.height);
    self.contentContainerView.transform = CGAffineTransformConcat(scaleTransform, translateTransform);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // 动画进入
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.contentContainerView.transform = CGAffineTransformIdentity;
        self.backgroundMaskView.alpha = 0.5;
    } completion:nil];
}

- (void)onBackButtonTapped {
    [self dismissWithAnimation];
}

- (void)dismissWithAnimation {
    [UIView animateWithDuration:0.25 animations:^{
        CGAffineTransform scaleTransform = CGAffineTransformMakeScale(0.95, 0.95);
        CGAffineTransform translateTransform = CGAffineTransformMakeTranslation(0, self.view.bounds.size.height);
        self.contentContainerView.transform = CGAffineTransformConcat(scaleTransform, translateTransform);
        self.backgroundMaskView.alpha = 0;
        self.contentContainerView.layer.cornerRadius = 15;
    } completion:^(BOOL finished) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }];
}

- (void)setupPanGesture {
    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    self.panGesture.delegate = self;
    [self.view addGestureRecognizer:self.panGesture];
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.view];
    CGPoint velocity = [gesture velocityInView:self.view];

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            self.startPoint = self.contentContainerView.center;
            break;

        case UIGestureRecognizerStateChanged: {
            // 只允许向下拖动
            if (translation.y > 0) {
                // 计算缩放比例，最小缩放到 0.85
                CGFloat maxTranslation = self.view.bounds.size.height;
                CGFloat progress = MIN(translation.y / maxTranslation, 1.0);
                CGFloat scale = 1.0 - (progress * 0.15); // 从 1.0 缩小到 0.85

                // 应用缩放和位移变换
                CGAffineTransform scaleTransform = CGAffineTransformMakeScale(scale, scale);
                CGAffineTransform translateTransform = CGAffineTransformMakeTranslation(0, translation.y);
                self.contentContainerView.transform = CGAffineTransformConcat(scaleTransform, translateTransform);

                // 根据拖动距离调整背景透明度
                CGFloat alpha = 0.5 * (1.0 - progress);
                self.backgroundMaskView.alpha = alpha;

                // 根据拖动距离调整圆角，最大圆角 10
                CGFloat cornerRadius = progress * 10.0;
                self.contentContainerView.layer.cornerRadius = cornerRadius;
            }
            break;
        }

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            // 判断是否应该关闭页面
            // 条件1: 向下的速度足够快 (velocity.y > 1000)
            // 条件2: 或者拖动距离超过屏幕高度的1/3
            BOOL shouldDismiss = velocity.y > 1000 || translation.y > self.view.bounds.size.height / 3.0;

            if (shouldDismiss) {
                // 关闭页面动画
                [UIView animateWithDuration:0.25 animations:^{
                    // 继续向下移动并缩小
                    CGAffineTransform scaleTransform = CGAffineTransformMakeScale(0.7, 0.7);
                    CGAffineTransform translateTransform = CGAffineTransformMakeTranslation(0, self.view.bounds.size.height);
                    self.contentContainerView.transform = CGAffineTransformConcat(scaleTransform, translateTransform);
                    self.backgroundMaskView.alpha = 0;
                    self.contentContainerView.layer.cornerRadius = 15;
                } completion:^(BOOL finished) {
                    [self dismissViewControllerAnimated:NO completion:nil];
                }];
            } else {
                // 恢复原位动画
                [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
                    self.contentContainerView.transform = CGAffineTransformIdentity;
                    self.backgroundMaskView.alpha = 0.5;
                    self.contentContainerView.layer.cornerRadius = 0;
                } completion:nil];
            }
            break;
        }

        default:
            break;
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.panGesture) {
        UIPanGestureRecognizer *panGesture = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint velocity = [panGesture velocityInView:self.view];

        // 只在垂直方向滑动且向下滑动时触发
        return fabs(velocity.y) > fabs(velocity.x) && velocity.y > 0;
    }
    return YES;
}

@end

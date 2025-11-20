#import "VMHUDRootViewController.h"
#import "VMHUDWindow.h"
#import "VMHUDView.h"
#import "TweakSB.h"
#import "MTMaterialView.h"
#import "FrontBoard.h"
#import "_UIBackdropView.h"
#import "MRYIPC/MRYIPCCenter.h"
#import <objc/runtime.h>
#import <notify.h>
#import <UIKit/UIImage+Private.h>
#import <sys/types.h>
#import <signal.h>

@interface VMHUDRootViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UIGestureRecognizerDelegate>

@end

#define kSliderAndIconInterval 12.
#define kCollectionViewItemInset 10.
#define kHudWidth 47.
#define kHudHeight 148.
#define kIconSize 29.

@implementation VMHUDRootViewController {
    MRYIPCCenter *_center;
    CGFloat _panelPortraitY;
    CGFloat _panelLandScapeY;
    BOOL _isHideInactiveApps;
    BOOL _isHideBackground;
    UICollectionView *_collectionView;
    UIView *_mtBgView;
    NSMutableArray<VMHUDView *> *_hudViews;
    NSMutableArray<NSString *> *_bundleIDs;
    NSMutableArray<NSNumber *> *_pids;
    NSMutableArray<NSNumber *> *_runningAppIndexes;
}
- (instancetype)init {
    self = [super init];
    if(self){
        [self initServer];
        [self loadPref];

        _hudViews = [NSMutableArray new];
        _bundleIDs = [NSMutableArray new];
        _pids = [NSMutableArray new];
        _runningAppIndexes = [NSMutableArray new];
    }
    return self;
}
- (void)loadView {
    [super loadView];

    double maxWidth = MAX(self.view.frame.size.width, self.view.frame.size.height);
    double minWidth = MIN(self.view.frame.size.width, self.view.frame.size.height);
    _touchBlockView = [[UILabel alloc] initWithFrame:CGRectMake(-10, 0, maxWidth + 10, maxWidth)];
    [self.view addSubview:_touchBlockView];
    _touchBlockView.text = @"1";

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumLineSpacing = 1;
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 100, minWidth, kHudHeight + kIconSize + kSliderAndIconInterval + 2 * kCollectionViewItemInset) collectionViewLayout:layout];
    CGFloat newCenterY = self.view.frame.size.width < self.view.frame.size.height ? _panelPortraitY : _panelLandScapeY;
    [_collectionView setCenter:CGPointMake(self.view.frame.size.width / 2., newCenterY)];
    _collectionView.showsHorizontalScrollIndicator = NO;
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    _collectionView.backgroundColor = [UIColor clearColor];
    [_collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"hudCell"];
    [self.view addSubview:_collectionView];

    if(@available(iOS 13.0, *)) {
        _mtBgView = [objc_getClass("MTMaterialView") materialViewWithRecipe:4 configuration:1 initialWeighting:1];
    }
    else if(@available(iOS 11.0, *)) {
        _mtBgView = [objc_getClass("MTMaterialView") materialViewWithRecipe:4 options:128 initialWeighting:1];
    }
    else if(objc_getClass("MTMaterialView")) {
        _mtBgView = [objc_getClass("MTMaterialView") materialViewWithStyleOptions:4 materialSettings:nil captureOnly:NO];
    }
    else {
        _mtBgView = [(_UIBackdropView *)[objc_getClass("_UIBackdropView") alloc] initWithStyle:2060];
    }
    _mtBgView.layer.cornerRadius = 10.;
    _mtBgView.layer.masksToBounds = YES;
    _collectionView.backgroundView = _mtBgView;
    _collectionView.backgroundView.hidden = _isHideBackground;

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    longPress.delegate = self;
    [self.view addGestureRecognizer:longPress];
    longPress.minimumPressDuration = 0;

    [self registerExistingApps];
}
// credits to https://twitter.com/aydenpanhuyzen/status/1205981139086782469
- (BOOL)_canShowWhileLocked {
    return YES;
}
- (void)longPress:(UILongPressGestureRecognizer *)longPress {
    if(longPress.state == UIGestureRecognizerStateBegan) {
        // NSLog(@"hideWindow: %@",longPress.view);
        [(VMHUDWindow *)[self.view superview] hideWindow];
    }
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // NSLog(@"touch view: %@",touch.view);
    if(_isHideBackground){
        return touch.view==self.view || touch.view==_collectionView;
    }
    return touch.view == self.view;
}

- (void)removeDataAtIndex:(int)i {
    [_bundleIDs removeObjectAtIndex:i];
    [_hudViews[i] removeFromSuperview];
    [_hudViews removeObjectAtIndex:i];
    [_pids removeObjectAtIndex:i];
}
- (void)reloadRunningApp {
    void (^blockForMain)(void) = ^{
        for(int i = [_bundleIDs count] - 1; i + 1; i--) {
            int pid = [_pids[i] intValue];
            int error = kill(pid, 0);
            if(error) [self removeDataAtIndex:i];
        }
        if(_isHideInactiveApps) {
            NSMutableArray *runningAppIndexes = [NSMutableArray new];
            int i = 0;
            for(NSNumber *pid in _pids) {
                if([[[[objc_getClass("FBProcessManager") sharedInstance] processForPID:[pid intValue]] state] taskState] == 2) {
                    [runningAppIndexes addObject:@(i)];
                }
                i++;
            }
            _runningAppIndexes = runningAppIndexes;
        }
        [_collectionView reloadData];
    };
    if(NSThread.isMainThread) blockForMain();
    else {
        dispatch_async(dispatch_get_main_queue(), blockForMain);
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if(_isHideInactiveApps) {
        return [_runningAppIndexes count];
    }
    return [_hudViews count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"hudCell" forIndexPath:indexPath];

    int index = _isHideInactiveApps ? [_runningAppIndexes[indexPath.row] intValue] : indexPath.row;

    UIView *contentView = cell.contentView;
    for(UIView *view in [contentView subviews]) {
        // NSLog(@"view: %@",view);
        [view removeFromSuperview];
    }
    VMHUDView *hudView = _hudViews[index];
    contentView.frame = CGRectMake(contentView.frame.origin.x, contentView.frame.origin.y, hudView.frame.size.width, kHudHeight + kIconSize + kSliderAndIconInterval);
    [contentView addSubview:hudView];

    UIImage *icon;
    if(![_bundleIDs[index] isEqualToString:kWebKitBundleId]) {
        icon = [UIImage _applicationIconImageForBundleIdentifier:_bundleIDs[index] format:0 scale:[UIScreen mainScreen].scale];
    }
    else {
        icon = [UIImage imageNamed:@"WebKitIcon" inBundle:[NSBundle bundleWithPath:kBundlePath] compatibleWithTraitCollection:nil];
    }
    UIImageView *imageView = [[UIImageView alloc] initWithImage:icon];
    [contentView addSubview:imageView];
    [imageView setFrame:CGRectMake(
                            (hudView.frame.size.width - kIconSize) / 2.,
                            contentView.bounds.origin.y,
                            imageView.frame.size.width,
                            imageView.frame.size.height)];
    [hudView setFrame:CGRectMake(
                          contentView.bounds.origin.x,
                          contentView.bounds.origin.y + kIconSize + kSliderAndIconInterval,
                          hudView.frame.size.width,
                          hudView.frame.size.height)];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(100, kHudHeight + kIconSize + kSliderAndIconInterval);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 5;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 5;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(0, kCollectionViewItemInset, 0, kCollectionViewItemInset);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"didSelectItemAtIndexPath: %ld", (long)indexPath.row);
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath{
    return NO;
}

- (void)initServer {
    _center = [MRYIPCCenter centerNamed:@"com.brend0n.volumemixer/register"];
    [_center addTarget:self action:@selector(register:)];
}
//receive bundleID
- (void)register:(NSDictionary *)args {
    NSLog(@"registering...");
    NSString *bundleID = args[@"bundleID"];
    NSNumber *pid = args[@"pid"];
    NSString *appNotify = [NSString stringWithFormat:@"com.brend0n.volumemixer/%@~%d/setVolume", bundleID, pid.intValue];
    NSLog(@"appNotify: %@", appNotify);

    dispatch_async(dispatch_get_main_queue(), ^{
        [_bundleIDs addObject:bundleID];
        [_pids addObject:pid];

        VMHUDView *hudView = [[VMHUDView alloc] initWithFrame:CGRectMake(0, 0, kHudWidth, kHudHeight)];
        hudView.bundleID = bundleID;
        MRYIPCCenter *client = [MRYIPCCenter centerNamed:appNotify];
        hudView.valueDidChange = ^(CGFloat curScale){
            [client callExternalVoidMethod:@selector(setVolume:) withArguments:@{ @"curScale": @(curScale) }];
        };
        [hudView initScale];
        [_hudViews addObject:hudView];

        [self reloadRunningApp];
    });
}
- (void)registerExistingApps{
    for(NSString *bundleID in [g_defaults objectForKey:kPrefAppsKey]){
        FBApplicationProcess *process = [[objc_getClass("FBProcessManager") sharedInstance] applicationProcessesForBundleIdentifier:bundleID].firstObject;
        if(process.pid){
            [self register:@{@"bundleID":bundleID, @"pid":@(process.pid)}];
        }
    }
}
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    // CGFloat oldWidth = size.height;
    // CGFloat oldHeight = size.width;
    CGFloat newWidth = size.width;
    CGFloat newHeight = size.height;

    CGFloat newCenterY = newWidth < newHeight ? _panelPortraitY : _panelLandScapeY;
    [coordinator animateAlongsideTransition:^(id arg1){
        [_collectionView setCenter:CGPointMake(newWidth / 2.0, newCenterY)];
    } completion:nil];
}
- (void)loadPref {
    _panelPortraitY = [g_defaults objectForKey:kPrefPanelPortraitYKey] ? [g_defaults doubleForKey:kPrefPanelPortraitYKey] : 200.0;
    _panelLandScapeY = [g_defaults objectForKey:kPrefPanelLandScapeYKey] ? [g_defaults doubleForKey:kPrefPanelLandScapeYKey] : MIN(UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height) / 2.0;
    _isHideInactiveApps = [g_defaults objectForKey:kPrefIsHideInactiveAppsKey] ? [g_defaults boolForKey:kPrefIsHideInactiveAppsKey] : NO;
    _isHideBackground = [g_defaults objectForKey:kPrefIsHideBackgroundKey] ? [g_defaults boolForKey:kPrefIsHideBackgroundKey] : NO;
    VMHUDWindow.sharedWindow.showsOnLockScreen = [g_defaults objectForKey:kPrefShowsOnLockScreenKey] ? [g_defaults boolForKey:kPrefShowsOnLockScreenKey] : YES;

    CGFloat newCenterY = self.view.frame.size.width < self.view.frame.size.height ? _panelPortraitY : _panelLandScapeY;
    [UIView animateWithDuration:0.25 animations:^{
        [_collectionView setCenter:CGPointMake(_collectionView.center.x, newCenterY)];
    }];
    _collectionView.backgroundView.hidden = _isHideBackground;
}
- (void)decreaseVolume {
    int i = 0;
    for(NSNumber *pid in _pids) {
        if([[[[objc_getClass("FBProcessManager") sharedInstance] processForPID:pid.intValue] state] taskState] == 2) {
            [_hudViews[i] changeScale:-1. / 16.];
        }
        i++;
    }
}
- (void)increaseVolume {
    int i = 0;
    for(NSNumber *pid in _pids) {
        if([[[[objc_getClass("FBProcessManager") sharedInstance] processForPID:pid.intValue] state] taskState] == 2) {
            [_hudViews[i] changeScale:1. / 16.];
        }
        i++;
    }
}
@end

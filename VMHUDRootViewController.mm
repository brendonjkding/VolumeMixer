#import "VMHUDRootViewController.h"
#import "VMHUDWindow.h"
#import "VMHUDView.h"
#import "MTMaterialView.h"
#import "VMIPCCenter.h"
#import <objc/runtime.h>
#import <notify.h>
#import <AppList/AppList.h>
#import <MRYIPCCenter/MRYIPCCenter.h>
#import <sys/types.h>
#import <signal.h>
@interface FBProcessState
-(int)taskState;
-(BOOL)isRunning;
@end
@interface SBApplication : NSObject
- (BOOL)isRunning;
- (FBProcessState *)processState;
@end
@interface SBApplicationController : NSObject
+ (id)sharedInstance;
- (SBApplication*)applicationWithBundleIdentifier:(NSString*)bundleIdentifier;
@end


@interface VMHUDRootViewController()<UICollectionViewDelegate,UICollectionViewDataSource,UIGestureRecognizerDelegate>
@property (strong, nonatomic) UICollectionView *collectionView;
@property (strong, nonatomic) NSMutableArray<VMHUDView*> *hudViews;
@property (strong, nonatomic) NSMutableArray<NSString*> *bundleIDs;
@property (strong, nonatomic) NSMutableArray<NSNumber*> *pids;
@property (strong, nonatomic) NSMutableArray<MRYIPCCenter*> *centers ;
@end
#define kSliderAndIconInterval 12.
#define kCollectionViewItemInset 10.
#define kHudWidth 47.
#define kHudHeight 148.
@implementation VMHUDRootViewController
-(instancetype)init{
	self= [super init];
	if(!self)return self;
	[self registerNotify];
	_hudViews=[NSMutableArray new];
	_bundleIDs=[NSMutableArray new];
	_pids=[NSMutableArray new];
	[self loadFrameWorks];
	return self;
}
-(void)loadView{
	[super loadView];

	UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumLineSpacing = 1;
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 100, self.view.frame.size.width, kHudHeight+ALApplicationIconSizeSmall+kSliderAndIconInterval+2*kCollectionViewItemInset) collectionViewLayout:layout];
    _collectionView.showsHorizontalScrollIndicator = NO;
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    _collectionView.backgroundColor = [UIColor clearColor];
    [_collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"UICollectionViewCell"];
    [self.view addSubview:_collectionView];
	

	MTMaterialView* mtBgView;
    if(@available(iOS 13.0, *)) {
        mtBgView=[objc_getClass("MTMaterialView") materialViewWithRecipe:4 configuration:1 initialWeighting:1];
    }
    else{
    	mtBgView=[objc_getClass("MTMaterialView") materialViewWithRecipe:4 options:128 initialWeighting:1];
    }
    mtBgView.layer.cornerRadius = 10.;
    mtBgView.layer.masksToBounds = YES;
	_collectionView.backgroundView =mtBgView;


    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    longPress.delegate=self;
    [self.view addGestureRecognizer:longPress];
    longPress.minimumPressDuration=0;


}
- (void)longPress:(UILongPressGestureRecognizer *)longPress{
	if (longPress.state == UIGestureRecognizerStateBegan){
    	[(VMHUDWindow*)[self.view superview] hideWindow];
    }

}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch{
	return touch.view==self.view;
 }
-(void)removeDataAtIndex:(int)i{
	[_bundleIDs removeObjectAtIndex:i];
	[_hudViews removeObjectAtIndex:i];
	[_centers removeObjectAtIndex:i];
	[_pids removeObjectAtIndex:i];
}
-(void)reloadRunningApp{
	dispatch_async(dispatch_get_main_queue(), ^{
	        for(int i=[_bundleIDs count]-1;i+1;i--){
        		int pid=[_pids[i] intValue];
				int error=kill(pid, 0);
				if(error) [self removeDataAtIndex:i];
	        }
	        [_collectionView reloadData];
		});
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return [_hudViews count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"UICollectionViewCell" forIndexPath:indexPath];
    for(UIView*view in [cell subviews]){
    	[view removeFromSuperview];
    }
    VMHUDView* hudView=_hudViews[indexPath.row];
    [cell setFrame:CGRectMake(cell.frame.origin.x,cell.frame.origin.y,hudView.frame.size.width,kHudHeight+ALApplicationIconSizeSmall+kSliderAndIconInterval)];
    [cell addSubview:hudView];
    UIImage *icon;
    if(![_bundleIDs[indexPath.row] isEqualToString:kWebKitBundleId])icon=[[ALApplicationList sharedApplicationList] iconOfSize:ALApplicationIconSizeSmall forDisplayIdentifier:_bundleIDs[indexPath.row]];
    else icon=[UIImage imageNamed:@"WebKitIcon" inBundle:[NSBundle bundleWithPath:@"/Library/PreferenceBundles/volumemixer.bundle"] compatibleWithTraitCollection:nil];
    UIImageView* imageView=[[UIImageView alloc] initWithImage:icon];
    [cell addSubview:imageView];
    [imageView setFrame:CGRectMake(
    	(hudView.frame.size.width-ALApplicationIconSizeSmall)/2.,
	     cell.bounds.origin.y,
	    imageView.frame.size.width,
	    imageView.frame.size.height)];
    [hudView setFrame:CGRectMake(
    	cell.bounds.origin.x,
	     cell.bounds.origin.y+ALApplicationIconSizeSmall+kSliderAndIconInterval,
	    hudView.frame.size.width,
	    hudView.frame.size.height)];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(100,kHudHeight+ALApplicationIconSizeSmall+kSliderAndIconInterval);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 5;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 5;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section{
    return UIEdgeInsetsMake(0, kCollectionViewItemInset, 0, kCollectionViewItemInset);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"didSelectItemAtIndexPath: %ld",indexPath.row);
}

-(void) registerNotify{
	//receive bundleID
	VMIPCCenter*IDCenter=[[VMIPCCenter alloc] initWithName:@"com.brend0n.volumemixer/register"];
	[IDCenter setRegisterBlock:^(NSDictionary*args){
		NSLog(@"registering...");
    	NSString* bundleID=args[@"bundleID"];
    	NSNumber*pid=args[@"pid"];
    	NSString*appNotify=[NSString stringWithFormat:@"com.brend0n.volumemixer/%@~%d/setVolume",bundleID,[pid intValue]];
    	NSLog(@"appNotify:%@",appNotify);
 		
 		// if([_bundleIDs containsObject:bundleID]&&![bundleID isEqualToString:kWebKitBundleId]) return;
    	dispatch_async(dispatch_get_main_queue(), ^{
    		[self reloadRunningApp];
	        [_bundleIDs addObject:bundleID];
	        [_pids addObject:pid];

	        MRYIPCCenter* center = [MRYIPCCenter centerNamed:appNotify];
	        [_centers addObject:center];
	    	
	    	__block VMHUDView* hudView=[[VMHUDView alloc] initWithFrame:CGRectMake(0,0,kHudWidth,kHudHeight)];
	    	__weak VMHUDView*weakHUDView=hudView;
	    	[hudView setBundleID:bundleID];
	    	[hudView setVolumeChangedCallBlock:^{
	    		//send volume
	    		NSNumber *scaleNumber=[NSNumber numberWithDouble:[weakHUDView curScale]];
	    		[center callExternalMethod:@selector(setVolume:)withArguments:@{@"curScale" : scaleNumber} completion:^(id ret){}];
	    	}];
	    	[hudView initScale];
	    	[_hudViews addObject:hudView];
		    
	        [_collectionView reloadData];
		});
	}];
	int token;
	notify_register_dispatch("com.brend0n.volumemixer/nowPlayingWebKitDidChange", &token, dispatch_get_main_queue(), ^(int token) {
			[self setNowPlayingWebKit];
		});
}
-(void)setNowPlayingWebKit{
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
	int pid=prefs?[prefs[@"nowPlayingWebKitpid"] intValue]:0;
	NSLog(@"%d",pid);
	if(pid){

	}
	
}
-(void)loadFrameWorks{
#if TARGET_OS_SIMULATOR
    NSArray* bundles = @[
        @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/MaterialKit.framework",
        @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/MaterialKit.framework"
    ];
#else
    NSArray* bundles = @[
        @"/System/Library/PrivateFrameworks/MaterialKit.framework",
    ];
#endif
	

	for (NSString* bundlePath in bundles)
	{
		NSBundle* bundle = [NSBundle bundleWithPath:bundlePath];
		if (!bundle.loaded)
			[bundle load];
	}
}
@end
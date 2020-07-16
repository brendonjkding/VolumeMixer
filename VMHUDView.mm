#import "VMHUDView.h"
#import "VMHUDWindow.h"
#import <objc/runtime.h>

@interface MTMaterialView
+(id)materialViewWithRecipe:(NSInteger)arg1 configuration:(NSInteger)arg2 initialWeighting:(CGFloat)arg3;
+(id)materialViewWithRecipe:(NSInteger)arg1 options:(NSInteger)arg2 initialWeighting:(CGFloat)arg3;
@end
@interface VMHUDView  (){
    CGPoint _originalPoint;//之前的位置
}
@end
@implementation VMHUDView
-(instancetype)initWithFrame:(CGRect)frame{
	self=[super initWithFrame:frame];
	if(!self)return self;

	self.clipsToBounds = YES;
	self.layer.cornerRadius = 14.;
    self.curScale=1.;

	// create blurred background for slider:
	UIBlurEffect* blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
	UIVisualEffectView* blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
	blurView.frame = self.bounds;
	blurView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
	[self addSubview:blurView];
	NSArray* bundles = @[
		@"/System/Library/PrivateFrameworks/MaterialKit.framework",
		@"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/MaterialKit.framework"
	];

	for (NSString* bundlePath in bundles)
	{
		NSBundle* bundle = [NSBundle bundleWithPath:bundlePath];
		if (!bundle.loaded)
			[bundle load];
	}
    id mtBgView,mtSliderView;
    if(@available(iOS 13.0, *)) {
        mtBgView=[objc_getClass("MTMaterialView") materialViewWithRecipe:4 configuration:2 initialWeighting:1];
        mtSliderView=[objc_getClass("MTMaterialView") materialViewWithRecipe:4 configuration:3 initialWeighting:1] ;
    }
    else{
        mtBgView=[objc_getClass("MTMaterialView") materialViewWithRecipe:4 options:3 initialWeighting:1];
        mtSliderView=[objc_getClass("MTMaterialView") materialViewWithRecipe:4 options:32 initialWeighting:1] ;
    }
	
	[mtBgView setFrame:self.bounds];
	[self addSubview:mtBgView];

	_clippingView=[[UIView alloc] initWithFrame:CGRectMake(0,0,self.bounds.size.width,self.bounds.size.height)];
	_clippingView.clipsToBounds = YES;
	[self addSubview:_clippingView];

	
	[mtSliderView setFrame:self.bounds];
	[_clippingView addSubview:mtSliderView];

	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    [self addGestureRecognizer:pan];

	return self;

}
- (void)pan:(UIPanGestureRecognizer *)pan{
    //获取当前位置
    CGPoint currentPosition = [pan locationInView:self];
    if (pan.state == UIGestureRecognizerStateBegan) {
        _originalPoint = currentPosition;
        [(VMHUDWindow*)[self superview] cancelAutoHide];
    }else if(pan.state == UIGestureRecognizerStateChanged){
        //偏移量(当前坐标 - 起始坐标 = 偏移量)
        // CGFloat offsetX = currentPosition.x - _originalPoint.x;
        CGFloat offsetY = currentPosition.y - _originalPoint.y;
        _originalPoint = currentPosition;

        CGFloat newY=MIN(MAX(_clippingView.frame.origin.y+offsetY,0),_clippingView.frame.size.height);
        CGFloat scale=1.-newY/_clippingView.frame.size.height;
        // NSLog(@"Scale:%lf",scale);
        if(fabs(scale-_curScale)>1/16){
        	_curScale=scale;
            // NSLog(@"newScale:%lf",_curScale);

        }

        [_clippingView setFrame:CGRectMake(_clippingView.frame.origin.x,
        									newY,
        									_clippingView.frame.size.width,
        									_clippingView.frame.size.height)];

        // //移动后的按钮中心坐标
        // CGFloat centerX = self.center.x + offsetX;
        // CGFloat centerY = self.center.y + offsetY;
        // self.center = CGPointMake(centerX, centerY);
        
        // //父试图的宽高
        // CGFloat superViewWidth = self.superview.frame.size.width;
        // CGFloat superViewHeight = self.superview.frame.size.height;
        // CGFloat btnX = self.frame.origin.x;
        // CGFloat btnY = self.frame.origin.y;
        // CGFloat btnW = self.frame.size.width;
        // CGFloat btnH = self.frame.size.height;
        
        // //x轴左右极限坐标
        // if (btnX > superViewWidth){
        //     //按钮右侧越界
        //     CGFloat centerX = superViewWidth - btnW/2;
        //     self.center = CGPointMake(centerX, centerY);
        // }else if (btnX < 0){
        //     //按钮左侧越界
        //     CGFloat centerX = btnW * 0.5;
        //     self.center = CGPointMake(centerX, centerY);
        // }
        
        // //默认都是有导航条的，有导航条的，父试图高度就要被导航条占据，固高度不够
        // CGFloat defaultNaviHeight = 64;
        // CGFloat judgeSuperViewHeight = superViewHeight - defaultNaviHeight;
        
        // //y轴上下极限坐标
        // if (btnY <= 0){
        //     //按钮顶部越界
        //     centerY = btnH * 0.7;
        //     self.center = CGPointMake(centerX, centerY);
        // }
        // else if (btnY > judgeSuperViewHeight){
        //     //按钮底部越界
        //     CGFloat y = superViewHeight - btnH * 0.5;
        //     self.center = CGPointMake(btnX, y);
        // }
    }else if (pan.state == UIGestureRecognizerStateEnded){
        [(VMHUDWindow*)[self superview] autoHide];
        // CGFloat btnWidth = self.frame.size.width;
        // CGFloat btnHeight = self.frame.size.height;
        // CGFloat btnY = self.frame.origin.y;
        // //        CGFloat btnX = self.frame.origin.x;
        // //按钮靠近右侧
        // switch (_type) {
                
        //     case WQSuspendViewTypeNone:{
        //         //自动识别贴边
        //         if (self.center.x >= self.superview.frame.size.width/2) {
                    
        //             [UIView animateWithDuration:0.5 animations:^{
        //                 //按钮靠右自动吸边
        //                 CGFloat btnX = self.superview.frame.size.width - btnWidth;
        //                 self.frame = CGRectMake(btnX, btnY, btnWidth, btnHeight);
        //             }];
        //         }else{
                    
        //             [UIView animateWithDuration:0.5 animations:^{
        //                 //按钮靠左吸边
        //                 CGFloat btnX = 0;
        //                 self.frame = CGRectMake(btnX, btnY, btnWidth, btnHeight);
        //             }];
        //         }
        //         break;
        //     }
        //     case WQSuspendViewTypeLeft:{
        //         [UIView animateWithDuration:0.5 animations:^{
        //             //按钮靠左吸边
        //             CGFloat btnX = 0;
        //             self.frame = CGRectMake(btnX, btnY, btnWidth, btnHeight);
        //         }];
        //         break;
        //     }
        //     case WQSuspendViewTypeRight:{
        //         [UIView animateWithDuration:0.5 animations:^{
        //             //按钮靠右自动吸边
        //             CGFloat btnX = self.superview.frame.size.width - btnWidth;
        //             self.frame = CGRectMake(btnX, btnY, btnWidth, btnHeight);
        //         }];
        //     }
        // }
        // NSMutableDictionary *prefs=[NSMutableDictionary new];
        // NSString*keyX=[NSString stringWithFormat:@"%@~X",[[NSBundle mainBundle] bundleIdentifier]];
        // NSString*keyY=[NSString stringWithFormat:@"%@~Y",[[NSBundle mainBundle] bundleIdentifier]];
        // prefs[keyX]=[NSNumber numberWithFloat:self.frame.origin.x];
        // prefs[keyY]=[NSNumber numberWithFloat:self.frame.origin.y];
        // [_messagingCenterClient sendMessageName:@"savePref" userInfo:prefs];
    }
}
@end
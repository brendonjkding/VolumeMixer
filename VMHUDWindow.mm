#import "VMHUDWindow.h"
@implementation VMHUDWindow

- (id)initWithFrame:(CGRect)frame{
	self=[super initWithFrame:frame];
	if(!self)return self;
	[self configureUI];

	// [[NSNotificationCenter defaultCenter]
 //     addObserver:self
 //     selector:@selector(volumeChanged:)
 //     name:@"AVSystemController_SystemVolumeDidChangeNotification"
 //     object:nil];


	[self hideWindow];

	return self;
}
// -(id)initWithWindowScene:(UIWindowScene *)windowScene{
// 	self=[super initWithWindowScene:windowScene];
// 	[self configureUI];
// 	return self;
// }


-(void) configureUI{
	NSLog(@"configureUI");
	self.windowLevel = UIWindowLevelStatusBar;
	[self setHidden:NO];
	[self setAlpha:1.0];
	[self setBackgroundColor:[UIColor clearColor]];
	[self makeKeyAndVisible];
	[self hideWindow];
}
-(void) hideWindow{
	[self setHidden:YES];
}
-(void) showWindow{
	[self setHidden:NO];
}
-(void) cancelAutoHide{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideWindow) object:nil];
}
-(void) autoHide{
	[self performSelector:@selector(hideWindow) withObject:nil afterDelay:2];
} 

- (void)volumeChanged:(NSNotification *)notification{
	// NSLog(@"???");
	[self cancelAutoHide];
	[self showWindow];
	[self autoHide];
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitTestView = [super hitTest:point withEvent:event];
    // NSLog(@"%@",[hitTestView class]);
    if(hitTestView ==self||hitTestView==[self rootViewController].view){
    	return nil;
    }
    return hitTestView;
    // if (hitTestView == button||[hitTestView superview]==button) 
    // {
    //     return hitTestView;
    // }
    // else
    // {
    //     return nil;
    // }
}
@end
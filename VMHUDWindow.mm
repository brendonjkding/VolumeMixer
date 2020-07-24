#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"
#import <notify.h>
@implementation VMHUDWindow

- (id)initWithFrame:(CGRect)frame{
	self=[super initWithFrame:frame];
	if(!self) return self;
	
	[self configureUI];

	return self;
}
-(void)changeVisibility{
	if([self alpha])[self hideWindow];
	else [self showWindow];
}
-(void) configureUI{
	self.windowLevel = UIWindowLevelStatusBar;
	[self makeKeyAndVisible];
	[self setAlpha:0.0];
	[self setBackgroundColor:[UIColor clearColor]];
}
-(void) hideWindow{
	[UIView animateWithDuration:0.5 animations:^{
		[self setAlpha:0.];
    }];
    notify_post("com.brend0n.volumemixer/windowDidShow");
}
-(void) showWindow{
	[self.rootViewController performSelector:@selector(reloadRunningApp)];
	[UIView animateWithDuration:0.5 animations:^{
		[self setAlpha:1.];
    }];
    notify_post("com.brend0n.volumemixer/windowDidShow");
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
    if((hitTestView ==self||hitTestView==[self rootViewController].view)&&![self alpha]){
    	return nil;
    }
    return hitTestView;
}
@end
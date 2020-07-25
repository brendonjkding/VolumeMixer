#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"
#import <notify.h>
@interface VMHUDWindow()
@property (strong) dispatch_source_t timer;
@end
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
	self.clipsToBounds= YES;
	[self makeKeyAndVisible];
	[self setAlpha:0.0];
	[self setBackgroundColor:[UIColor clearColor]];
}
-(void) hideWindow{
	[UIView animateWithDuration:0.5 animations:^{
		[self setAlpha:0.];
    }];
    if(_timer)  {
    	dispatch_source_cancel(_timer);
    	_timer=nil;
    }
    notify_post("com.brend0n.volumemixer/windowDidHide");
}
-(void) showWindow{
	[self.rootViewController performSelector:@selector(reloadRunningApp)];
	[UIView animateWithDuration:0.5 animations:^{
		[self setAlpha:1.];
    }];
    if(_timer) return;
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), (1.0) * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(_timer, ^{
    	notify_post("com.brend0n.volumemixer/windowDidShow");
    });
    dispatch_resume(_timer);
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
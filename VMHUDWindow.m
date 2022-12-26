#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"
#import <notify.h>

static VMHUDWindow *sharedWindow;

@implementation VMHUDWindow
+ (id)sharedWindow{
    if(!sharedWindow){
        sharedWindow = [[VMHUDWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }
    return sharedWindow;
}
- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(!self) return self;

    [self configureUI];

    return self;
}
- (void)changeVisibility {
    if([self alpha]) [self hideWindow];
    else {
        [self showWindow];
    }
}
- (void)configureUI {
    self.windowLevel = 1200;
    self.clipsToBounds = YES;
    [self makeKeyAndVisible];
    [self setAlpha:0.0];
    [self setBackgroundColor:[UIColor clearColor]];
}
// credits to https://twitter.com/EnjoyingElectra/status/1205992433894469633
- (BOOL)_shouldCreateContextAsSecure {
    return YES;
}
- (void)hideWindow {
    [UIView animateWithDuration:0.5 animations:^{
        [self setAlpha:0.];
    }];
}
- (void)showWindow {
    [self.rootViewController performSelector:@selector(reloadRunningApp)];
    [UIView animateWithDuration:0.5
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         [self setAlpha:1.];
                     }
                     completion:NULL];
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitTestView = [super hitTest:point withEvent:event];
    // NSLog(@"hittest: %@",hitTestView);
    if((hitTestView == self || hitTestView == [self rootViewController].view) && ![self alpha]) {
        return nil;
    }
    return hitTestView;
}
@end
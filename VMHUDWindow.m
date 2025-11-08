#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"
#import <notify.h>
#import <SpringBoard/SBLockScreenManager.h>
#import <objc/runtime.h>

@interface SpringBoard
- (id)embeddedDisplayWindowScene;
@end

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

    if(self){
        [self configureUI];

        if(@available(iOS 16.0, *)){
            if(!self.windowScene){
                self.windowScene = [(SpringBoard *)[UIApplication sharedApplication] embeddedDisplayWindowScene];
            }
        }
    }

    return self;
}
- (void)changeVisibility {
    if(self.alpha){
        [self hideWindow];
    }
    else {
        [self showWindow];
    }
}
- (void)configureUI {
    self.windowLevel = 1200;
    self.clipsToBounds = YES;
    [self makeKeyAndVisible];
    self.alpha = 0.0;
    self.backgroundColor = UIColor.clearColor;
}
// credits to https://twitter.com/EnjoyingElectra/status/1205992433894469633
- (BOOL)_shouldCreateContextAsSecure {
    return YES;
}
- (void)hideWindow {
    ((VMHUDRootViewController *)self.rootViewController).touchBlockView.hidden = YES;
    [UIView animateWithDuration:0.5 animations:^{
        [self setAlpha:0.];
    } completion:^(BOOL finished){
        ((VMHUDRootViewController *)self.rootViewController).touchBlockView.hidden = NO;
    }];
}
- (void)showWindow {
    if(!_showsOnLockScreen && [[objc_getClass("SBLockScreenManager") sharedInstance] isUILocked]) return;
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

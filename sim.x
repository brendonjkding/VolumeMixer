#import <theos/IOSMacros.h>

#import "VMHUDWindow.h"

extern VMHUDWindow *hudWindow;

%hook UIStatusBarWindow

- (instancetype)initWithFrame:(CGRect)frame {
    id ret = %orig;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(vm_tap:)];
    [ret addGestureRecognizer:tap];

    return ret;
}
%new
- (void)vm_tap:(UITapGestureRecognizer *)sender {
	if (sender.state == UIGestureRecognizerStateEnded){
		[hudWindow changeVisibility];
	}
}
%end

@interface SBMainDisplaySceneLayoutStatusBarView:UIView
@end
%hook SBMainDisplaySceneLayoutStatusBarView
- (void)_addStatusBarIfNeeded {
	%orig;

	UIView *statusBar = [self valueForKey:@"_statusBar"];

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(vm_tap:)];
	tap.numberOfTapsRequired=2;
    [statusBar addGestureRecognizer:tap];
}
%new
- (void)vm_tap:(UITapGestureRecognizer *)sender {
	if (sender.state == UIGestureRecognizerStateEnded){
		[hudWindow changeVisibility];
	}

}
%end

%ctor{
	if(IN_SPRINGBOARD){
		%init;
	}
}

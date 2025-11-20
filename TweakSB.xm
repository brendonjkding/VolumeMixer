#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"
#import <notify.h>
#import <theos/IOSMacros.h>
#import "TweakSB.h"

@interface AXPassthroughWindow : UIWindow
+ (id)sharedInstance;
@end

NSUserDefaults *g_defaults = nil;

VMHUDWindow *hudWindow = nil;
VMHUDRootViewController *rootViewController = nil;
static BOOL byVolumeButton = NO;

static void loadPref(){
    byVolumeButton = [g_defaults objectForKey:kPrefByVolumeButtonKey] ? [g_defaults boolForKey:kPrefByVolumeButtonKey] : NO;

    [rootViewController loadPref];
}

static void showHUDWindowSB(){
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        hudWindow = VMHUDWindow.sharedWindow;
        rootViewController = [VMHUDRootViewController new];
        hudWindow.rootViewController = rootViewController;
    });
}

%group SB
%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application{
    %orig;
    NSLog(@"applicationDidFinishLaunching");
    showHUDWindowSB();    
    dispatch_async(dispatch_get_main_queue(), ^{
        AXPassthroughWindow *axPassthroughWindow = [objc_getClass("AXPassthroughWindow") sharedInstance];
        if(axPassthroughWindow){
            hudWindow.windowLevel = axPassthroughWindow.windowLevel + 1;
        }
    });
}
%end //SpringBoard

%hook VolumeControlClass
- (void)increaseVolume{
    %orig;
    if(byVolumeButton){
        [hudWindow showWindow];
    }
}
- (void)decreaseVolume{
    %orig;
    if(byVolumeButton){
        [hudWindow showWindow];
    }
}
%end //VolumeControlClass
%end //SB

%ctor{
    if(!IN_SPRINGBOARD){
        return;
    }
    // Credit: Polyfills — com.apple.UIKit usage
    g_defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.apple.UIKit"];

    %init(SB, VolumeControlClass = objc_getClass("SBVolumeControl") ?: objc_getClass("VolumeControl"));

    loadPref();
    int token;
    notify_register_dispatch("com.brend0n.volumemixer/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
        loadPref();
    });
}

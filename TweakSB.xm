#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"
#import <notify.h>
#import "TweakSB.h"

HBPreferences *prefs = nil;

VMHUDWindow *hudWindow = nil;
VMHUDRootViewController *rootViewController = nil;
static BOOL byVolumeButton = NO;

static void loadPref(){
    byVolumeButton = prefs[@"byVolumeButton"] ? [prefs[@"byVolumeButton"] boolValue] : NO;

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
    prefs = [[HBPreferences alloc] initWithIdentifier:@"com.brend0n.volumemixer"];

    %init(SB, VolumeControlClass = objc_getClass("SBVolumeControl") ?: objc_getClass("VolumeControl"));

    loadPref();
    int token;
    notify_register_dispatch("com.brend0n.volumemixer/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
        loadPref();
    });
}

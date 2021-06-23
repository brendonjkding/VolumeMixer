#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"
#import <notify.h>
#import "TweakSB.h"

HBPreferences *prefs;

VMHUDWindow *hudWindow;
VMHUDRootViewController *rootViewController;
static BOOL byVolumeButton;

static void loadPref(){
    byVolumeButton = prefs[@"byVolumeButton"]?[prefs[@"byVolumeButton"] boolValue]:NO;

    [rootViewController loadPref];
}

static void showHUDWindowSB(){
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void(^blockForMain)(void) = ^{
                CGRect bounds=[UIScreen mainScreen].bounds;
                hudWindow =[[VMHUDWindow alloc] initWithFrame:bounds];
                rootViewController=[VMHUDRootViewController new];
                [hudWindow setRootViewController:rootViewController];
        };
        if ([NSThread isMainThread]) blockForMain();
        else {
            dispatch_async(dispatch_get_main_queue(), blockForMain);
        }
    });
}
%group SBHook
%hook SpringBoard
-(void) applicationDidFinishLaunching:(id)application{
    %orig;
    NSLog(@"applicationDidFinishLaunching");
    showHUDWindowSB();    
}
%end

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
%end
%end //SBHook

%ctor{
    prefs = [[HBPreferences alloc] initWithIdentifier:@"com.brend0n.volumemixer"];

    %init(SBHook, VolumeControlClass = objc_getClass("SBVolumeControl")?:objc_getClass("VolumeControl"));

    loadPref();
    int token;
    notify_register_dispatch("com.brend0n.volumemixer/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
        loadPref();
    });
}
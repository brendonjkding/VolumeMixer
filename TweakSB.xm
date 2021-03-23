#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"
#import <notify.h>

VMHUDWindow*hudWindow;
static VMHUDRootViewController*rootViewController;
static BOOL byVolumeButton;

static void loadPref(){
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    byVolumeButton=prefs[@"byVolumeButton"]?[prefs[@"byVolumeButton"] boolValue]:NO;

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
        else dispatch_async(dispatch_get_main_queue(), blockForMain);
        
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
- (void)increaseVolume {
    %orig;
    if(byVolumeButton) [hudWindow showWindow];
}

- (void)decreaseVolume {
    %orig;
    if(byVolumeButton) [hudWindow showWindow];
}
%end
%end //SBHook

%ctor{
    %init(SBHook,VolumeControlClass=objc_getClass("SBVolumeControl")?:objc_getClass("VolumeControl"));

    loadPref();
    int token;
    notify_register_dispatch("com.brend0n.volumemixer/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
        loadPref();
    });
}
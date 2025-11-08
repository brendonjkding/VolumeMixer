#import "TweakSB.h"
#import <libactivator/libactivator.h>
#import <objc/runtime.h>
#import <dlfcn.h>

@interface VolumeMixerLAListener: NSObject <LAListener>

@end

@implementation VolumeMixerLAListener

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
    [hudWindow changeVisibility];
}

+ (void)load {
    @autoreleasepool {
        // Register listener
        dlopen("/usr/lib/libactivator.dylib", RTLD_LAZY);
        Class la = objc_getClass("LAActivator");
        if(la) [[la sharedInstance] registerListener:[self new] forName:@"com.brend0n.volumemixer"];
    }
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName {
    return @"VolumeMixer";
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName {
    return @"Show Volume Mixer";
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
    return @"Volume control for individual app";
}

- (UIImage *)activator:(LAActivator *)activator requiresSmallIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale {
    static UIImage *icon;
    if(!icon) {
        icon = [UIImage imageNamed:@"icon" inBundle:[NSBundle bundleWithPath:kBundlePath] compatibleWithTraitCollection:nil];
    }
    return icon;
}

- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName {
    return @[@"springboard", @"application", @"lockscreen"];
}

@end

#if !(TARGET_OS_SIMULATOR)
#import "VMLAListener.h"
#import "VMHUDWindow.h"
extern VMHUDWindow*hudWindow;
@implementation VolumeMixerLAListener

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	[hudWindow changeVisibility];
}


+ (void)load
{
	@autoreleasepool 
	{
		// Register listener
		if([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) 
			[[LAActivator sharedInstance] registerListener:[self new] forName:@"com.brend0n.volumemixer"];
	}
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName
{
	return @"VolumeMixer";
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName
{
    return @"Show Volume Mixer";
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName
{
    return @"Volume control for individual app";
}

- (UIImage *)activator:(LAActivator *)activator requiresSmallIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
{
	__block NSBundle *preferenceBundle = nil;
	static dispatch_once_t once;
    dispatch_once(&once, ^{
		preferenceBundle = [NSBundle bundleWithPath:@"/Library/PreferenceBundles/volumemixer.bundle/"];
	});

	UIImage *icon = [UIImage imageNamed:@"icon" inBundle:preferenceBundle compatibleWithTraitCollection:nil];

	return icon;
}

- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName
{
    //It does not work well on lock screen on iOS10.
    return @[@"springboard", @"application"];
   
    
}

@end

#endif

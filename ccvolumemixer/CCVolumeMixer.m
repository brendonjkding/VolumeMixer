#import <objc/runtime.h>
#import <SpringBoard/SBControlCenterController.h>
#import "CCVolumeMixer.h"
#import "../VMHUDWindow.h"

@implementation CCVolumeMixer

//Return the icon of your module here
- (UIImage *)iconGlyph{
    return [UIImage imageNamed:@"icon" inBundle:[NSBundle bundleWithPath:kBundlePath] compatibleWithTraitCollection:nil];
}

//Return the color selection color of your module here
- (UIColor *)selectedColor{
    return [UIColor blueColor];
}

- (BOOL)isSelected{
    return _selected;
}

- (void)setSelected:(BOOL)selected{
    [[objc_getClass("VMHUDWindow") sharedWindow] changeVisibility];
    [[objc_getClass("SBControlCenterController") sharedInstance] dismissAnimated:YES completion:nil];
}

@end

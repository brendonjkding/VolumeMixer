#import "VMHUDView.h"
#import "VMHUDWindow.h"
#import "TweakSB.h"
#import "MTMaterialView.h"
#import "_UIBackdropView.h"
#import "MRYIPC/MRYIPCCenter.h"
#import <objc/runtime.h>

@implementation VMHUDView {
    CGPoint _lastLocation;
    UIImpactFeedbackGenerator *_feedback;
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(!self) return self;

    self.clipsToBounds = YES;
    self.layer.cornerRadius = 14.;
    _curScale = 1.;

    // credits to https://github.com/Muirey03/13HUD/blob/master/MRYHUDView.xm#L69
    // create blurred background for slider:
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    [self addSubview:blurView];

    UIView *mtBgView, *mtSliderView;
    if(@available(iOS 13.0, *)) {
        mtBgView = [objc_getClass("MTMaterialView") materialViewWithRecipe:4 configuration:2 initialWeighting:1];
        mtSliderView = [objc_getClass("MTMaterialView") materialViewWithRecipe:4 configuration:3 initialWeighting:1];
    }
    else if(@available(iOS 11.0, *)) {
        mtBgView = [objc_getClass("MTMaterialView") materialViewWithRecipe:4 options:3 initialWeighting:1];
        mtSliderView = [objc_getClass("MTMaterialView") materialViewWithRecipe:4 options:32 initialWeighting:1];
    }
    else if(objc_getClass("MTMaterialView")) {
        mtBgView = [objc_getClass("MTMaterialView") materialViewWithStyleOptions:4 materialSettings:nil captureOnly:NO];
        mtSliderView = [objc_getClass("MTMaterialView") materialViewWithStyleOptions:1 materialSettings:nil captureOnly:NO];
    }
    else {
        mtBgView = [(_UIBackdropView *)[objc_getClass("_UIBackdropView") alloc] initWithStyle:2060];
        mtSliderView = [(_UIBackdropView *)[objc_getClass("_UIBackdropView") alloc] initWithStyle:100];
    }
    [mtBgView setFrame:self.bounds];
    [self addSubview:mtBgView];

    _clippingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)];
    _clippingView.clipsToBounds = YES;
    [self addSubview:_clippingView];


    [mtSliderView setFrame:self.bounds];
    [_clippingView addSubview:mtSliderView];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    [self addGestureRecognizer:longPress];
    longPress.minimumPressDuration = 0;



    return self;
}
- (void)initScale {
    NSNumber *scaleNumber = [self scaleFromPrefs];
    if(scaleNumber) {
        double scale = [scaleNumber doubleValue];
        [_clippingView setFrame:CGRectMake(_clippingView.frame.origin.x,
                                           _clippingView.frame.size.height * (1. - scale),
                                           _clippingView.frame.size.width,
                                           _clippingView.frame.size.height)];
        _curScale = scale;
    }
}
- (NSNumber *)scaleFromPrefs {
    return prefs[_bundleID];
}
- (void)saveScaleToPrefs:(NSNumber *)scale {
    prefs[_bundleID] = scale;
}
- (void)longPress:(UILongPressGestureRecognizer *)longPress {
    CGPoint currentLocation = [longPress locationInView:self];
    if(longPress.state == UIGestureRecognizerStateBegan) {
        _lastLocation = currentLocation;
        _feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [_feedback impactOccurred];
    }
    else if(longPress.state == UIGestureRecognizerStateChanged) {
        CGFloat dY = currentLocation.y - _lastLocation.y;
        _lastLocation = currentLocation;

        CGFloat newY = MIN(MAX(_clippingView.frame.origin.y + dY, 0), _clippingView.frame.size.height);
        [_clippingView setFrame:CGRectMake(_clippingView.frame.origin.x,
                                           newY,
                                           _clippingView.frame.size.width,
                                           _clippingView.frame.size.height)];
        CGFloat scale = 1. - _clippingView.frame.origin.y / _clippingView.frame.size.height;
        if(fabs(scale - _curScale) > 1. / 16. || scale <= 1. / 16.) {
            _curScale = scale;
            [_client callExternalMethod:@selector(setVolume:) withArguments:@{ @"curScale": @(_curScale) } completion:^(id ret){}];
        }
    }
    else if(longPress.state == UIGestureRecognizerStateEnded) {
        [_feedback impactOccurred];
        _feedback = nil;
        [self saveScaleToPrefs:@(_curScale)];
    }
}
- (void)setCurScale:(CGFloat)scale {
    _curScale = scale;
    [_clippingView setFrame:CGRectMake(_clippingView.frame.origin.x,
                                       _clippingView.frame.size.height * (1. - _curScale),
                                       _clippingView.frame.size.width,
                                       _clippingView.frame.size.height)];
    [_client callExternalMethod:@selector(setVolume:) withArguments:@{ @"curScale": @(_curScale) } completion:^(id ret){}];
    [self saveScaleToPrefs:@(_curScale)];
}
- (void)changeScale:(CGFloat)dScale {
    [self setCurScale:MIN(MAX(_curScale + dScale, 0.), 1.)];
}
@end
#import "VMHUDView.h"
#import "VMHUDWindow.h"
#import "TweakSB.h"
#import "MTMaterialView.h"
#import "_UIBackdropView.h"
#import "MRYIPC/MRYIPCCenter.h"
#import <objc/runtime.h>

@implementation VMHUDView {
    CGPoint _startingOrigin;
    UIImpactFeedbackGenerator *_feedback;
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(!self) return self;

    self.clipsToBounds = YES;
    self.layer.cornerRadius = 14.0;
    _curScale = 1.0;

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

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    [self addGestureRecognizer:pan];
    pan.delegate = (id<UIGestureRecognizerDelegate>)self;

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    [self addGestureRecognizer:longPress];
    longPress.delegate = (id<UIGestureRecognizerDelegate>)self;
    longPress.minimumPressDuration = 0.1;

    return self;
}
- (void)initScale {
    NSNumber *scaleNumber = [self scaleFromPrefs];
    if(scaleNumber) {
        double scale = [scaleNumber doubleValue];
        [_clippingView setFrame:CGRectMake(_clippingView.frame.origin.x,
                                           _clippingView.frame.size.height * (1.0 - scale),
                                           _clippingView.frame.size.width,
                                           _clippingView.frame.size.height)];
        _curScale = scale;
    }
}
- (NSNumber *)scaleFromPrefs {
    return [g_defaults objectForKey:kPrefScalesKey][_bundleID];
}
- (void)saveScaleToPrefs:(NSNumber *)scale {
    NSMutableDictionary *scales = [[g_defaults objectForKey:kPrefScalesKey] mutableCopy] ?: [NSMutableDictionary new];
    scales[_bundleID] = scale;
    [g_defaults setObject:scales forKey:kPrefScalesKey];
}
- (void)pan:(UIPanGestureRecognizer *)pan{
    if(pan.state == UIGestureRecognizerStateBegan) {
        _startingOrigin = _clippingView.frame.origin;
        if(!_feedback){
            _feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [_feedback impactOccurred];
        }
    }
    else if(pan.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [pan translationInView:pan.view];

        CGFloat newY = MIN(MAX(_startingOrigin.y + translation.y, 0), _clippingView.frame.size.height);
        [_clippingView setFrame:CGRectMake(_clippingView.frame.origin.x,
                                           newY,
                                           _clippingView.frame.size.width,
                                           _clippingView.frame.size.height)];
        CGFloat scale = 1.0 - _clippingView.frame.origin.y / _clippingView.frame.size.height;
        if(scale == _curScale){
            return;
        }
        if(fabs(scale - _curScale) > 1.0 / 16.0 || scale <= 1.0 / 16.0 || scale == 1.0) {
            _curScale = scale;
            _valueDidChange(_curScale);
        }
    }
    else if(pan.state == UIGestureRecognizerStateEnded) {
        [self saveScaleToPrefs:@(_curScale)];
        [_feedback impactOccurred];
        _feedback = nil;
    }
}
- (void)longPress:(UILongPressGestureRecognizer *)longPress{
    switch(longPress.state){
        case UIGestureRecognizerStateBegan:
            if(!_feedback){
                _feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
                [_feedback impactOccurred];
            }
            break;
        case UIGestureRecognizerStateEnded:
            [_feedback impactOccurred];
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            _feedback = nil;
            break;
        default:
            break;
    }
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    return YES;
}
- (void)setCurScale:(CGFloat)scale {
    _curScale = scale;
    [_clippingView setFrame:CGRectMake(_clippingView.frame.origin.x,
                                       _clippingView.frame.size.height * (1.0 - _curScale),
                                       _clippingView.frame.size.width,
                                       _clippingView.frame.size.height)];
    _valueDidChange(_curScale);
    [self saveScaleToPrefs:@(_curScale)];
}
- (void)changeScale:(CGFloat)dScale {
    [self setCurScale:MIN(MAX(_curScale + dScale, 0.0), 1.0)];
}
@end

@interface VMHUDView :UIView
// -(instancetype)initWithFrame:(CGRect)frame;
@property(strong) UIView*clippingView;
@property CGFloat curScale;
@property void(^volumeChangedCallBlock)(void);
@end
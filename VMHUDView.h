@interface VMHUDView : UIView
@property (strong, nonatomic) UIView *clippingView;
@property (strong, nonatomic) NSString *bundleID;
@property (weak, nonatomic) id client;
@property (nonatomic) CGFloat curScale;
- (void)initScale;
- (void)changeScale:(CGFloat)dScale;
@end
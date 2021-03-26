@interface VMHUDView : UIView
@property (strong) UIView *clippingView;
@property (nonatomic) CGFloat curScale;
@property (strong) NSString *bundleID;
@property (weak) id client;
-(void)initScale;
-(void)changeScale:(CGFloat)dScale;
@end
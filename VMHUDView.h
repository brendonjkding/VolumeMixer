@interface VMHUDView :UIView
@property(strong) UIView*clippingView;
@property CGFloat curScale;
@property (strong,nonatomic) NSString*bundleID;
@property id client;
-(void)initScale;
@end
@interface VMHUDView :UIView
@property(strong) UIView*clippingView;
@property CGFloat curScale;
@property void(^volumeChangedCallBlock)(void);
@property (strong,nonatomic) NSString*bundleID;
-(void)initScale;
@end
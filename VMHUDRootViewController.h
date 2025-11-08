@interface VMHUDRootViewController : UIViewController
- (void)loadPref;
- (void)increaseVolume;
- (void)decreaseVolume;
@property (nonatomic) UILabel *touchBlockView;
@end

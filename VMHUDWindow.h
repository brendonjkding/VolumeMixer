@interface VMHUDWindow : UIWindow
+ (id)sharedWindow;
- (void)changeVisibility;
- (void)showWindow;
- (void)hideWindow;
@end

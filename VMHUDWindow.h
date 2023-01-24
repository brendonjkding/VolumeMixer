@interface VMHUDWindow : UIWindow
+ (VMHUDWindow *)sharedWindow;
- (void)changeVisibility;
- (void)showWindow;
- (void)hideWindow;
@end

@interface VMHUDWindow : UIWindow
+ (VMHUDWindow *)sharedWindow;
- (void)changeVisibility;
- (void)showWindow;
- (void)hideWindow;
@property BOOL showsOnLockScreen;
@end

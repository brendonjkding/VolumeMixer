@interface VMHUDWindow:UIWindow
-(void) cancelAutoHide;
-(void) autoHide;
- (void)volumeChanged:(NSNotification *)notification;
-(void)changeVisibility;
-(void) hideWindow;
@end

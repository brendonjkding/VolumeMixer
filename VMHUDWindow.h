@interface VMHUDWindow:UIWindow
-(void) cancelAutoHide;
-(void) autoHide;
- (void)volumeChanged:(NSNotification *)notification;
-(void) hideWindow;
-(void) showWindow;
@end

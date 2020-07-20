@interface VMHUDWindow:UIWindow
-(void) cancelAutoHide;
-(void) autoHide;
- (void)volumeChanged:(NSNotification *)notification;
@end

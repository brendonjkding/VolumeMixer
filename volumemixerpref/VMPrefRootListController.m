#include "VMPrefRootListController.h"
#include "BDAppListController.h"
#include "BDInfoListController.h"
#include "VMLicenseViewController.h"
#import <Preferences/PSSpecifier.h>

#define VMNSLocalizedString(key) NSLocalizedStringFromTableInBundle((key),@"Root",[NSBundle bundleWithPath:@"/Library/PreferenceBundles/volumemixer.bundle"],nil)

@implementation VMPrefRootListController

- (NSArray *)specifiers {
  if (!_specifiers) {
    _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];

        PSSpecifier* spec;
        
        spec=[PSSpecifier emptyGroupSpecifier];
        [_specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Licenses"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(showLicenses);
        [_specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:VMNSLocalizedString(@"ABOUT_AUTHOR")
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(showInfo);
        [_specifiers addObject:spec];

  }

  return _specifiers;
}
- (id)readPreferenceValue:(PSSpecifier*)specifier {
    NSString *path = [NSString stringWithFormat:@"/User/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    if([specifier.properties[@"key"] isEqualToString:@"webEnabled"]) {
      NSArray*apps=settings[@"apps"];
      if(!apps) return @NO;
      return [NSNumber numberWithBool:[apps containsObject:kWebKitBundleId]];
    }
    return (settings[specifier.properties[@"key"]]) ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    NSString *path = [NSString stringWithFormat:@"/User/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    if([specifier.properties[@"key"] isEqualToString:@"webEnabled"]) {
      NSMutableArray*apps=[settings[@"apps"] mutableCopy];
      if(!apps) apps=[NSMutableArray new];
      if([value boolValue]&&![apps containsObject:kWebKitBundleId]){
        [apps addObject:kWebKitBundleId];
      }
      else if ([apps containsObject:kWebKitBundleId]){
        [apps removeObjectAtIndex:[apps indexOfObject:kWebKitBundleId]];
      }
    }
    else [settings setObject:value forKey:specifier.properties[@"key"]];
    [settings writeToFile:path atomically:YES];
    CFStringRef notificationName = (__bridge CFStringRef )specifier.properties[@"PostNotification"];
    if (notificationName) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
    }
}
-(void)showInfo{
  UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
  self.navigationItem.backBarButtonItem = backItem; 
  [self.navigationController pushViewController:[[BDInfoListController alloc] init] animated:YES];
}
-(void)selectAudiomixApp{
  UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
  self.navigationItem.backBarButtonItem = backItem; 
  [self.navigationController pushViewController:[[BDAppListController alloc] initWithDefaults:@"com.brend0n.volumemixer" andKey:@"audiomixApps"] animated:YES];
}
-(void)selectApp_{
  UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
  self.navigationItem.backBarButtonItem = backItem; 
  [self.navigationController pushViewController:[[BDAppListController alloc] initWithDefaults:@"com.brend0n.volumemixer" andKey:@"apps"] animated:YES];
}
-(void)selectApp{
  NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
  if(prefs) {
    NSString*key=prefs[@"didShowReleaseAlert"];
    if(key){
      [self selectApp_];
      return;  
    }
    
  }

  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:VMNSLocalizedString(@"BETA_ALERT_TITLE") message:VMNSLocalizedString(@"BETA_ALERT") preferredStyle:UIAlertControllerStyleAlert];

  UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:VMNSLocalizedString(@"ACTION_NO") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {}];

  UIAlertAction *okAction = [UIAlertAction actionWithTitle:VMNSLocalizedString(@"ACTION_YES") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    dispatch_async(dispatch_get_main_queue(), ^{
      NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
      if(!prefs) prefs=[NSMutableDictionary new];
      prefs[@"didShowReleaseAlert"]=@YES;
      [prefs writeToFile:kPrefPath atomically:YES];
      [self selectApp_];
    });
  }];

  [alertController addAction:cancelAction];
  [alertController addAction:okAction];
  [self presentViewController:alertController animated:YES completion:nil];
  
}
-(void)showLicenses{
  UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
  self.navigationItem.backBarButtonItem = backItem; 
  [self.navigationController pushViewController:[[VMLicenseViewController alloc] init] animated:TRUE];
}
@end

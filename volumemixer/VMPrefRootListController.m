#include "VMPrefRootListController.h"
#include "VMAPPListController.h"
#include "BDInfoListController.h"
#import <Preferences/PSSpecifier.h>

#define VMNSLocalizedString(key) NSLocalizedStringFromTableInBundle((key),@"Root",[NSBundle bundleWithPath:@"/Library/PreferenceBundles/volumemixer.bundle"],nil)

@implementation VMPrefRootListController

- (NSArray *)specifiers {
  if (!_specifiers) {
    _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];

        PSSpecifier* spec;
        
        spec = [PSSpecifier preferenceSpecifierNamed:VMNSLocalizedString(@"ABOUT_AUTHOR")
                                              target:self
                                              set:Nil
                                              get:Nil
                                              detail:Nil
                                              cell:PSGroupCell
                                              edit:Nil];
        [spec setProperty:@"作者" forKey:@"label"];
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
    return (settings[specifier.properties[@"key"]]) ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    NSString *path = [NSString stringWithFormat:@"/User/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    [settings setObject:value forKey:specifier.properties[@"key"]];
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
-(void)selectApp_{
  UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
  self.navigationItem.backBarButtonItem = backItem; 
  [self.navigationController pushViewController:[[VMAPPListController alloc] init] animated:YES];
}
#define prefPath @"/var/mobile/Library/Preferences/com.brend0n.volumemixer.plist"
-(void)selectApp{
  NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:prefPath];
  if(prefs) {
    NSString*key=prefs[@"didShowAlert"];
    if(key){
      [self selectApp_];
      return;  
    }
    
  }

  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:VMNSLocalizedString(@"BETA_ALERT_TITLE") message:VMNSLocalizedString(@"BETA_ALERT") preferredStyle:UIAlertControllerStyleAlert];

  UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:VMNSLocalizedString(@"ACTION_NO") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {}];

  UIAlertAction *okAction = [UIAlertAction actionWithTitle:VMNSLocalizedString(@"ACTION_YES") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    dispatch_async(dispatch_get_main_queue(), ^{
      NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:prefPath];
      if(!prefs) prefs=[NSMutableDictionary new];
      prefs[@"didShowAlert"]=@YES;
      [prefs writeToFile:prefPath atomically:YES];
      [self selectApp_];
    });
  }];

  [alertController addAction:cancelAction];
  [alertController addAction:okAction];
  [self presentViewController:alertController animated:YES completion:nil];
  
}
@end

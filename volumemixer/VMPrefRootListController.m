#include "VMPrefRootListController.h"
#include "VMAPPListController.h"
#include "BDInfoListController.h"
#import <Preferences/PSSpecifier.h>

@implementation VMPrefRootListController

- (NSArray *)specifiers {
  if (!_specifiers) {
    _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];

        PSSpecifier* spec;
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"关于作者"
                                              target:self
                                              set:Nil
                                              get:Nil
                                              detail:Nil
                                              cell:PSGroupCell
                                              edit:Nil];
        [spec setProperty:@"作者" forKey:@"label"];
        [_specifiers addObject:spec];
        spec = [PSSpecifier preferenceSpecifierNamed:@"关于作者"
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
  [self.navigationController pushViewController:[[BDInfoListController alloc] init] animated:TRUE];
}
-(void)selectApp{
  UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
  self.navigationItem.backBarButtonItem = backItem; 
  [self.navigationController pushViewController:[[VMAPPListController alloc] init] animated:TRUE];
}
@end

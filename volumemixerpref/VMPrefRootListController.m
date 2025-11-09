#import "VMPrefRootListController.h"
#import "BDInfoListController.h"
#import "VMLicenseViewController.h"
#import "VMAuthorListController.h"
#import <Preferences/PSSpecifier.h>
#import <objc/runtime.h>
#import <notify.h>
#import <dlfcn.h>

extern UIApplication *UIApp;

@implementation VMPrefRootListController{
  NSDictionary *_old_prefs;
  NSUserDefaults *_defaults;
}

- (void)viewDidLoad{
  [super viewDidLoad];

  // Credit: Polyfills — com.apple.UIKit usage
  _defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.apple.UIKit"];
  _old_prefs = [NSDictionary dictionaryWithContentsOfFile:@THEOS_PACKAGE_INSTALL_PREFIX"/var/mobile/Library/Preferences/com.brend0n.volumemixer.plist"];

  if([_defaults objectForKey:kPrefDidShowReleaseAlertKey] || _old_prefs[@"didShowReleaseAlert"]){
    return;
  }

  if(!objc_getClass("UIAlertController")){
    return;
  }

  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:VMNSLocalizedString(@"BETA_ALERT_TITLE") message:VMNSLocalizedString(@"BETA_ALERT") preferredStyle:UIAlertControllerStyleAlert];

  UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:VMNSLocalizedString(@"ACTION_NO") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
      if([[UIDevice currentDevice].model isEqualToString:@"iPad"]){
        exit(0);
      }
      else{
        [self.parentViewController.navigationController popViewControllerAnimated:YES];
      }
  }];

  UIAlertAction *okAction = [UIAlertAction actionWithTitle:VMNSLocalizedString(@"ACTION_YES") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [_defaults setObject:@YES forKey:kPrefDidShowReleaseAlertKey];
    });
  }];

  [alertController addAction:cancelAction];
  [alertController addAction:okAction];
  [self presentViewController:alertController animated:YES completion:nil];
}

- (NSArray *)specifiers {
  if (!_specifiers) {
    _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];

        PSSpecifier* spec;
        
        spec=[self specifierForID:@"PANEL_PORTRAIT_Y"];
        [spec setProperty:@0 forKey:@"min"];
        [spec setProperty:@(MAX(UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height)) forKey:@"max"];
        [spec setProperty:@200 forKey:@"default"];

        spec=[self specifierForID:@"PANEL_LANDSCAPE_Y"];
        [spec setProperty:@0 forKey:@"min"];
        [spec setProperty:@(MIN(UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height)) forKey:@"max"];
        [spec setProperty:@(MIN(UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height)/2.) forKey:@"default"];

        spec=[self specifierForID:@"AUDIO_MIX_CREDIT_GROUP"];
        [spec setProperty:@"PSFooterHyperlinkView" forKey:@"footerCellClass"];
        [spec setProperty:VMNSLocalizedString(@"AUDIO_MIX_CREDIT") forKey:@"headerFooterHyperlinkButtonTitle"];
        [spec setProperty:NSStringFromRange([VMNSLocalizedString(@"AUDIO_MIX_CREDIT") rangeOfString:VMNSLocalizedString(@"AUDIO_MIX_CREDIT_HYPERLINK_TEXT")]) forKey:@"footerHyperlinkRange"];
        [spec setProperty:[NSValue valueWithNonretainedObject:self] forKey:@"footerHyperlinkTarget"];
        [spec setProperty:@"openOnewayticket" forKey:@"footerHyperlinkAction"];

        dlopen("/usr/lib/libactivator.dylib", RTLD_LAZY);
        Class la = objc_getClass("LAActivator");
        if(!la){
          for(NSString *specifierId in @[@"BY_ACTIVATOR",@"ACTIVATOR_VOLUME_UP",@"ACTIVATOR_VOLUME_DOWN"]){
            spec=[self specifierForID:specifierId];
            [spec setButtonAction:@selector(openActivator)];
          }
        }
        if(!objc_getClass("CCSModuleProviderManager")){
          [[self specifierForID:@"ControlCenter"] setButtonAction:@selector(openCCSupport)];
        }

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

        spec = [PSSpecifier preferenceSpecifierNamed:[[NSBundle bundleForClass:[self class]] localizedStringForKey:@"AUTHOR" value:@"Author" table:@"Root"]
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        spec->action = @selector(showAuthors);
        [_specifiers addObject:spec];

  }

  return _specifiers;
}

-(void)_reset{
  for(NSString *key in kAllPrefKeys){
    [_defaults removeObjectForKey:key];
  }
  [self reloadSpecifiers];
  notify_post("com.brend0n.volumemixer/loadPref");
}
- (void)_migrate{
  for(NSString *oldKey in _old_prefs){
    id value = _old_prefs[oldKey];
    NSString *newKey = [@"com.brend0n.volumemixer_" stringByAppendingString:oldKey];
    if([kAllPrefKeys containsObject:newKey]){
      [_defaults setObject:value forKey:newKey];
    }
    else if([value isKindOfClass:NSNumber.class]){
      NSString *bundleID = oldKey;
      NSNumber *scale = value;
      if(scale.doubleValue>=0.0 && scale.doubleValue<=1.0){
        NSMutableDictionary *scales = [[_defaults objectForKey:kPrefScalesKey] mutableCopy] ?: [NSMutableDictionary new];
        scales[bundleID] = scale;
        [_defaults setObject:scales forKey:kPrefScalesKey];
      }
    }
  }
  if([_old_prefs[@"apps"] containsObject:kWebKitBundleId]){
    [_defaults setObject:@YES forKey:kPrefWebEnabledKey];
  }
  [self reloadSpecifiers];
  notify_post("com.brend0n.volumemixer/loadPref");
}
- (void)showConfirmAlert:(PSSpecifier *)specifier{
  NSString *title = VMNSLocalizedString(specifier.properties[@"label"]);
  NSString *message = VMNSLocalizedString([specifier.properties[@"label"] stringByAppendingString:@"_"]);
  void (^okHandler)(UIAlertAction *) = ^(UIAlertAction *action){
    SEL selector = NSSelectorFromString(specifier.identifier);
    ((void (*)(id, SEL))[self methodForSelector:selector])(self, selector);
  };

  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
  [alertController addAction:[UIAlertAction actionWithTitle:VMNSLocalizedString(@"CANCEL") style:UIAlertActionStyleCancel handler:nil]];
  [alertController addAction:[UIAlertAction actionWithTitle:VMNSLocalizedString(@"CONFIRM") style:UIAlertActionStyleDefault handler:okHandler]];
  [self presentViewController:alertController animated:YES completion:nil];
}

- (void)showAuthors{
  UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
  self.navigationItem.backBarButtonItem = backItem;
  [self.navigationController pushViewController:[[VMAuthorListController alloc] init] animated:YES];
}
- (void)showLicenses{
  UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
  self.navigationItem.backBarButtonItem = backItem; 
  [self.navigationController pushViewController:[[VMLicenseViewController alloc] init] animated:TRUE];
}
- (void)openOnewayticket{
  [UIApp openURL:[NSURL URLWithString:@"https://github.com/onewayticket255"]];
}
- (void)openActivator{
  [UIApp openURL:[NSURL URLWithString:@"cydia://package/libactivator"]];
}
- (void)openCCSupport{
  if([UIApp canOpenURL:[NSURL URLWithString:@"cydia://package/com.opa334.ccsupport"]]){
    [UIApp openURL:[NSURL URLWithString:@"cydia://package/com.opa334.ccsupport"]];
  }
  else{
    [UIApp openURL:[NSURL URLWithString:@"sileo://package/com.opa334.ccsupport"]];
  }
}
@end

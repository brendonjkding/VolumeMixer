#import "BDAppListController.h"
#import "VMPref.h"
#import <Preferences/PSSpecifier.h>
#import <AppList/AppList.h>

@interface PSControlTableCell : PSTableCell
@end
@interface PSSwitchTableCell : PSControlTableCell
- (id)initWithStyle:(int)style reuseIdentifier:(id)identifier specifier:(PSSpecifier*)specifier;
@end
@interface BDAPPSwitchTableCell:PSSwitchTableCell
@end
@implementation BDAPPSwitchTableCell
-(id)initWithStyle:(int)style reuseIdentifier:(id)identifier specifier:(PSSpecifier*)specifier { //init method
  self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier specifier:specifier]; //call the super init method
  if (self) {
    self.detailTextLabel.text=specifier.properties[@"detail"];
  }
  return self;
}

@end


@interface BDAppListController()<UISearchControllerDelegate,UISearchBarDelegate,UISearchResultsUpdating>

@property (strong, nonatomic) UISearchController *searchController;
@property (strong, nonatomic) NSString*searchKey;
@property (strong, nonatomic) NSString*key;
@property (strong, nonatomic) NSString*defaults;
@property UIBarButtonItem *rightItem;

@end

@implementation BDAppListController
-(id)initWithDefaults:(NSString*)defaults andKey:(NSString*)key{
  self=[super init];
  if(!self) return self;
  _searchKey=@"";
  _key=key;
  _defaults=defaults;
  return self;
}
-(void)loadView{
	[super loadView];

  self.navigationItem.title = @"";
  
  self.searchController = [[UISearchController alloc]initWithSearchResultsController:nil];
  self.searchController.searchResultsUpdater = self;
  if(@available(iOS 9.1, *)) self.searchController.obscuresBackgroundDuringPresentation = NO;


  if (@available(iOS 11.0, *)) {
      self.navigationItem.searchController = self.searchController;
      self.navigationItem.hidesSearchBarWhenScrolling=NO;
  } else {
      self.table.tableHeaderView = self.searchController.searchBar;
  }

  _rightItem=[[UIBarButtonItem alloc] initWithTitle:VMNSLocalizedString(@"SELECT_DESELECT_ALL") style:UIBarButtonItemStylePlain target:self action:@selector(rightBarItemClicked:)];
  self.navigationItem.rightBarButtonItem=_rightItem;
    
}
- (void)selectAll{
    NSMutableArray*apps=[NSMutableArray new];
    if([prefs[_key] containsObject:kWebKitBundleId]) [apps addObject:kWebKitBundleId];

    NSArray *sortedDisplayIdentifiers;
    [[ALApplicationList sharedApplicationList] applicationsFilteredUsingPredicate:[NSPredicate predicateWithFormat:@"isInternalApplication = FALSE"]
      onlyVisible:YES titleSortedIdentifiers:&sortedDisplayIdentifiers];
    for(id displayIdentifier in sortedDisplayIdentifiers) [apps addObject:displayIdentifier];
    prefs[_key]=apps;

    [self reloadSpecifiers];

}
- (void)deselectAll{
    NSMutableArray*apps=[NSMutableArray new];
    if([prefs[_key] containsObject:kWebKitBundleId]) [apps addObject:kWebKitBundleId];
    prefs[_key]=apps;

    [self reloadSpecifiers];
}
- (void)rightBarItemClicked:(UIBarButtonItem *)item{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:VMNSLocalizedString(@"CANCEL") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){

    }];

    UIAlertAction *deSelectAllAction = [UIAlertAction actionWithTitle:VMNSLocalizedString(@"DESELECT_ALL") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      [self deselectAll];
    }];

    UIAlertAction *selectAllAction = [UIAlertAction actionWithTitle:VMNSLocalizedString(@"SELECT_ALL") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
      [self selectAll];
    }];

    [alertController addAction:selectAllAction];
    [alertController addAction:deSelectAllAction];
    [alertController addAction:cancelAction];
    [self presentViewController:alertController animated:YES completion:nil];
}
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController{
  _searchKey=searchController.searchBar.text;
  [self reloadSpecifiers];
}
- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [NSMutableArray arrayWithCapacity:256];
    // sort the apps by display name. displayIdentifiers is an autoreleased object.
    NSArray *sortedDisplayIdentifiers;
    NSDictionary *applications = [[ALApplicationList sharedApplicationList] applicationsFilteredUsingPredicate:[NSPredicate predicateWithFormat:@"isInternalApplication = FALSE"]
      onlyVisible:YES titleSortedIdentifiers:&sortedDisplayIdentifiers];
    // NSLog(@"app count:%lu",[applications count]);

    PSSpecifier* spec;
    for(id displayIdentifier in sortedDisplayIdentifiers){
      UIImage *icon = [[ALApplicationList sharedApplicationList] iconOfSize:ALApplicationIconSizeSmall forDisplayIdentifier:displayIdentifier];
      NSString *displayName = applications[displayIdentifier];
      if(![displayIdentifier localizedStandardContainsString:_searchKey]&&![displayName localizedStandardContainsString:_searchKey]&&![_searchKey isEqualToString:@""]) continue;
      spec = [PSSpecifier preferenceSpecifierNamed:displayName
                                              target:self
                                              set:@selector(setPreferenceValue:specifier:)
                                              get:@selector(readPreferenceValue:)
                                              detail:Nil
                                              cell:PSSwitchCell
                                              edit:Nil];
      [spec setProperty:displayIdentifier forKey:@"displayIdentifier"];
      [spec setProperty:@YES forKey:@"hasIcon"];
      [spec setProperty:icon forKey:@"iconImage"];
      [spec setProperty:_defaults forKey:@"defaults"];
      [spec setProperty:displayIdentifier forKey:@"detail"];
      [spec setProperty:NSClassFromString(@"BDAPPSwitchTableCell") forKey:@"cellClass"];
      
      [_specifiers addObject:spec];
        
        
    }
}

	return _specifiers;
}
- (id)readPreferenceValue:(PSSpecifier*)specifier {
    return @([prefs[_key] containsObject:specifier.properties[@"displayIdentifier"]]);
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    NSMutableArray*apps=[prefs[_key] mutableCopy]?:[NSMutableArray new];
    NSString*displayIdentifier=specifier.properties[@"displayIdentifier"];
    if([value boolValue]&&![apps containsObject:displayIdentifier]){
      [apps addObject:displayIdentifier];
    }
    else if ([apps containsObject:displayIdentifier]){
      [apps removeObjectAtIndex:[apps indexOfObject:displayIdentifier]];
    }

    [prefs setObject:apps forKey:_key];
}
@end
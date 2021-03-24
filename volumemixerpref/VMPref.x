#import "VMPref.h"
HBPreferences *prefs;

%ctor{
    prefs = [[HBPreferences alloc] initWithIdentifier:@"com.brend0n.volumemixer"];
}
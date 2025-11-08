#import "VMPref.h"

HBPreferences *prefs = nil;

%ctor{
    prefs = [[HBPreferences alloc] initWithIdentifier:@"com.brend0n.volumemixer"];
}

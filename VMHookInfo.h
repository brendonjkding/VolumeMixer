#import <AudioUnit/AudioUnit.h>

@interface VMHookInfo : NSObject
@property void *outputCallback;
@property UInt32 mFormatFlags;
@property void *inRefCon;
@property AudioUnitScope inScope;
@property AudioUnitElement inElement;
@end

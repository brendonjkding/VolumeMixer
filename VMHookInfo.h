#import <AudioUnit/AudioUnit.h>

@interface VMHookInfo : NSObject
@property AURenderCallback inputProc;
@property UInt32 mFormatFlags;
@property UInt32 mBitsPerChannel;
@property void *inRefCon;
@property AudioUnitScope inScope;
@property AudioUnitElement inElement;
@end

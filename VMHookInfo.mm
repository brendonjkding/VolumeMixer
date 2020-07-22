#import "VMHookInfo.h"
#import <AudioUnit/AudioUnit.h>
#import <substrate.h>

template<class T>
extern OSStatus my_outputCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
		const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);
extern NSMutableDictionary* origCallbacks;

@implementation VMHookInfo
-(void)hookIfReady{
	/*
		kAudioFormatFlagIsFloat                     = (1U << 0),     // 0x1
	    kAudioFormatFlagIsBigEndian                 = (1U << 1),     // 0x2
	    kAudioFormatFlagIsSignedInteger             = (1U << 2),     // 0x4
	    kAudioFormatFlagIsPacked                    = (1U << 3),     // 0x8
	    kAudioFormatFlagIsAlignedHigh               = (1U << 4),     // 0x10
	    kAudioFormatFlagIsNonInterleaved            = (1U << 5),     // 0x20
	    kAudioFormatFlagIsNonMixable                = (1U << 6),     // 0x40
	    kAudioFormatFlagsAreAllClear                = 0x80000000,
    */
	static int cs=0,cf=0;
	if(!_hooked&&_outputCallback&&_mFormatFlags&&_inRefCon){
		NSLog(@"???");
		if(_mFormatFlags&kAudioFormatFlagIsFloat){
			MSHookFunction((void *)_outputCallback, (void *)my_outputCallback<float>, (void **)&_orig_outputCallback);
			NSLog(@"%d: hook float",cf++);
		}
		else{
			MSHookFunction((void *)_outputCallback, (void *)my_outputCallback<short>, (void **)&_orig_outputCallback);
			NSLog(@"%d: hook short",cs++);
		}
		_hooked=YES;
		NSString*key=[NSString stringWithFormat:@"%ld",(long)_inRefCon];
		origCallbacks[key]=[NSNumber numberWithLong:(long)_orig_outputCallback];
	}
}
@end
#import "VMHookInfo.h"
#import <AudioUnit/AudioUnit.h>
#import <substrate.h>
#import "VMHookAudioUnit.hpp"

// key: outputCallbackAddressString value: addressForCalling
NSMutableDictionary<NSString*,NSNumber*> *hookedCallbacks;

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
	static int cn=0,cc=0;
	//different callback hooked to same my but need different orig, use inrefcon to differ
	
	if(_outputCallback && _mFormatFlags && _inRefCon){
		//only hook once
		NSString*outputCallbackString=[NSString stringWithFormat:@"%p",_outputCallback];
		NSLog(@"checking: %@",outputCallbackString);
		if(!hookedCallbacks[outputCallbackString]){
			if(_mFormatFlags&kAudioFormatFlagIsFloat){
				MSHookFunction((void *)_outputCallback, (void *)my_outputCallback<float>, (void **)&_orig_outputCallback);
				NSLog(@"float");
			}
			else{
				MSHookFunction((void *)_outputCallback, (void *)my_outputCallback<short>, (void **)&_orig_outputCallback);
				NSLog(@"short");
			}

			//what if one callback has multiple inrefcon
			NSString*key=[NSString stringWithFormat:@"%p",_inRefCon];
			origCallbacks[key]=[NSNumber numberWithLong:(long)_orig_outputCallback];
			NSLog(@"[*]new hook %d: %@",++cn, outputCallbackString);

			hookedCallbacks[outputCallbackString]=[NSNumber numberWithLong:(long)_orig_outputCallback];

			//what if callback of one unit is set multiple times. 
			_outputCallback=0;
			_mFormatFlags=0;
			_inRefCon=0;
		}
		else{
			NSString*key=[NSString stringWithFormat:@"%p",_inRefCon];
			origCallbacks[key]=hookedCallbacks[outputCallbackString];
			NSLog(@"[*]cached hook %d: %@",++cc, outputCallbackString);
		}
		
	}
}
@end
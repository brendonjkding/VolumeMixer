#import <notify.h>
#import <substrate.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>

BOOL enabled;
UInt32 mFormatID=0;

BOOL loadPref(){
	NSLog(@"loadPref..........");
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.brend0n.volumemixer.plist"];
	if(!prefs) enabled=YES;
	else enabled=[prefs[@"enabled"] boolValue];
	return enabled;
}
BOOL is_enabled_app(){
	NSString* bundleIdentifier=[[NSBundle mainBundle] bundleIdentifier];
	if([bundleIdentifier isEqualToString:@"com.bilibili.priconne"])return YES;
	if([bundleIdentifier isEqualToString:@"com.github.GBA4iOS.brend0n"])return YES;
	return YES;

	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.brend0n.volumemixer.plist"];
	NSArray *apps=prefs?prefs[@"apps"]:nil;
	if(!apps) return NO;
	if([apps containsObject:bundleIdentifier]) return YES;

	return NO;
}
template<class T>
static int volume_adjust(T  * in_buf, T  * out_buf, double in_vol)
{
    double tmp;

    // in_vol[0, 100]
//    float vol = in_vol - 98;
//
//    if(-98<vol && vol<0)
//        vol = 1/(vol*(-1));
//    else if(0<=vol && vol<=1)
//        vol = 1;
//    /*
//    else if(1<=vol && vol<=2)
//        vol = vol;
//    */
//    else if(vol<=-98)
//        vol = 0;
//    else if(vol>=2)
//        vol = 40;  //这个值可以根据你的实际情况去调整
    double vol=in_vol/100.0;

    tmp = (*in_buf)*vol; // 上面所有关于vol的判断，其实都是为了此处*in_buf乘以一个倍数，你可以根据自己的需要去修改

    // 下面的code主要是为了溢出判断
    if(sizeof(T)==2){
    	if(tmp > 32767)
        tmp = 32767;
    	else if(tmp < -32768)
        tmp = -32768;
    }
    else{
    	if(tmp > 4294967296)
        tmp = 4294967296;
    	else if(tmp < -4294967296)
        tmp = -4294967296;
    }
    
    *out_buf = tmp;

    return 0;
}
// typedef OSStatus(*orig_t)(void*,AudioUnitRenderActionFlags*,const AudioTimeStamp*,UInt32,UInt32,AudioBufferList*);
static OSStatus (*orig_outputCallback32)(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
		const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);
static OSStatus (*orig_outputCallback64)(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
		const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);
template<class T>
OSStatus my_outputCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
		const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
	//
	OSStatus ret;
	//if there is multiple audio unit, what will happen......
	if(sizeof(T)==2){
		ret=orig_outputCallback32(inRefCon,ioActionFlags,inTimeStamp,inBusNumber,inNumberFrames,ioData);
	}
	else{
		ret=orig_outputCallback64(inRefCon,ioActionFlags,inTimeStamp,inBusNumber,inNumberFrames,ioData);
	}
	// NSLog(@"orig_outputCallback");
	if(*ioActionFlags==kAudioUnitRenderAction_OutputIsSilence){
		return ret;
	}
	// NSLog(@"%lu",sizeof(T));
	// return ret;
	// NSLog(@"%u",ioData -> mNumberBuffers);
	// for (UInt32 i = 1; i < MIN(2,ioData->mNumberBuffers); i++){
	for (UInt32 i = 0; i < ioData -> mNumberBuffers; i++){
		auto *buf = (unsigned char*)ioData->mBuffers[i].mData;

		uint bytes = ioData->mBuffers[i].mDataByteSize;
		

	    // static int volume=0;
	//    abort();
	    // for(UInt32 j=0;j<bytes;j+=2){
	    //     volume_adjust((short*)(buf+j), (short*)(buf+j), (float)((25)%100));
	    // }
	    for(UInt32 j=0;j<bytes;j+=sizeof(T)){
	        volume_adjust((T*)(buf+j), (T*)(buf+j), (float)((10)%100));
	    }
	}
	
    
	return ret;
}
void *outputCallback;
UInt32 mFormatFlags;

void hookIfReady(){
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
	if(mFormatFlags){
		static int cs=0,cf=0;
		if(mFormatFlags&kAudioFormatFlagIsFloat){
			MSHookFunction((void *)outputCallback, (void *)my_outputCallback<float>, (void **)&orig_outputCallback64);
			NSLog(@"%d: hook float",cf++);
		}
		else{
			MSHookFunction((void *)outputCallback, (void *)my_outputCallback<short>, (void **)&orig_outputCallback32);
			NSLog(@"%d: hook short",cs++);
		}
		
		
		mFormatFlags=0;
		return;
	}
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
	// if([[UIApplication sharedApplication] keyWindow]){
		hookIfReady();

	});
}

%group hook
%hookf(OSStatus, AudioUnitSetProperty, AudioUnit inUnit, AudioUnitPropertyID inID, AudioUnitScope inScope, AudioUnitElement inElement, const void *inData, UInt32 inDataSize){

	// method 1:
	OSStatus ret=%orig;
	// inID
	/*
		kAudioUnitProperty_SetRenderCallback 23
		kAudioUnitProperty_StreamFormat		 8
	*/

	// inScope
	/*
		kAudioUnitScope_Global		= 0,
		kAudioUnitScope_Input		= 1,
		kAudioUnitScope_Output		= 2,
	*/
	//assume RenderCallback is set after StreamFormat
	if(inID==kAudioUnitProperty_SetRenderCallback){//23
		NSLog(@"kAudioUnitProperty_SetRenderCallback: %ld",(long)inUnit);	
		NSLog(@"	AudioUnitScope:%u",inScope);
		// if(inScope&kAudioUnitScope_Input){
			outputCallback=(void*)*(long*)inData;
			NSLog(@"	outputCallback:%ld",*(long*)inData);
			hookIfReady();
		// }
		
	}
	else if(inID==kAudioUnitProperty_StreamFormat){//8
		NSLog(@"kAudioUnitProperty_StreamFormat: %ld",(long)inUnit);
		NSLog(@"	AudioUnitScope:%u",inScope);
	    // if(inScope&kAudioUnitScope_Input){
			//to do: other format
	    	UInt32 mFormatID=((AudioStreamBasicDescription*)inData)->mFormatID;
			// NSLog(@"FormatID: %u",mFormatID);
			if(mFormatID!=kAudioFormatLinearPCM) {
				return ret;
				NSLog(@"not pcm");
			}
			mFormatFlags=((AudioStreamBasicDescription*)inData)->mFormatFlags;	
			NSLog(@"	mFormatFlags: %u",mFormatFlags);
		// }

	}	
	return ret;


	// //methoed 2: failed
	// AURenderCallbackStruct renderCallbackProp =
	// {
	// 	my_outputCallback,
	// 	//nullptr
	// };
	// if(inID==kAudioUnitProperty_SetRenderCallback){
	// 	orig_outputCallback=(orig_t)*(long*)inData;
	// 	return %orig(inUnit,inID,inScope,inElement,&renderCallbackProp,sizeof(renderCallbackProp));
	// }
	// return %orig;
}
%end
%ctor{
	if(!is_enabled_app()) return;
	// if(!loadPref()) return;
	NSLog(@"ctor: VolumeMixer");

	%init(hook);

	int token = 0;
	notify_register_dispatch("com.brend0n.volumemixer/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
		loadPref();
	});
}

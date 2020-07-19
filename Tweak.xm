#import <notify.h>
#import <substrate.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "VMHUDView.h"
#import "VMHUDWindow.h"
#import <OpenAL/OpenAL.h>

%config(generator=MobileSubstrate)

BOOL enabled;
UInt32 mFormatID=0;
VMHUDWindow*hudWindow;
AudioQueueRef lstAudioQueue;
AVPlayer* lstAVPlayer;
AVAudioPlayer* lstAVAudioPlayer;

@implementation VMHUDWindow

- (id)initWithFrame:(CGRect)frame{
	self=[super initWithFrame:frame];
	[self configureUI];

	// [[NSNotificationCenter defaultCenter]
 //     addObserver:self
 //     selector:@selector(volumeChanged:)
 //     name:@"AVSystemController_SystemVolumeDidChangeNotification"
 //     object:nil];


	[self hideWindow];

	return self;
}
// -(id)initWithWindowScene:(UIWindowScene *)windowScene{
// 	self=[super initWithWindowScene:windowScene];
// 	[self configureUI];
// 	return self;
// }


-(void) configureUI{
	NSLog(@"configureUI");
	self.windowLevel = UIWindowLevelStatusBar;
	[self setHidden:NO];
	[self setAlpha:1.0];
	[self setBackgroundColor:[UIColor clearColor]];
	// [self makeKeyAndVisible];
}
-(void) hideWindow{
	[self setHidden:YES];
}
-(void) showWindow{
	[self setHidden:NO];
}
-(void) cancelAutoHide{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideWindow) object:nil];
}
-(void) autoHide{
	[self performSelector:@selector(hideWindow) withObject:nil afterDelay:2];
} 

- (void)volumeChanged:(NSNotification *)notification{
	// NSLog(@"???");
	[self cancelAutoHide];
	[self showWindow];
	[self autoHide];
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitTestView = [super hitTest:point withEvent:event];
    // NSLog(@"%@",[hitTestView class]);
    if(hitTestView ==self||hitTestView==[self rootViewController].view){
    	return nil;
    }
    return hitTestView;
    // if (hitTestView == button||[hitTestView superview]==button) 
    // {
    //     return hitTestView;
    // }
    // else
    // {
    //     return nil;
    // }
}
@end
BOOL loadPref(){
	NSLog(@"loadPref..........");
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.brend0n.volumemixer.plist"];
	if(!prefs) enabled=YES;
	else enabled=[prefs[@"enabled"] boolValue];
	return enabled;
}
BOOL is_enabled_app(){
	NSString* bundleIdentifier=[[NSBundle mainBundle] bundleIdentifier];
	// if([bundleIdentifier isEqualToString:@"com.bilibili.priconne"])return YES;
	// if([bundleIdentifier isEqualToString:@"com.github.GBA4iOS.brend0n"])return YES;
	// return YES;

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
    double vol=in_vol;

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

VMHUDView* hudview;

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
	// NSLog(@"inRefCon: %p",inRefCon);
	if(!hudview) return ret;
	CGFloat curScale=[hudview curScale];
	for (UInt32 i = 0; i < ioData -> mNumberBuffers; i++){
		auto *buf = (unsigned char*)ioData->mBuffers[i].mData;

		uint bytes = ioData->mBuffers[i].mDataByteSize;
		

	    // static int volume=0;
	//    abort();
	    // for(UInt32 j=0;j<bytes;j+=2){
	    //     volume_adjust((short*)(buf+j), (short*)(buf+j), (float)((25)%100));
	    // }
	    for(UInt32 j=0;j<bytes;j+=sizeof(T)){
	        volume_adjust((T*)(buf+j), (T*)(buf+j), curScale);
	    }
	}
	
    
	return ret;
}
void *outputCallback;
UInt32 mFormatFlags;


void showHUDWindow(){
	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
    	NSLog(@"showing");
    	void(^blockForMain)(void) = ^{
				CGRect bounds=[UIScreen mainScreen].bounds;
		    	CGFloat sWidth=MIN(bounds.size.width,bounds.size.height);
		    	CGFloat sHeight=MAX(bounds.size.width,bounds.size.height);
		    	CGFloat hudWidth=47.*sWidth/(750./2.);
		    	CGFloat hudHeight=148.*sHeight/(1334./2.);
		        hudWindow =[[VMHUDWindow alloc] initWithFrame:bounds];
		        // [window makeKeyAndVisible];
		        hudview=[[VMHUDView alloc] initWithFrame:CGRectMake((sWidth-hudWidth)/2.,(sHeight-hudHeight)/2.,hudWidth,hudHeight)];
		        [hudview setVolumeChangedCallBlock:^{
		        	if(lstAudioQueue) AudioQueueSetParameter(lstAudioQueue,kAudioQueueParam_Volume,[hudview curScale]);
		        	[lstAVPlayer setVolume:[hudview curScale]];
		        	[lstAVAudioPlayer setVolume:[hudview curScale]];
		        }];
				[hudWindow addSubview:hudview];
			};
		if ([NSThread isMainThread]) blockForMain();
		else dispatch_async(dispatch_get_main_queue(), blockForMain);
    	
    });
}

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

		showHUDWindow();
		
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
		AURenderCallbackStruct *callbackSt=(AURenderCallbackStruct*)inData;

		NSLog(@"context: %p",callbackSt->inputProcRefCon);
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

/*
	kAudioQueueParam_Volume         = 1,
    kAudioQueueParam_PlayRate       = 2,
    kAudioQueueParam_Pitch          = 3,
    kAudioQueueParam_VolumeRampTime = 4,
    kAudioQueueParam_Pan            = 13
*/
%hookf(OSStatus ,AudioQueueSetParameter,AudioQueueRef inAQ, AudioQueueParameterID inParamID, AudioQueueParameterValue inValue){
	showHUDWindow();
	lstAudioQueue=inAQ;
	NSLog(@"%p %u %lf",(void*)inAQ,inParamID,inValue);
	if(hudview) {
		if(inParamID==kAudioQueueParam_Volume){
			return %orig(inAQ,inParamID,[hudview curScale]);
		}
	}

	return %orig(inAQ,inParamID,inValue);
}
%end
%group SB
%hook  SBVolumeHardwareButton
- (void)volumeDecreasePress:(id)arg1{
	%orig;
	NSLog(@"volumeDecreasePress: %@",arg1);
	notify_post("com.brend0n.volumemixer/volumePressed");
}
- (void)volumeIncreasePress:(id)arg1{
	%orig;
	NSLog(@"volumeIncreasePress: %@",arg1);
	notify_post("com.brend0n.volumemixer/volumePressed");
}
%end
// %hook MTMaterialView
// +(id)materialViewWithRecipe:(NSInteger)arg1 configuration:(NSInteger)arg2 initialWeighting:(CGFloat)arg3{
// 	NSLog(@"%ld %ld %lf",arg1,arg2,arg3);
// 	return %orig;
// }
// +(id)materialViewWithRecipe:(NSInteger)arg1 options:(NSInteger)arg2 initialWeighting:(CGFloat)arg3{
// 	NSLog(@"%ld %ld %lf",arg1,arg2,arg3);
// 	return %orig;

// }
// %end
%hook SpringBoard

- (void)_ringerChanged:(id)arg1{
	NSLog(@"_ringerChanged: %@",arg1);
	notify_post("com.brend0n.volumemixer/volumePressed");
	%orig;
}
// - (BOOL)_handlePhysicalButtonEvent:(id)arg1{
// 	NSLog(@"_handlePhysicalButtonEvent");
// 	return %orig;
// }
%end
%end//sb





%group test
%hookf(ALCdevice*,alcOpenDevice ,const ALCchar *devicename){
	NSLog(@"openal!!!");
	return %orig;
}

%hookf(void, alcGetProcAddress,ALCdevice *device, const ALCchar *funcName){
	NSLog(@"openal!!!");
	%orig;
}
// %hookf(OSStatus,AudioQueueAllocateBuffer,AudioQueueRef inAQ, UInt32 inBufferByteSize, AudioQueueBufferRef *outBuffer ){
// 	NSLog(@"AudioQueueAllocateBuffer!!!");
// 	return %orig(inAQ,inBufferByteSize,outBuffer);
// }

%hook AVAudioPlayer
-(id)alloc{
	NSLog(@"AVAudioPlayer alloc");
	return %orig;
}
-(void)play{
	NSLog(@"AVAudioPlayer play %@",self);
	lstAVAudioPlayer=self;
	[self setVolume:[hudview curScale]];
	return %orig;
}
%end
%hook AVPlayer
-(void)play{
	NSLog(@"AVPlayer play %@",self);
	lstAVPlayer=self;
	[self setVolume:[hudview curScale]];
	return %orig;
}
-(void)setVolume:(float)volume{
	NSLog(@"setVolume: %f",volume);
	return %orig;
}

-(id)alloc{
	NSLog(@"AVPlayer alloc");
	return %orig;
}
%end
%hookf(OSStatus, AudioFileOpenWithCallbacks,void *inClientData, AudioFile_ReadProc inReadFunc, AudioFile_WriteProc inWriteFunc, AudioFile_GetSizeProc inGetSizeFunc, AudioFile_SetSizeProc inSetSizeFunc, AudioFileTypeID inFileTypeHint, AudioFileID   *outAudioFile){
	NSLog(@"AudioFileOpenWithCallbacks");
	return %orig;
}
%hookf(OSStatus ,AudioFileOpenURL,CFURLRef inFileRef, AudioFilePermissions inPermissions, AudioFileTypeID inFileTypeHint, AudioFileID   *outAudioFile){
	NSLog(@"AudioFileOpenURL");
	return %orig;
}
%end//test

%ctor{
	if([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]){
		%init(SB);
		NSLog(@"SB");
	}
	if(!is_enabled_app()) return;
	// if(!loadPref()) return;
	NSLog(@"ctor: VolumeMixer");

	%init(hook);
#if DEBUG
	%init(test);
	NSLog(@"test");
#endif
	int token = 0;
	notify_register_dispatch("com.brend0n.volumemixer/volumePressed", &token, dispatch_get_main_queue(), ^(int token) {
		[hudWindow volumeChanged:nil];
	});
	int token2 = 0;
	notify_register_dispatch("com.brend0n.volumemixer/volumePressed", &token2, dispatch_get_main_queue(), ^(int token) {
		NSLog(@"testttt");
	});
}

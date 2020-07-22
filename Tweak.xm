#import <notify.h>
#import <substrate.h>

#import <cmath>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenAL/OpenAL.h>

#import "VMHUDView.h"
#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"
#import "VMIPCCenter.h"


%config(generator=MobileSubstrate)

BOOL enabled;
UInt32 mFormatID=0;
VMHUDWindow*hudWindow;
AudioQueueRef lstAudioQueue;
AVPlayer* lstAVPlayer;
AVAudioPlayer* lstAVAudioPlayer;

BOOL loadPref(){
	NSLog(@"loadPref..........");
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.brend0n.volumemixer.plist"];
	if(!prefs) enabled=YES;
	else enabled=[prefs[@"enabled"] boolValue];
	return enabled;
}
BOOL is_enabled_app(){
	NSString* bundleIdentifier=[[NSBundle mainBundle] bundleIdentifier];
	if([bundleIdentifier isEqualToString:@"com.apple.springboard"])return YES;
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

    double vol=in_vol;

    tmp = (*in_buf)*vol; // 上面所有关于vol的判断，其实都是为了此处*in_buf乘以一个倍数，你可以根据自己的需要去修改

    // 下面的code主要是为了溢出判断
    double maxValue=pow(2.,sizeof(T)*8.0-1.0)-1.0;
    double minValue=pow(2.,sizeof(T)*8.0-1.0)*-1.0;
    tmp=MIN(tmp,maxValue);
    tmp=MAX(tmp,minValue);
    
    *out_buf = tmp;

    return 0;
}

VMHUDView* hudview;
float g_curScale=1;
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
	// if(!hudview) return ret;
	CGFloat curScale=g_curScale;
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

}
void showHUDWindowSB(){
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
		        VMHUDRootViewController*rootViewController=[VMHUDRootViewController new];
		        [rootViewController configure];
		        [hudWindow setRootViewController:rootViewController];
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
#pragma mark hook
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

	if(inParamID==kAudioQueueParam_Volume){
		return %orig(inAQ,inParamID,g_curScale);
	}
	

	return %orig(inAQ,inParamID,inValue);
}
%end


#pragma mark SIM
%group SBSIM
%hook UIStatusBarWindow

- (instancetype)initWithFrame:(CGRect)frame {
	NSLog(@"UIStatusBarWindow hooked...");
    id ret = %orig;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(vm_tap:)];
    [ret addGestureRecognizer:tap];


    return ret;
}
%new
- (void)vm_tap:(UITapGestureRecognizer *)sender {
	if (sender.state == UIGestureRecognizerStateEnded){
		NSLog(@"tap");
		// if([hudWindow isHidden]) [hudWindow showWindow];
		// else [hudWindow hideWindow];
		[hudWindow isHidden]?[hudWindow showWindow]:[hudWindow hideWindow];
	}
}
%end

@interface SBMainDisplaySceneLayoutStatusBarView:UIView
@end
%hook SBMainDisplaySceneLayoutStatusBarView
- (void)_addStatusBarIfNeeded {
	%orig;
	NSLog(@"SBMainDisplaySceneLayoutStatusBarView hooked...");
	UIView *statusBar = [self valueForKey:@"_statusBar"];

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(vm_tap:)];
	tap.numberOfTapsRequired=2;
    [statusBar addGestureRecognizer:tap];
}
%new
- (void)vm_tap:(UITapGestureRecognizer *)sender {

	if (sender.state == UIGestureRecognizerStateEnded){
		NSLog(@"inapp tap");
		[hudWindow isHidden]?[hudWindow showWindow]:[hudWindow hideWindow];
	}

}
%end
%end//SBSIM

#pragma mark SB
%group SB

%hook SpringBoard
-(void) applicationDidFinishLaunching:(id)application{
	%orig;
	NSLog(@"applicationDidFinishLaunching");
	// [QQLyricMessagingCenter sharedInstance];

	showHUDWindowSB();
    
}
%end
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




#pragma mark test
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
#pragma mark AVAudioPlayer
%hook AVAudioPlayer
+(instancetype)alloc{
	NSLog(@"AVAudioPlayer alloc");
	return %orig;
}
-(void)play{
	NSLog(@"AVAudioPlayer play %@",self);
	lstAVAudioPlayer=self;
	%orig;
	[self setVolume:g_curScale];
}
-(void)setVolume:(float)volume{
	NSLog(@"AVAudioPlayer setVolume: %f",volume);
	return %orig(g_curScale);
}
%end
#pragma mark AVPlayer
%hook AVPlayer
+(instancetype)alloc{
	NSLog(@"AVPlayer alloc");
	return %orig;
}
-(void)play{
	NSLog(@"AVPlayer play %@",self);
	lstAVPlayer=self;
	%orig;
	[self setVolume:g_curScale];
}
-(void)setVolume:(float)volume{
	NSLog(@"AVPlayer setVolume: %f",volume);
	return %orig(g_curScale);
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
#pragma mark MTMaterialView
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
%end//test
void registerApp(){
	//send bundleid
	NSString*bundleID=[[NSBundle mainBundle] bundleIdentifier];
	NSData*bundleIDData=[NSKeyedArchiver archivedDataWithRootObject:bundleID];
	[[UIPasteboard generalPasteboard] setValue:bundleIDData forPasteboardType:@"com.brend0n.volumemixer/bundleID"];
	notify_post("com.brend0n.qqmusicdesktoplyrics/register");

	// int token = 0;
	// notify_register_dispatch("com.brend0n.volumemixer/volumePressed", &token, dispatch_get_main_queue(), ^(int token) {
	// 	[hudWindow volumeChanged:nil];
	// });



	//receive volume
	NSString*appNotify=[NSString stringWithFormat:@"com.brend0n.volumemixer/%@/setVolume",bundleID];
	NSLog(@"registerd: %@",appNotify);
	// int token3 = 0;
	// notify_register_dispatch([appNotify UTF8String], &token3, dispatch_get_main_queue(), ^(int token) {
	// 	// NSLog(@"setVolume");
	// 	NSData*scaleData=[[UIPasteboard generalPasteboard] dataForPasteboardType:@"com.brend0n.volumemixer"];
		
	// 	if(scaleData){
	// 		NSNumber*scaleNumber= [NSKeyedUnarchiver unarchiveObjectWithData:scaleData];
	// 		// NSLog(@"%@",scaleNumber);

	// 		g_curScale=[scaleNumber doubleValue];

	// 		if(lstAudioQueue) AudioQueueSetParameter(lstAudioQueue,kAudioQueueParam_Volume,g_curScale);
 //        	[lstAVPlayer setVolume:g_curScale];
 //        	[lstAVAudioPlayer setVolume:g_curScale];
	// 	}
	// });
	VMIPCCenter*center=[[VMIPCCenter alloc] initWithName:appNotify];
	[center setVolumeChangedCallBlock:^(double curScale){
		g_curScale=curScale;

		if(lstAudioQueue) AudioQueueSetParameter(lstAudioQueue,kAudioQueueParam_Volume,g_curScale);
    	[lstAVPlayer setVolume:g_curScale];
    	[lstAVAudioPlayer setVolume:g_curScale];
	}];
}
#pragma mark ctor
%ctor{
	if(!is_enabled_app()) return;
	NSLog(@"ctor: VolumeMixer");

	if([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]){
		%init(SB);

#if TARGET_OS_SIMULATOR
		%init(SBSIM);	
#endif
	}	
	else {
		%init(hook);
		registerApp();
	}

#if DEBUG
	%init(test);
#endif

}

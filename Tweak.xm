#import <notify.h>
#import <substrate.h>
#import <MRYIPCCenter/MRYIPCCenter.h>

#import <cmath>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenAL/OpenAL.h>
#import <WebKit/WebKit.h>

#import "VMHUDView.h"
#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"
#import "VMIPCCenter.h"
#import "VMHookInfo.h"
#import "VMHookAudioUnit.hpp"

%config(generator=MobileSubstrate)

BOOL enabled;

VMHUDWindow*hudWindow;
VMHUDView* hudview;
double g_curScale=1;
AudioQueueRef lstAudioQueue;
AVPlayer* lstAVPlayer;
AVAudioPlayer* lstAVAudioPlayer;

NSMutableDictionary<NSString*,VMHookInfo*> *hookInfos;

void setScale(double curScale);
void registerApp();
void initScale();

BOOL webEnabled(){
	// NSLog(@"loadPref..........");
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
	if(!prefs) prefs=[NSMutableDictionary new];
	return prefs[@"webEnabled"]?[prefs[@"webEnabled"] boolValue]:YES;
}
BOOL is_enabled_app(){
	NSString* bundleIdentifier=[[NSBundle mainBundle] bundleIdentifier];
	if(unlikely([bundleIdentifier isEqualToString:kSpringBoardBundleId]))return YES;
	if(unlikely([bundleIdentifier isEqualToString:kWebKitBundleId])&&webEnabled())return YES;

	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
	NSArray *apps=prefs?prefs[@"apps"]:nil;
	if(!apps) return NO;
	if([apps containsObject:bundleIdentifier]) return YES;

	return NO;
}

#pragma mark BB
unsigned hudWindowContextId=0;
BOOL isWindowShowing;
%group BBHook
%hook CAWindowServerDisplay
-(unsigned)contextIdAtPosition:(CGPoint)arg1 excludingContextIds:(id)arg2  { 
	// NSLog(@"contextIdAtPosition:(CGPoint){%g, %g} excludingContextIds:(id)%@  start",arg1.x,arg1.y,arg2);
	unsigned r=%orig;
	if(unlikely(isWindowShowing&&hudWindowContextId)) {
		return hudWindowContextId;
	}
	// NSLog(@" = %u", r); 
	return r; 
}
%end
void BBLoadPref(){
	NSLog(@"loadPref...");
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
	hudWindowContextId=prefs?[prefs[@"hudWindowContextId"] unsignedIntValue]:0;
	NSLog(@"%u",hudWindowContextId);
}

@interface VMBBTimer:NSObject
@end
@implementation VMBBTimer
-(instancetype)init{
	self=[super init];
	if(!self)return self;
	int token=0;
	notify_register_dispatch("com.brend0n.volumemixer/windowDidShow", &token, dispatch_get_main_queue(), ^(int token) {
		[self windowDidShow];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(windowDidHide) object:nil];
    	[self performSelector:@selector(windowDidHide) withObject:nil afterDelay:5];
	});
	notify_register_dispatch("com.brend0n.volumemixer/windowDidHide", &token, dispatch_get_main_queue(), ^(int token) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(windowDidHide) object:nil];
	    [self windowDidHide];
	});
	return self;
}
-(void)windowDidShow{
	isWindowShowing=1;
}
-(void)windowDidHide{
	isWindowShowing=0;
}
@end
%end
#pragma mark hook
%group hook
%hookf(OSStatus, AudioUnitSetProperty, AudioUnit inUnit, AudioUnitPropertyID inID, AudioUnitScope inScope, AudioUnitElement inElement, const void *inData, UInt32 inDataSize){
	if([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kWebKitBundleId]) registerApp();
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
	//assume one thread
	NSString*unitKey=[NSString stringWithFormat:@"%ld",(long)inUnit];
	VMHookInfo*info=hookInfos[unitKey];
	if(!info)info=[VMHookInfo new];
	if(inID==kAudioUnitProperty_SetRenderCallback){//23
		NSLog(@"kAudioUnitProperty_SetRenderCallback: %ld",(long)inUnit);	
		NSLog(@"	AudioUnitScope:%u",inScope);
		// if(inScope&kAudioUnitScope_Input){
			void *outputCallback=(void*)*(long*)inData;
			NSLog(@"	outputCallback:%p",outputCallback);
			// hookIfReady();
		// }
		AURenderCallbackStruct *callbackSt=(AURenderCallbackStruct*)inData;
		void* inRefCon=callbackSt->inputProcRefCon;
		if(!inRefCon) inRefCon=(void*)-1;
		NSLog(@"	context: %p",inRefCon);

		
		[info setOutputCallback:outputCallback];
		[info setInRefCon:inRefCon];
		[info hookIfReady];
	}
	else if(inID==kAudioUnitProperty_StreamFormat){//8
		NSLog(@"kAudioUnitProperty_StreamFormat: %ld",(long)inUnit);
		NSLog(@"	AudioUnitScope:%u",inScope);
	    // if(inScope&kAudioUnitScope_Input){
			//to do: other format
	    	UInt32 mFormatID=((AudioStreamBasicDescription*)inData)->mFormatID;
			// NSLog(@"FormatID: %u",mFormatID);
			if(mFormatID!=kAudioFormatLinearPCM) {
				NSLog(@"not pcm");
				return ret;
			}
			UInt32 mFormatFlags=((AudioStreamBasicDescription*)inData)->mFormatFlags;	
			NSLog(@"	mFormatFlags: %u",mFormatFlags);
		// }
		[info setMFormatFlags:mFormatFlags];
		[info hookIfReady];

	}	
	[hookInfos setObject:info forKey:unitKey];
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
	if([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kWebKitBundleId]) registerApp();
	lstAudioQueue=inAQ;
	// NSLog(@"%p %u %lf",(void*)inAQ,inParamID,inValue);

	if(inParamID==kAudioQueueParam_Volume){
		return %orig(inAQ,inParamID,g_curScale);
	}
	

	return %orig(inAQ,inParamID,inValue);
}
%hookf(OSStatus, AudioQueuePrime,AudioQueueRef inAQ, UInt32 inNumberOfFramesToPrepare, UInt32 *outNumberOfFramesPrepared){
	lstAudioQueue=inAQ;
	AudioQueueSetParameter(lstAudioQueue,kAudioQueueParam_Volume,g_curScale);
	return %orig;
}
%hookf(OSStatus, AudioQueueStart,AudioQueueRef inAQ, const AudioTimeStamp *inStartTime){
	lstAudioQueue=inAQ;
	AudioQueueSetParameter(lstAudioQueue,kAudioQueueParam_Volume,g_curScale);
	return %orig;
}
%hookf(void,AudioServicesPlaySystemSound,SystemSoundID inSystemSoundID){
	NSLog(@"AudioServicesPlaySystemSound");
	if(!g_curScale) return;
	return %orig;
}

void sendPid(){
	int pid=[[NSProcessInfo processInfo] processIdentifier];
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if(!prefs) prefs=[NSMutableDictionary new];
    prefs[@"nowPlayingWebKitpid"]=[NSNumber numberWithInt:pid];
    [prefs writeToFile:kPrefPath atomically:YES];
	notify_post("com.brend0n.volumemixer/nowPlayingWebKitDidChange");
}
#pragma mark AVAudioPlayer
%hook AVAudioPlayer
+(instancetype)alloc{
	id ret=%orig;
	lstAVAudioPlayer=ret;
	NSLog(@"AVAudioPlayer alloc %@",ret);
	if([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kWebKitBundleId]) registerApp();
	return ret;
}
-(void)play{
	NSLog(@"AVAudioPlayer play %@",self);
	lstAVAudioPlayer=self;
	if(unlikely([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kWebKitBundleId])) sendPid();
	[self setVolume:g_curScale];
	%orig;
}
-(void)setRate:(float)rate{
	NSLog(@"AVAudioPlayer setRate:%f",rate);
	lstAVAudioPlayer=self;
	if(unlikely([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kWebKitBundleId])) sendPid();
	[self setVolume:g_curScale];
	%orig;
}
-(void)setVolume:(float)volume{
	NSLog(@"AVAudioPlayer setVolume: %f",volume);
	return %orig(g_curScale);
}
%end

#pragma mark AVPlayer
%hook AVPlayer
+(instancetype)alloc{
	id ret=%orig;
	lstAVPlayer=ret;
	NSLog(@"AVPlayer alloc %@",ret);
	if([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kWebKitBundleId]) registerApp();
	return ret;
}
-(void)play{
	NSLog(@"AVPlayer play %@",self);
	lstAVPlayer=self;
	if(unlikely([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kWebKitBundleId])) sendPid();
	[self setVolume:g_curScale];
	%orig;
}
-(void)setRate:(float)rate{
	NSLog(@"AVPlayer setRate:%f",rate);
	if(rate){
		lstAVPlayer=self;
		if(unlikely([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kWebKitBundleId])) sendPid();
	}
	[self setVolume:g_curScale];
	%orig;
}
-(void)setVolume:(float)volume{
	NSLog(@"AVPlayer setVolume: %f",volume);
	return %orig(g_curScale);
}
%end

#pragma mark AVAudioSession
%hook AVAudioSession
- (BOOL)setActive:(BOOL)active withOptions:(AVAudioSessionSetActiveOptions)options error:(NSError **)outError{
  NSString* bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier]; 
  if([bundleIdentifier isEqualToString:@"com.netease.cloudmusic"]||[bundleIdentifier isEqualToString:@"com.tencent.QQMusic"]){
    [self setCategory:AVAudioSessionCategoryPlayback withOptions:0 error:outError];
  }else{
    [self setCategory:[self category] withOptions:AVAudioSessionCategoryOptionDuckOthers error:outError];
  }
  
  return %orig;
}
%end

%end //hook

#if TARGET_OS_SIMULATOR
#pragma mark SIM
%group SIM
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
		[hudWindow changeVisibility];
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
		[hudWindow changeVisibility];
	}

}
%end
%end//SIM
#endif

#pragma mark SB
@interface UIWindow()
-(unsigned)_contextId;
@end
void showHUDWindowSB(){
	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
    	void(^blockForMain)(void) = ^{
				CGRect bounds=[UIScreen mainScreen].bounds;

		        hudWindow =[[VMHUDWindow alloc] initWithFrame:bounds];
		        VMHUDRootViewController*rootViewController=[VMHUDRootViewController new];
		        [hudWindow setRootViewController:rootViewController];
		        unsigned contextId=[hudWindow _contextId];
		        NSLog(@"%u",contextId);

			    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
			    if(!prefs) prefs=[NSMutableDictionary new];
			    prefs[@"hudWindowContextId"]=[NSNumber numberWithUnsignedInt:contextId];
			    [prefs writeToFile:kPrefPath atomically:YES];
			    notify_post("com.brend0n.volumemixer/loadPref");
			};
		if ([NSThread isMainThread]) blockForMain();
		else dispatch_async(dispatch_get_main_queue(), blockForMain);
    	
    });
}
%group SB
%hook SpringBoard
-(void) applicationDidFinishLaunching:(id)application{
	%orig;
	NSLog(@"applicationDidFinishLaunching");
	showHUDWindowSB();    
}
%end

%hook SBVolumeControl
- (void)increaseVolume {
	%orig;
    [hudWindow changeVisibility];
}

- (void)decreaseVolume {
	%orig;
    [hudWindow changeVisibility];
}
%end

%end //SB


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
// to do: wechat?
// AudioFile_ReadProc orig_inReadFunc;
// static OSStatus my_inReadFunc(
// 								void *		inClientData,
// 								SInt64		inPosition, 
// 								UInt32		requestCount,
// 								void *		buffer, 
// 								UInt32 *	actualCount){
// 	NSLog(@"AudioFile test");
// 	return orig_inReadFunc(inClientData,inPosition,requestCount,buffer,actualCount);
// }

// %hookf(OSStatus, AudioFileOpenWithCallbacks,void *inClientData, AudioFile_ReadProc inReadFunc, AudioFile_WriteProc inWriteFunc, AudioFile_GetSizeProc inGetSizeFunc, AudioFile_SetSizeProc inSetSizeFunc, AudioFileTypeID inFileTypeHint, AudioFileID   *outAudioFile){
// 	NSLog(@"AudioFileOpenWithCallbacks");
// 	// MSHookFunction((void *)inReadFunc, (void *)my_inReadFunc, (void **)&orig_inReadFunc);
// 	return %orig;
// }

%hookf(OSStatus ,AudioFileOpenURL,CFURLRef inFileRef, AudioFilePermissions inPermissions, AudioFileTypeID inFileTypeHint, AudioFileID   *outAudioFile){
	NSLog(@"AudioFileOpenURL");
	return %orig;
}
%hookf(OSStatus, AudioFileStreamOpen, void *inClientData, AudioFileStream_PropertyListenerProc inPropertyListenerProc, AudioFileStream_PacketsProc inPacketsProc, AudioFileTypeID inFileTypeHint, AudioFileStreamID  _Nullable *outAudioFileStream){
	NSLog(@"AudioFileStreamOpen");
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

void initScale(){
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if(!prefs)prefs=[NSMutableDictionary new];
    NSNumber *scaleNumber=prefs[[[NSBundle mainBundle] bundleIdentifier]];
    if(scaleNumber){
    	g_curScale=[scaleNumber doubleValue];
    	auCurScale=g_curScale;
    }
}
void setScale(double curScale){
	g_curScale=curScale;
	auCurScale=g_curScale;

	if(lstAudioQueue) AudioQueueSetParameter(lstAudioQueue,kAudioQueueParam_Volume,g_curScale);
	[lstAVAudioPlayer setVolume:g_curScale]; 
	[lstAVPlayer setVolume:g_curScale];
    
}
void registerApp(){
	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
    	//send bundleid
		NSString*bundleID=[[NSBundle mainBundle] bundleIdentifier];
		MRYIPCCenter *IDCenter=[MRYIPCCenter centerNamed:@"com.brend0n.volumemixer/register"];

		int pid=[[NSProcessInfo processInfo] processIdentifier];
		[IDCenter callExternalMethod:@selector(register:)withArguments:@{@"bundleID" : bundleID,@"pid":[NSNumber numberWithInt:pid]} completion:^(id ret){}];
			

		NSString*appNotify=[NSString stringWithFormat:@"com.brend0n.volumemixer/%@~%d/setVolume",bundleID,pid];
		//receive volume
		VMIPCCenter*center=[[VMIPCCenter alloc] initWithName:appNotify];
		[center setVolumeChangedCallBlock:^(double curScale){
			setScale(curScale);
		}];
    });
	
}


#pragma mark ctor
%ctor{
	if([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.backboardd"]){
		%init(BBHook);
		int token=0;
		notify_register_dispatch("com.brend0n.volumemixer/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
			BBLoadPref();
		});
		
		(void)[VMBBTimer new];
		return;
	}

	if(!is_enabled_app()) return;
	NSLog(@"ctor: VolumeMixer");

	if([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kSpringBoardBundleId]){
		%init(SB);
		int token=0;
		notify_register_dispatch("com.brend0n.volumemixer/hideWindow", &token, dispatch_get_main_queue(), ^(int token) {
			[hudWindow hideWindow];
			NSLog(@"com.brend0n.volumemixer/hideWindow");
		});
		notify_register_dispatch("com.apple.springboard.lockstate", &token, dispatch_get_main_queue(), ^(int token) {
			[hudWindow hideWindow];
			NSLog(@"locked");
		});
		
#if TARGET_OS_SIMULATOR
		%init(SIM);	
#endif
	}	
	else {
		%init(hook);
		if(![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kWebKitBundleId]) registerApp();
		initScale();
		origCallbacks=[NSMutableDictionary new];
		hookInfos=[NSMutableDictionary new];
		hookedCallbacks=[NSMutableDictionary new];
		
	}

#if DEBUG
	%init(test);
#endif

}

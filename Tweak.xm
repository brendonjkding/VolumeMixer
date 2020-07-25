#import <notify.h>
#import <substrate.h>

#import <cmath>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenAL/OpenAL.h>
#import <WebKit/WebKit.h>

#import "VMHUDView.h"
#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"
#import "VMIPCCenter.h"
#import "VMHookInfo.h"


%config(generator=MobileSubstrate)

BOOL enabled;

VMHUDWindow*hudWindow;
VMHUDView* hudview;
float g_curScale=1;
AudioQueueRef lstAudioQueue;
AVPlayer* lstAVPlayer;
AVAudioPlayer* lstAVAudioPlayer;

NSMutableDictionary<NSString*,NSNumber*> *origCallbacks;
NSMutableDictionary<NSString*,VMHookInfo*> *hookInfos;
NSMutableDictionary<NSString*,NSNumber*> *hookedCallbacks;

void setScale(double curScale);

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

    tmp = (*in_buf)*vol; 

    // 下面的code主要是为了溢出判断
    double maxValue=pow(2.,sizeof(T)*8.0-1.0)-1.0;
    double minValue=pow(2.,sizeof(T)*8.0-1.0)*-1.0;
    tmp=MIN(tmp,maxValue);
    tmp=MAX(tmp,minValue);
    
    *out_buf = tmp;

    return 0;
}


typedef OSStatus(*orig_t)(void*,AudioUnitRenderActionFlags*,const AudioTimeStamp*,UInt32,UInt32,AudioBufferList*);
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
	void*inRefConKey=inRefCon;
	if(!inRefConKey) inRefConKey=(void*)-1;
	orig_t orig=(orig_t) [origCallbacks[[NSString stringWithFormat:@"%ld",(long)inRefConKey]] longValue];
	ret= orig(inRefCon,ioActionFlags,inTimeStamp,inBusNumber,inNumberFrames,ioData);


	if(unlikely(*ioActionFlags==kAudioUnitRenderAction_OutputIsSilence)){
		return ret;
	}

	CGFloat curScale=g_curScale;
	for (UInt32 i = 0; i < ioData -> mNumberBuffers; i++){
		auto *buf = (unsigned char*)ioData->mBuffers[i].mData;

		uint bytes = ioData->mBuffers[i].mDataByteSize;
		

	    for(UInt32 j=0;j<bytes;j+=sizeof(T)){
	        volume_adjust((T*)(buf+j), (T*)(buf+j), curScale);
	    }
	}
	
    
	return ret;
}


@interface UIWindow()
-(unsigned)_contextId;
@end
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
		        [hudWindow setRootViewController:rootViewController];
		        unsigned contextId=[hudWindow _contextId];
		        NSLog(@"%u",contextId);

			    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:prefPath];
			    if(!prefs) prefs=[NSMutableDictionary new];
			    prefs[@"hudWindowContextId"]=[NSNumber numberWithUnsignedInt:contextId];
			    [prefs writeToFile:prefPath atomically:YES];
			    notify_post("com.brend0n.volumemixer/loadPref");
			};
		if ([NSThread isMainThread]) blockForMain();
		else dispatch_async(dispatch_get_main_queue(), blockForMain);
    	
    });
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
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:prefPath];
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
	// NSLog(@"windowDidShow");
}
-(void)windowDidHide{
	isWindowShowing=0;
}
@end
%end
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
	lstAudioQueue=inAQ;
	// NSLog(@"%p %u %lf",(void*)inAQ,inParamID,inValue);

	if(inParamID==kAudioQueueParam_Volume){
		return %orig(inAQ,inParamID,g_curScale);
	}
	

	return %orig(inAQ,inParamID,inValue);
}

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
	id ret=%orig;
	lstAVPlayer=ret;
	NSLog(@"AVPlayer alloc %@",ret);
	return ret;
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
%end//SBSIM
#endif

#pragma mark SB
%group SB

%hook SpringBoard
-(void) applicationDidFinishLaunching:(id)application{
	%orig;
	NSLog(@"applicationDidFinishLaunching");
	showHUDWindowSB();

    
}
%end
%hook  SBVolumeHardwareButton
- (void)volumeDecreasePress:(id)arg1{
	%orig;
	// NSLog(@"volumeDecreasePress: %@",arg1);
	notify_post("com.brend0n.volumemixer/volumePressed");
}
- (void)volumeIncreasePress:(id)arg1{
	%orig;
	// NSLog(@"volumeIncreasePress: %@",arg1);
	notify_post("com.brend0n.volumemixer/volumePressed");
}
%end

%hook SpringBoard

- (void)_ringerChanged:(id)arg1{
	// NSLog(@"_ringerChanged: %@",arg1);
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
// ExceptionOr<void> HTMLMediaElement::setVolume(double volume)
// https://github.com/WebKit/webkit/blob/950143da027e80924b4bb86defa8a3f21fd3fb1e/Source/WebCore/html/HTMLMediaElement.cpp#L3608
// https://github.com/WebKit/webkit/tree/950143da027e80924b4bb86defa8a3f21fd3fb1e/Source/WebCore/html

// void MediaPlayer::setVolume(double volume)
// https://github.com/WebKit/webkit/blob/950143da027e80924b4bb86defa8a3f21fd3fb1e/Source/WebCore/platform/graphics/MediaPlayer.cpp#L838
// https://github.com/WebKit/webkit/blob/950143da027e80924b4bb86defa8a3f21fd3fb1e/Source/WebCore/platform/graphics/MediaPlayer.h
// https://github.com/WebKit/webkit/blob/950143da027e80924b4bb86defa8a3f21fd3fb1e/Source/WebCore/platform/graphics/MediaPlayerPrivate.h#L130
// https://github.com/WebKit/webkit/tree/950143da027e80924b4bb86defa8a3f21fd3fb1e/Source/WebCore/platform/graphics
// long (*orig__ZN7WebCore16HTMLMediaElement9setVolumeEd)(long,double);
// long my__ZN7WebCore16HTMLMediaElement9setVolumeEd(long arg1,double arg2){
// 	NSLog(@"__ZN7WebCore16HTMLMediaElement9setVolumeEd");
// 	return orig__ZN7WebCore16HTMLMediaElement9setVolumeEd(arg1,arg2);
// }
%hook MPAVController
-(void)play{
	%orig;
	NSLog(@"play");
	setScale(g_curScale);
}
%end
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
AudioFile_ReadProc orig_inReadFunc;
static OSStatus my_inReadFunc(
								void *		inClientData,
								SInt64		inPosition, 
								UInt32		requestCount,
								void *		buffer, 
								UInt32 *	actualCount){
	NSLog(@"AudioFile test");
	return orig_inReadFunc(inClientData,inPosition,requestCount,buffer,actualCount);
}

%hookf(OSStatus, AudioFileOpenWithCallbacks,void *inClientData, AudioFile_ReadProc inReadFunc, AudioFile_WriteProc inWriteFunc, AudioFile_GetSizeProc inGetSizeFunc, AudioFile_SetSizeProc inSetSizeFunc, AudioFileTypeID inFileTypeHint, AudioFileID   *outAudioFile){
	NSLog(@"AudioFileOpenWithCallbacks");
	// MSHookFunction((void *)inReadFunc, (void *)my_inReadFunc, (void **)&orig_inReadFunc);
	return %orig;
}

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
#pragma mark web
NSMutableArray<WKWebView*>*webViews;
// %hook WKWebView
// +(instancetype)alloc{
// 	id ret=%orig;
// 	NSLog(@"WKWebView");
// 	[webViews addObject:ret];
// 	return ret;
// }
// %end

%end//test
void setScale(double curScale){
	g_curScale=curScale;

	if(lstAudioQueue) AudioQueueSetParameter(lstAudioQueue,kAudioQueueParam_Volume,g_curScale);
	[lstAVAudioPlayer setVolume:g_curScale]; 
	[lstAVPlayer setVolume:g_curScale];

	//credits to https://stackoverflow.com/questions/15569983/avplayer-volume-control
	AVPlayerItem*mPlayerItem=[lstAVPlayer currentItem];
	// NSLog(@"item: %@",mPlayerItem);
	NSArray *audioTracks = mPlayerItem.asset.tracks;

	// Change Volume of all the audio tracks
	NSMutableArray *allAudioParams = [NSMutableArray array];
	for (AVAssetTrack *track in audioTracks) {
		AVMutableAudioMixInputParameters *audioInputParams =[AVMutableAudioMixInputParameters audioMixInputParameters];
		[audioInputParams setVolume:g_curScale atTime:kCMTimeZero];
		[audioInputParams setTrackID:[track trackID]];
		[allAudioParams addObject:audioInputParams];
	}
	AVMutableAudioMix *audioZeroMix = [AVMutableAudioMix audioMix];
	[audioZeroMix setInputParameters:allAudioParams];

	[mPlayerItem setAudioMix:audioZeroMix]; // Change Volume of the player item

    
	//failed
	for(WKWebView*webView in webViews){
		[webView evaluateJavaScript:
    			[NSString stringWithFormat:@""
	    			"var videos=document.getElementsByTagName('video');"
					"for(var i = 0; i < videos.length; i++) {"
					"	var video=videos[i];"
					"	video.volume=%lf;"
					// "	alert(video.volume);"
					// "	video.pause();"
					"}"
					, g_curScale
				]
			 completionHandler: ^(id _Nullable obj, NSError * _Nullable error){
			 	// NSLog(@"%@",error);
			 }];
	}
}
void registerApp(){
	//todo: use rocketbootstrap or mryipc
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
	VMIPCCenter*center=[[VMIPCCenter alloc] initWithName:appNotify];
	[center setVolumeChangedCallBlock:^(double curScale){
		setScale(curScale);
	}];
}
void initTemplate(){
	my_outputCallback<short>;
	my_outputCallback<float>;
}
#pragma mark ctor
%ctor{

	// void*ad=((void *)MSFindSymbol(NULL, "__ZN7WebCore16HTMLMediaElement9setVolumeEd"));
	// NSLog(@"ad:%p",ad);
	// MSHookFunction(ad, (void *)my__ZN7WebCore16HTMLMediaElement9setVolumeEd, (void **)&orig__ZN7WebCore16HTMLMediaElement9setVolumeEd);
		      	
	if([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.backboardd"]){
		%init(BBHook);
		int token=0;
		notify_register_dispatch("com.brend0n.volumemixer/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
			BBLoadPref();
		});
		
		[[VMBBTimer alloc] init];
		return;
	}

	if(!is_enabled_app()) return;
	NSLog(@"ctor: VolumeMixer");

	if([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]){
		%init(SB);
		int token=0;
		notify_register_dispatch("com.brend0n.volumemixer/hideWindow", &token, dispatch_get_main_queue(), ^(int token) {
			[hudWindow hideWindow];
			NSLog(@"com.brend0n.volumemixer/hideWindow");
		});
		
#if TARGET_OS_SIMULATOR
		%init(SIM);	
#endif
	}	
	else {
		%init(hook);
		registerApp();
		origCallbacks=[NSMutableDictionary new];
		hookInfos=[NSMutableDictionary new];
		webViews=[NSMutableArray new];
		hookedCallbacks=[NSMutableDictionary new];
	}

#if DEBUG
	%init(test);
	
	
	
#endif

}

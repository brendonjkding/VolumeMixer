#import <notify.h>
#import <MRYIPCCenter/MRYIPCCenter.h>

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#import "VMHUDWindow.h"
#import "VMHUDRootViewController.h"
#import "VMHookInfo.h"
#import "VMHookAudioUnit.hpp"

static BOOL byVolumeButton;
static BOOL webAudioUnitHookEnabled;

VMHUDWindow*hudWindow;
static VMHUDRootViewController*rootViewController;
static double g_curScale=1;
static AudioQueueRef lstAudioQueue;
static AVPlayer* lstAVPlayer;
static AVAudioPlayer* lstAVAudioPlayer;

static NSMutableDictionary<NSString*,VMHookInfo*> *hookInfos;

static void setScale(double curScale);
static void registerApp();
static void initScale();

static void loadPref(){
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
	if(!prefs) prefs=[NSMutableDictionary new];
	byVolumeButton=prefs[@"byVolumeButton"]?[prefs[@"byVolumeButton"] boolValue]:NO;
	webAudioUnitHookEnabled=prefs[@"webAudioUnitHookEnabled"]?[prefs[@"webAudioUnitHookEnabled"] boolValue]:NO;

	[rootViewController loadPref];

	// 0.0.2 compatibility 
	if(prefs[@"webEnabled"]){
		if([prefs[@"webEnabled"] boolValue]){
			NSMutableArray*apps=[prefs[@"apps"] mutableCopy];
    		if(!apps) apps=[NSMutableArray new];
    		[apps addObject:kWebKitBundleId];
    		prefs[@"apps"]=apps;
		}

    	[prefs removeObjectForKey:@"webEnabled"];
    	[prefs writeToFile:kPrefPath atomically:YES];
	}
}

static BOOL isEnabledApp(){
	NSString* bundleIdentifier=[[NSBundle mainBundle] bundleIdentifier];
	if(unlikely([bundleIdentifier isEqualToString:kSpringBoardBundleId]))return YES;

	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
	NSArray *apps=prefs?prefs[@"apps"]:nil;
	if(!apps) return NO;
	if([apps containsObject:bundleIdentifier]) return YES;

	return NO;
}

#pragma mark appHook
%group appHook
%hookf(OSStatus, AudioUnitSetProperty, AudioUnit inUnit, AudioUnitPropertyID inID, AudioUnitScope inScope, AudioUnitElement inElement, const void *inData, UInt32 inDataSize){
	OSStatus ret=%orig;
	
	if([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kWebKitBundleId]) {
		if(!webAudioUnitHookEnabled) return ret;
		registerApp();
	}
	// method 1:
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
	NSString*unitKey=[NSString stringWithFormat:@"%p",inUnit];
	VMHookInfo*info=hookInfos[unitKey];
	if(!info)info=[VMHookInfo new];
	if(inID==kAudioUnitProperty_SetRenderCallback){//23
		NSLog(@"kAudioUnitProperty_SetRenderCallback: %p",inUnit);	
		NSLog(@"	AudioUnitScope:%u",(unsigned int)inScope);
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
		NSLog(@"kAudioUnitProperty_StreamFormat: %p",inUnit);
		NSLog(@"	AudioUnitScope:%u",(unsigned int)inScope);
	    // if(inScope&kAudioUnitScope_Input){
			//to do: other format
	    	UInt32 mFormatID=((AudioStreamBasicDescription*)inData)->mFormatID;
			// NSLog(@"FormatID: %u",mFormatID);
			if(mFormatID!=kAudioFormatLinearPCM) {
				NSLog(@"not pcm");
				return ret;
			}
			UInt32 mFormatFlags=((AudioStreamBasicDescription*)inData)->mFormatFlags;	
			NSLog(@"	mFormatFlags: %u",(unsigned int)mFormatFlags);
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
	NSLog(@"AudioQueueSetParameter: %p %u %lf",(void*)inAQ,(unsigned int)inParamID,inValue);

	if(inParamID==kAudioQueueParam_Volume&&inValue){
		return %orig(inAQ,inParamID,g_curScale);
	}
	

	return %orig(inAQ,inParamID,inValue);
}
%hookf(OSStatus, AudioQueuePrime,AudioQueueRef inAQ, UInt32 inNumberOfFramesToPrepare, UInt32 *outNumberOfFramesPrepared){
	NSLog(@"AudioQueuePrime: %p",(void*)inAQ);
	lstAudioQueue=inAQ;
	AudioQueueParameterValue outValue;
	AudioQueueGetParameter(lstAudioQueue,kAudioQueueParam_Volume,&outValue);
	if(outValue) AudioQueueSetParameter(lstAudioQueue,kAudioQueueParam_Volume,g_curScale);
	return %orig;
}
%hookf(OSStatus, AudioQueueStart,AudioQueueRef inAQ, const AudioTimeStamp *inStartTime){
	lstAudioQueue=inAQ;
	NSLog(@"AudioQueueStart: %p",(void*)inAQ);
	AudioQueueParameterValue outValue;
	AudioQueueGetParameter(lstAudioQueue,kAudioQueueParam_Volume,&outValue);
	if(outValue) AudioQueueSetParameter(lstAudioQueue,kAudioQueueParam_Volume,g_curScale);
	return %orig;
}
%hookf(void,AudioServicesPlaySystemSound,SystemSoundID inSystemSoundID){
	NSLog(@"AudioServicesPlaySystemSound");
	if(!g_curScale) return;
	return %orig;
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
	if([self volume]) [self setVolume:g_curScale];
	%orig;
}
-(void)setRate:(float)rate{
	NSLog(@"AVAudioPlayer setRate:%f",rate);
	lstAVAudioPlayer=self;
	if([self volume]) [self setVolume:g_curScale];
	%orig;
}
-(void)setVolume:(float)volume{
	NSLog(@"AVAudioPlayer setVolume: %f",volume);
	if(!volume) return %orig;
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
	if([self volume]) [self setVolume:g_curScale];
	%orig;
}
-(void)setRate:(float)rate{
	NSLog(@"AVPlayer setRate:%f",rate);
	if(rate){
		lstAVPlayer=self;
	}
	if([self volume]) [self setVolume:g_curScale];
	%orig;
}
-(void)setVolume:(float)volume{
	NSLog(@"AVPlayer setVolume: %f",volume);
	if(!volume) return %orig;
	return %orig(g_curScale);
}
%end

#pragma mark AVAudioSession
%hook AVAudioSession
- (BOOL)setActive:(BOOL)active withOptions:(AVAudioSessionSetActiveOptions)options error:(NSError **)outError{
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
	if(!prefs) prefs=[NSMutableDictionary new];
	BOOL audioMixEnabled=prefs[@"audioMixEnabled"]?[prefs[@"audioMixEnabled"] boolValue]:NO;
	if(!audioMixEnabled) return %orig;

  NSString *category=[self category];
  NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier]; 
  NSLog(@"mlyx AVAudio category %@, options %u",category,(unsigned int)options);

  //听歌识曲
  if([category isEqualToString:@"AVAudioSessionCategoryPlayAndRecord"]||[category isEqualToString:@"AVAudioSessionCategoryRecord"]){
    return %orig;
  }

  if([prefs[@"audiomixApps"] containsObject:bundleIdentifier]){
    //Choose Playback Mode App to Fix that[Recommend: Music App] 
    [self setCategory:AVAudioSessionCategoryPlayback withOptions:0 error:outError];
  }else{
  	//AudioMix Enabled App Will NOT Show Up in ControlCenter and LockScreen MediaPlayer
    [self setCategory:category withOptions:2 error:outError];
  }
  
  return %orig;
}
%end

%end //appHook

#pragma mark SBHook
static void showHUDWindowSB(){
	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
    	void(^blockForMain)(void) = ^{
				CGRect bounds=[UIScreen mainScreen].bounds;
		        hudWindow =[[VMHUDWindow alloc] initWithFrame:bounds];
		        rootViewController=[VMHUDRootViewController new];
		        [hudWindow setRootViewController:rootViewController];
		};
		if ([NSThread isMainThread]) blockForMain();
		else dispatch_async(dispatch_get_main_queue(), blockForMain);
    	
    });
}
%group SBHook
%hook SpringBoard
-(void) applicationDidFinishLaunching:(id)application{
	%orig;
	NSLog(@"applicationDidFinishLaunching");
	showHUDWindowSB();    
}
%end

%hook VolumeControlClass
- (void)increaseVolume {
	%orig;
	if(byVolumeButton) [hudWindow showWindow];
}

- (void)decreaseVolume {
	%orig;
    if(byVolumeButton) [hudWindow showWindow];
}
%end
%end //SBHook



static void initScale(){
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if(!prefs)prefs=[NSMutableDictionary new];
    NSNumber *scaleNumber=prefs[[[NSBundle mainBundle] bundleIdentifier]];
    if(scaleNumber){
    	g_curScale=[scaleNumber doubleValue];
    	auCurScale=g_curScale;
    }
}
static void setScale(double curScale){
	g_curScale=curScale;
	auCurScale=g_curScale;

	if(lstAudioQueue) AudioQueueSetParameter(lstAudioQueue,kAudioQueueParam_Volume,g_curScale);
	[lstAVAudioPlayer setVolume:g_curScale]; 
	[lstAVPlayer setVolume:g_curScale];
    
}
@interface VMAPPServer : NSObject
-(instancetype)initWithName:(NSString* )name;
@end
@implementation VMAPPServer{
	MRYIPCCenter* _center;
}
-(instancetype)initWithName:(NSString* )name
{
	if ((self = [super init]))
	{
		_center = [MRYIPCCenter centerNamed:name];
		[_center addTarget:self action:@selector(setVolume:)];
		NSLog(@"[MRYIPC] running server in %@", [NSProcessInfo processInfo].processName);
	}
	return self;
}
-(void)setVolume:(NSDictionary*)args{
	double curScale=[args[@"curScale"] doubleValue];
	setScale(curScale);
}

@end
static VMAPPServer *appServer;
void registerApp(){
	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
    	//send bundleid
		NSString*bundleID=[[NSBundle mainBundle] bundleIdentifier];
		MRYIPCCenter *idClient=[MRYIPCCenter centerNamed:@"com.brend0n.volumemixer/register"];

		int pid=[[NSProcessInfo processInfo] processIdentifier];
		[idClient callExternalMethod:@selector(register:)withArguments:@{@"bundleID" : bundleID,@"pid":[NSNumber numberWithInt:pid]} completion:^(id ret){}];

		NSString*appNotify=[NSString stringWithFormat:@"com.brend0n.volumemixer/%@~%d/setVolume",bundleID,pid];
		appServer=[[VMAPPServer alloc] initWithName:appNotify];
    });
}


#pragma mark ctor
%ctor{
	if(!isEnabledApp()) return;
	NSLog(@"ctor: VolumeMixer");

	if([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kSpringBoardBundleId]){
		%init(SBHook,VolumeControlClass=objc_getClass("SBVolumeControl")?:objc_getClass("VolumeControl"));
	}	
	else {
		%init(appHook);
		if(![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kWebKitBundleId]) registerApp();
		initScale();
		origCallbacks=[NSMutableDictionary new];
		hookInfos=[NSMutableDictionary new];
		hookedCallbacks=[NSMutableDictionary new];
		
	}
	loadPref();
	int token;
	notify_register_dispatch("com.brend0n.volumemixer/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
		loadPref();
	});

}

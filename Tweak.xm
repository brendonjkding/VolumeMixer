#import "VMHookInfo.h"
#import "VMHookAudioUnit.hpp"
#import "MRYIPC/MRYIPCCenter.h"

#import <notify.h>
#import <sys/mman.h>
#import <mach/mach.h>
#import <dlfcn.h>
#import <pthread.h>
#import <unordered_map>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

extern "C" kern_return_t mach_vm_protect(vm_map_t, mach_vm_address_t, mach_vm_size_t, boolean_t, vm_prot_t);

static NSUserDefaults *g_defaults = nil;

static BOOL webAudioUnitHookEnabled = NO;

static double g_curScale = 1;
static AudioQueueRef lstAudioQueue = NULL;
static AVPlayer *lstAVPlayer = nil;
static AVAudioPlayer *lstAVAudioPlayer = nil;
static id lstAVSampleBufferAudioRenderer = nil;

static NSMutableDictionary<NSString *, VMHookInfo *> *hookInfos = nil;

static void setScale(double curScale);
static void registerApp();
static void initScale();

static void loadPref(){
    webAudioUnitHookEnabled = [g_defaults objectForKey:kPrefWebAudioUnitHookEnabledKey] ? [g_defaults boolForKey:kPrefWebAudioUnitHookEnabledKey] : NO;
}

static BOOL isEnabledApp(){
    if(![NSProcessInfo.processInfo.arguments.firstObject containsString:@"/Application"]
        && ![NSBundle.mainBundle.bundleIdentifier isEqualToString:kWebKitBundleId]){
        return NO;
    }
    // Credit: Polyfills — com.apple.UIKit usage
    g_defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.apple.UIKit"];
    if([[g_defaults objectForKey:kPrefAppsKey] containsObject:NSBundle.mainBundle.bundleIdentifier]){
        return YES;
    }
    else if([g_defaults boolForKey:kPrefWebEnabledKey] && [NSBundle.mainBundle.bundleIdentifier isEqualToString:kWebKitBundleId]){
        return YES;
    }
    return NO;
}

%group app
#pragma mark AudioUnit

static void trampoline(){
    #if __aarch64__
    asm volatile (
        "1: .quad 0x1122334455667788\n"
        "2: .quad 0x1122334455667788\n"
        "ldr x16, 1b\n"
        "ldr x17, 2b\n"
        "br x17\n"
        "3: .quad 0x8877665544332211\n"
    );
    #elif __x86_64__
    asm volatile (
        "1: .quad 0x1122334455667788\n"
        "2: .quad 0x1122334455667788\n"
        "movq 1b(%rip), %rax\n"
        "jmp *2b(%rip)\n"
        "3: .quad 0x8877665544332211\n"
    );
    #endif
}

template<class T>
static T make_trampoline(T target, T orig){
    void *instance = mmap(NULL, PAGE_SIZE, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANON, -1, 0);
    uint64_t little_start = 0x1122334455667788;
    uint64_t little_end = 0x8877665544332211;
    void *start = memmem((void *)trampoline, PAGE_SIZE, &little_start, sizeof(little_start));
    void *end = memmem((void *)trampoline, PAGE_SIZE, &little_end, sizeof(little_end));
    memcpy(instance, start, (char *)end - (char *)start);

    uint64_t *p = (uint64_t *)instance;

    uint64_t *literal_orig = p++;
    uint64_t *literal_target = p++;
    uint32_t *code = (uint32_t *)p;

    *literal_orig = (uint64_t) orig;
    *literal_target = (uint64_t) target;

    mach_vm_protect(mach_task_self(), (mach_vm_address_t)instance, PAGE_SIZE, FALSE, VM_PROT_READ|VM_PROT_EXECUTE);

    return (T)code;
}

static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
static std::unordered_map<AURenderCallback, AURenderCallback> inputProc_maps[3];

static AURenderCallback my_inputProcs[] = {
    my_inputProc<short>, my_inputProc<float>, my_inputProc<uint8_t>
};
static NSString *type_strings[] = {
    @"short", @"float", @"uint8_t"
};

%hookf(OSStatus, AudioUnitSetProperty, AudioUnit inUnit, AudioUnitPropertyID inID, AudioUnitScope inScope, AudioUnitElement inElement, const void *inData, UInt32 inDataSize){
    OSStatus ret = %orig;

    if([NSBundle.mainBundle.bundleIdentifier isEqualToString:kWebKitBundleId]) {
        if(!webAudioUnitHookEnabled){
            return ret;
        }
        registerApp();
    }
    // inID
    /*
        kAudioUnitProperty_SetRenderCallback 23
        kAudioUnitProperty_StreamFormat      8
    */

    // inScope
    /*
        kAudioUnitScope_Global      = 0,
        kAudioUnitScope_Input       = 1,
        kAudioUnitScope_Output      = 2,
    */
    if(inScope!=kAudioUnitScope_Input && inScope!=kAudioUnitScope_Global){
        return ret;
    }

    NSString *unitKey = [NSString stringWithFormat:@"%p", inUnit];
    VMHookInfo *info = nil;
    @synchronized(hookInfos){
        info = hookInfos[unitKey] ?: [VMHookInfo new];
    }
    if(inID == kAudioUnitProperty_SetRenderCallback){//23
        NSLog(@"kAudioUnitProperty_SetRenderCallback: %p", inUnit);
        NSLog(@"    AudioUnitScope:%u", (unsigned int)inScope);

        AURenderCallbackStruct *callbackSt = (AURenderCallbackStruct *)inData;
        AURenderCallback inputProc = callbackSt->inputProc;
        void *inRefCon = callbackSt->inputProcRefCon;
        NSLog(@"    inputProc:%p", inputProc);
        NSLog(@"    inRefCon: %p", inRefCon);

        info.inputProc = inputProc;
        info.inRefCon = inRefCon;
        info.inScope = inScope;
        info.inElement = inElement;
    }
    else if(inID == kAudioUnitProperty_StreamFormat){//8
        NSLog(@"kAudioUnitProperty_StreamFormat: %p", inUnit);
        NSLog(@"    AudioUnitScope:%u", (unsigned int)inScope);

        UInt32 mFormatID = ((AudioStreamBasicDescription *)inData)->mFormatID;
        // NSLog(@"FormatID: %u", mFormatID);
        if(mFormatID != kAudioFormatLinearPCM){
            NSLog(@"mFormatID != kAudioFormatLinearPCM");
            return ret;
        }
        UInt32 mFormatFlags = ((AudioStreamBasicDescription *)inData)->mFormatFlags;
        UInt32 mBitsPerChannel = ((AudioStreamBasicDescription *)inData)->mBitsPerChannel;
        NSLog(@"    mFormatFlags: %u",(unsigned int)mFormatFlags);
        NSLog(@"    mBitsPerChannel: %u",(unsigned int)mBitsPerChannel);

        info.mFormatFlags = mFormatFlags;
        info.mBitsPerChannel = mBitsPerChannel;
    }
    else{
        return ret;
    }
    @synchronized(hookInfos){
        hookInfos[unitKey] = info;
    }
    if(info.inputProc && info.mFormatFlags){
        AURenderCallbackStruct callbackSt;
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
        int type = -1;
        if(info.mBitsPerChannel == 8){
            type = 2;
        }
        else{
            type = info.mFormatFlags & kAudioFormatFlagIsFloat;
        }
        pthread_mutex_lock(&mutex);
        AURenderCallback myInputProc = inputProc_maps[type][info.inputProc];
        if(!myInputProc){
            myInputProc = make_trampoline(my_inputProcs[type], info.inputProc);

            NSLog(@"[*] new inputProc: %p, type: %@", info.inputProc, type_strings[type]);
            inputProc_maps[type][info.inputProc] = myInputProc;
        }
        else{
            NSLog(@"[*] cached inputProc: %p, type: %@", info.inputProc, type_strings[type]);
        }
        pthread_mutex_unlock(&mutex);

        callbackSt.inputProc = myInputProc;
        callbackSt.inputProcRefCon = info.inRefCon;
        %orig(inUnit, kAudioUnitProperty_SetRenderCallback, info.inScope, info.inElement, &callbackSt, sizeof(callbackSt));

        info.inputProc = NULL;
    }
    return ret;
}

/*
    kAudioQueueParam_Volume         = 1,
    kAudioQueueParam_PlayRate       = 2,
    kAudioQueueParam_Pitch          = 3,
    kAudioQueueParam_VolumeRampTime = 4,
    kAudioQueueParam_Pan            = 13
*/
%hookf(OSStatus, AudioQueueSetParameter, AudioQueueRef inAQ, AudioQueueParameterID inParamID, AudioQueueParameterValue inValue){
    if([NSBundle.mainBundle.bundleIdentifier isEqualToString:kWebKitBundleId]){
        registerApp();
    }
    lstAudioQueue = inAQ;
    NSLog(@"AudioQueueSetParameter: %p %u %lf", (void *)inAQ, (unsigned int)inParamID, inValue);

    if(inParamID==kAudioQueueParam_Volume && inValue){
        inValue = g_curScale;
    }

    return %orig;
}
%hookf(OSStatus, AudioQueuePrime, AudioQueueRef inAQ, UInt32 inNumberOfFramesToPrepare, UInt32 *outNumberOfFramesPrepared){
    NSLog(@"AudioQueuePrime: %p", (void *)inAQ);
    lstAudioQueue = inAQ;
    AudioQueueParameterValue outValue;
    AudioQueueGetParameter(lstAudioQueue, kAudioQueueParam_Volume, &outValue);
    if(outValue){
        AudioQueueSetParameter(lstAudioQueue, kAudioQueueParam_Volume, g_curScale);
    }
    return %orig;
}
%hookf(OSStatus, AudioQueueStartUnified, AudioQueueRef inAQ, const AudioTimeStamp *inStartTime, uint64_t flags){
    NSLog(@"AudioQueueStartUnified: %p", (void *)inAQ);
    lstAudioQueue = inAQ;
    AudioQueueParameterValue outValue;
    AudioQueueGetParameter(lstAudioQueue, kAudioQueueParam_Volume, &outValue);
    if(outValue){
        AudioQueueSetParameter(lstAudioQueue, kAudioQueueParam_Volume, g_curScale);
    }
    return %orig;
}
%hookf(void, AudioServicesPlaySystemSoundWithOptions, SystemSoundID inSystemSoundID, id options, id inCompletionBlock){
    NSLog(@"AudioServicesPlaySystemSoundWithOptions");
    if(!g_curScale){
        return;
    }
    %orig;
}

#pragma mark AVAudioPlayer
%hook AVAudioPlayer
+ (instancetype)alloc{
    AVAudioPlayer *ret = %orig;
    lstAVAudioPlayer = ret;
    NSLog(@"AVAudioPlayer alloc %@", ret);
    if([NSBundle.mainBundle.bundleIdentifier isEqualToString:kWebKitBundleId]){
        registerApp();
    }
    return ret;
}
- (void)play{
    NSLog(@"AVAudioPlayer play %@", self);
    lstAVAudioPlayer = self;
    if(self.volume){
        self.volume = g_curScale;
    }
    %orig;
}
- (void)setRate:(float)rate{
    NSLog(@"AVAudioPlayer setRate: %f", rate);
    lstAVAudioPlayer = self;
    if(self.volume){
        self.volume = g_curScale;
    }
    %orig;
}
- (void)setVolume:(float)volume{
    NSLog(@"AVAudioPlayer setVolume: %f", volume);
    if(volume){
        volume = g_curScale;
    }
    %orig;
}
%end //AVAudioPlayer

#pragma mark AVPlayer
%hook AVPlayer
+ (instancetype)alloc{
    AVPlayer *ret = %orig;
    lstAVPlayer = ret;
    NSLog(@"AVPlayer alloc %@", ret);
    if([NSBundle.mainBundle.bundleIdentifier isEqualToString:kWebKitBundleId]){
        registerApp();
    }
    return ret;
}
- (void)play{
    NSLog(@"AVPlayer play: %@", self);
    lstAVPlayer = self;
    if(self.volume){
        self.volume = g_curScale;
    }
    %orig;
}
- (void)setRate:(float)rate{
    NSLog(@"AVPlayer setRate: %f", rate);
    if(rate){
        lstAVPlayer = self;
    }
    if(self.volume){
        self.volume = g_curScale;
    }
    %orig;
}
- (void)setVolume:(float)volume{
    NSLog(@"AVPlayer setVolume: %f", volume);
    if(volume){
        volume = g_curScale;
    }
    %orig;
}
%end //AVPlayer

#pragma mark AVAudioSession
%hook AVAudioSession
- (BOOL)setActive:(BOOL)active withOptions:(AVAudioSessionSetActiveOptions)options error:(NSError **)outError{
    BOOL audioMixEnabled = [g_defaults objectForKey:kPrefAudioMixEnabledKey] ? [g_defaults boolForKey:kPrefAudioMixEnabledKey] : NO;
    if(!audioMixEnabled){
        return %orig;
    }

    NSString *category = self.category;
    NSLog(@"mlyx AVAudio category %@, options %u", category, (unsigned int)options);

    //听歌识曲
    if([category isEqualToString:@"AVAudioSessionCategoryPlayAndRecord"] || [category isEqualToString:@"AVAudioSessionCategoryRecord"]){
        return %orig;
    }

    if([[g_defaults objectForKey:kPrefAudiomixAppsKey] containsObject:NSBundle.mainBundle.bundleIdentifier]){
        //Choose Playback Mode App to Fix that [Recommend: Music App]
        [self setCategory:AVAudioSessionCategoryPlayback withOptions:0 error:outError];
    }
    else{
        //AudioMix Enabled App Will NOT Show Up in ControlCenter and LockScreen MediaPlayer
        [self setCategory:category withOptions:2 error:outError];
    }

    return %orig;
}
%end //AVAudioSession

#pragma mark AVSampleBufferAudioRenderer
%hook AVSampleBufferAudioRenderer
+ (instancetype)alloc{
    id ret = %orig;
    lstAVSampleBufferAudioRenderer = ret;
    NSLog(@"AVSampleBufferAudioRenderer alloc %@", ret);
    if([NSBundle.mainBundle.bundleIdentifier isEqualToString:kWebKitBundleId]){
        registerApp();
    }
    return ret;
}
- (void)setVolume:(float)volume{
    NSLog(@"AVSampleBufferAudioRenderer setVolume: %f", volume);
    if(volume){
        volume = g_curScale;
    }
    %orig;
}
%end //AVSampleBufferAudioRenderer
%end //app

static void initScale(){
    NSNumber *scaleNumber = [g_defaults objectForKey:kPrefScalesKey][NSBundle.mainBundle.bundleIdentifier];
    if(scaleNumber){
        g_curScale = [scaleNumber doubleValue];
        auCurScale = g_curScale;
    }
}
static void setScale(double curScale){
    g_curScale = curScale;
    auCurScale = g_curScale;

    if(lstAudioQueue){
        AudioQueueSetParameter(lstAudioQueue, kAudioQueueParam_Volume, g_curScale);
    }
    lstAVAudioPlayer.volume = g_curScale;
    lstAVPlayer.volume = g_curScale;
    [lstAVSampleBufferAudioRenderer setVolume:g_curScale];
}

@interface VMAPPServer : NSObject
@end
@implementation VMAPPServer{
    MRYIPCCenter *_center;
}
- (instancetype)initWithName:(NSString*)name{
    if((self = [super init])){
        _center = [MRYIPCCenter centerNamed:name];
        [_center addTarget:self action:@selector(setVolume:)];
    }
    return self;
}
- (void)setVolume:(NSDictionary *)args{
    double curScale = [args[@"curScale"] doubleValue];
    setScale(curScale);
}
@end

static VMAPPServer *appServer = nil;

static void registerApp(){
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        //send bundleid
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        MRYIPCCenter *idClient = [MRYIPCCenter centerNamed:@"com.brend0n.volumemixer/register"];

        int pid = NSProcessInfo.processInfo.processIdentifier;
        [idClient callExternalVoidMethod:@selector(register:) withArguments:@{@"bundleID":bundleID, @"pid":@(pid)}];

        NSString *appNotify = [NSString stringWithFormat:@"com.brend0n.volumemixer/%@~%d/setVolume", bundleID, pid];
        appServer = [[VMAPPServer alloc] initWithName:appNotify];
    });
}

#pragma mark ctor
%ctor{
    if(!isEnabledApp()){
        return;
    }
    NSLog(@"ctor: VolumeMixer");

    void *AudioToolbox = dlopen("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox", RTLD_LAZY);
    void *AudioQueueStartUnified = dlsym(AudioToolbox, "AudioQueueStartWithFlags");
    if(!AudioQueueStartUnified){
        AudioQueueStartUnified = (void *)AudioQueueStart;
    }
    void *AudioServicesPlaySystemSoundWithOptions = dlsym(AudioToolbox, "AudioServicesPlaySystemSoundWithOptions");
    dlclose(AudioToolbox);

    %init(app, AVSampleBufferAudioRenderer = objc_getClass("AVSampleBufferAudioRenderer"), AudioQueueStartUnified = AudioQueueStartUnified, AudioServicesPlaySystemSoundWithOptions = AudioServicesPlaySystemSoundWithOptions);
    if(![NSBundle.mainBundle.bundleIdentifier isEqualToString:kWebKitBundleId]) {
        registerApp();
    }
    initScale();
    hookInfos = [NSMutableDictionary new];

    loadPref();
    int token;
    notify_register_dispatch("com.brend0n.volumemixer/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
        loadPref();
    });
}

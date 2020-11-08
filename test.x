#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenAL/OpenAL.h>

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
// +(id)materialViewWithStyleOptions:(NSInteger)arg1 materialSettings:(id)arg2 captureOnly:(BOOL)arg3{
// 	NSLog(@"vmlog %ld %@ %d",(long)arg1,arg2,arg3);
// 	return %orig;

// }
// %end

%ctor{

}
#import <AudioUnit/AudioUnit.h>
typedef OSStatus(*orig_t)(void*,AudioUnitRenderActionFlags*,const AudioTimeStamp*,UInt32,UInt32,AudioBufferList*);
extern NSMutableDictionary<NSString*,NSNumber*> *origCallbacks;
extern double auCurScale;
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

	for (UInt32 i = 0; i < ioData -> mNumberBuffers; i++){
		auto *buf = (unsigned char*)ioData->mBuffers[i].mData;

		uint bytes = ioData->mBuffers[i].mDataByteSize;
		

	    for(UInt32 j=0;j<bytes;j+=sizeof(T)){
	        volume_adjust((T*)(buf+j), (T*)(buf+j), auCurScale);
	    }
	}
	
    
	return ret;
}
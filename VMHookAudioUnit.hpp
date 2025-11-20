#import <AudioUnit/AudioUnit.h>

#import <vector>

extern double auCurScale;

// credits to https://blog.csdn.net/Timsley/article/details/50683084?utm_medium=distribute.pc_relevant.none-task-blog-BlogCommendFromMachineLearnPai2-1.nonecase&depth_1-utm_source=distribute.pc_relevant.none-task-blog-BlogCommendFromMachineLearnPai2-1.nonecase
// credits to https://www.jianshu.com/p/ca2cb00418a7
template<class T>
static int volume_adjust(T *in_buf, T *out_buf, double in_vol) {
    double tmp;

    double vol = in_vol;

    tmp = (*in_buf) * vol;

    // 下面的code主要是为了溢出判断
    double maxValue = pow(2., sizeof(T) * 8.0 - 1.0) - 1.0;
    double minValue = pow(2., sizeof(T) * 8.0 - 1.0) * -1.0;
    tmp = MIN(tmp, maxValue);
    tmp = MAX(tmp, minValue);

    *out_buf = tmp;

    return 0;
}

template<class T>
OSStatus my_inputProc(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    AURenderCallback orig = NULL;
    #if __aarch64__
    asm volatile ("mov %0, x16" : "=r" (orig));
    #elif __x86_64__
    asm volatile ("mov %%rax, %0" : "=r" (orig));
    #endif

    std::vector<void *> mDatas;
    for(UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
        mDatas.push_back(ioData->mBuffers[i].mData);
    }

    OSStatus ret = orig(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);

    if(*ioActionFlags == kAudioUnitRenderAction_OutputIsSilence) {
        return ret;
    }

    for(UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
        AudioBuffer *mBuffer = &ioData->mBuffers[i];
        void *mData = mDatas[i];
        if(mBuffer->mData != mData){
            memcpy(mData, mBuffer->mData, mBuffer->mDataByteSize);
            mBuffer->mData = mData;
        }

        unsigned char *buf = (unsigned char *)ioData->mBuffers[i].mData;

        uint bytes = ioData->mBuffers[i].mDataByteSize;

        for(UInt32 j = 0; j < bytes; j += sizeof(T)) {
            volume_adjust((T *)(buf + j), (T *)(buf + j), auCurScale);
        }
    }

    return ret;
}

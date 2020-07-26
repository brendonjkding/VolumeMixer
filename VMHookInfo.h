extern NSMutableDictionary<NSString*,NSNumber*> *hookedCallbacks;
@interface VMHookInfo:NSObject
@property void *outputCallback;
@property UInt32 mFormatFlags;
@property void*inRefCon;
@property void*orig_outputCallback;
@property BOOL hooked;
-(void)hookIfReady;
@end
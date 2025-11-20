@interface FBProcessState : NSObject 
@property (assign,nonatomic) long long taskState;
@end

@interface FBProcess : NSObject
@property (nonatomic,readonly) int pid;
@property (nonatomic,copy,readonly) FBProcessState *state;
@end
@interface FBApplicationProcess : FBProcess
@end

@interface FBProcessManager : NSObject
+ (id)sharedInstance;
- (NSArray<FBApplicationProcess *> *)applicationProcessesForBundleIdentifier:(NSString *)identifier;
- (FBProcess *)processForPID:(int)arg1;
@end

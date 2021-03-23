@interface FBProcessState : NSObject 
@property (assign,nonatomic) long long taskState;
@end

@interface FBProcess : NSObject
@property (nonatomic,copy,readonly) FBProcessState * state;
@end

@interface FBProcessManager : NSObject
+(id)sharedInstance;
-(FBProcess*)processForPID:(int)arg1 ;
@end




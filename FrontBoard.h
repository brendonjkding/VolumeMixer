#import <FrontBoard/FBProcessManager.h>

@interface FBProcessState : NSObject 
@property (assign,nonatomic) long long taskState;
@end

@interface FBProcess : NSObject
@property (nonatomic,copy,readonly) FBProcessState *state;
@end

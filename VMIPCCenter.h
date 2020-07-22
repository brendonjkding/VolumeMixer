@interface VMIPCCenter : NSObject
-(instancetype)initWithName:(NSString* )name;
@property void(^volumeChangedCallBlock)(double);
@end

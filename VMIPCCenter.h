@interface VMIPCCenter : NSObject
-(instancetype)initWithName:(NSString* )name;
@property void(^volumeChangedCallBlock)(double);
@property void(^registerBlock)(NSDictionary*);
@end

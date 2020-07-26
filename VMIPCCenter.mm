#import "VMIPCCenter.h"
#import <MRYIPCCenter/MRYIPCCenter.h>
@implementation VMIPCCenter
{
	MRYIPCCenter* _center;
}


-(instancetype)initWithName:(NSString* )name
{
	if ((self = [super init]))
	{
		_center = [MRYIPCCenter centerNamed:name];
		[_center addTarget:self action:@selector(setVolume:)];
		[_center addTarget:self action:@selector(register:)];
		NSLog(@"[MRYIPC] running server in %@", [NSProcessInfo processInfo].processName);
	}
	return self;
}

-(void)setVolume:(NSDictionary*)args
{
	double curScale=[args[@"curScale"] doubleValue];
	_volumeChangedCallBlock(curScale);
}
-(void)register:(NSDictionary*)args
{
	_registerBlock(args);
}
@end
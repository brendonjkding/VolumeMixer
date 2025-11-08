#import "VMLicenseViewController.h"

@implementation VMLicenseViewController
- (void)loadView{
	[super loadView];

    self.navigationItem.title = @"Licenses";
    UITextView*textView = [UITextView new];
    textView.frame = self.view.frame;

    NSString *licenses = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@/licenses.txt", kBundlePath] encoding:NSUTF8StringEncoding error:nil];
    textView.text = licenses;

    [self.view addSubview:textView];
}
@end

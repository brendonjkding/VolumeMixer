#import "VMHUDRootViewController.h"
#import "VMHUDWindow.h"
#import "VMHUDView.h"
#import <notify.h>
#import <AppList/AppList.h>

NSString*prefPath=@"/var/mobile/Library/Preferences/com.brend0n.qqmusicdesktoplyrics.plist";

@interface VMHUDRootViewController()<UICollectionViewDelegate,UICollectionViewDataSource>
@property (strong, nonatomic) UICollectionView *collectionView;
@property (strong, nonatomic) NSMutableArray* hudViews;
@property (strong, nonatomic) NSMutableArray* bundleIDs;
@end
@implementation VMHUDRootViewController

-(void)loadView{
	[super loadView];
	[self.view addSubview:[self collectionView]];
	[self registerNotify];
	_hudViews=[NSMutableArray new];
	_bundleIDs=[NSMutableArray new];
}

- (UICollectionView *)collectionView{
    if(!_collectionView) {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.minimumLineSpacing = 1;
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 100, self.view.frame.size.width, 148) collectionViewLayout:layout];
        [self.view addSubview:_collectionView];
        _collectionView.showsHorizontalScrollIndicator = NO;
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        _collectionView.backgroundColor = [UIColor clearColor];
        
        [_collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"UICollectionViewCell"];
    }
    return _collectionView;
}
-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return [_hudViews count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"UICollectionViewCell" forIndexPath:indexPath];
    // UIImageView *imageView = [[UIImageView alloc] initWithFrame:cell.bounds];
    // imageView.image = [UIImage imageNamed:@"2623743-21d547b5c37a8f8e"];
    // [cell addSubview:imageView];
    for(UIView*view in [cell subviews]){
    	[view removeFromSuperview];
    }
    VMHUDView* hudview=_hudViews[indexPath.row];
    [cell setFrame:CGRectMake(cell.frame.origin.x,cell.frame.origin.y,hudview.frame.size.width,hudview.frame.size.height)];
    [cell addSubview:hudview];
    UIImage *icon = [[ALApplicationList sharedApplicationList] iconOfSize:ALApplicationIconSizeSmall forDisplayIdentifier:_bundleIDs[indexPath.row]];
    UIImageView* imageView=[[UIImageView alloc] initWithImage:icon];
    [cell addSubview:imageView];
    
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(100,148);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 5;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 5;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section{
    return UIEdgeInsetsMake(0, 0, 0, 0);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"%ld",indexPath.row);
}

-(void) registerNotify{
	int token=0;
	//receive bundleID
	notify_register_dispatch("com.brend0n.qqmusicdesktoplyrics/register", &token, dispatch_get_main_queue(), ^(int token) {
		NSLog(@"registering...");
    	NSData*bundleIDData=[[UIPasteboard generalPasteboard] valueForPasteboardType:@"com.brend0n.volumemixer/bundleID"];
    	NSString*bundleID= [NSKeyedUnarchiver unarchiveObjectWithData:bundleIDData];
    	NSString*appNotify=[NSString stringWithFormat:@"com.brend0n.volumemixer/%@/setVolume",bundleID];
    	if(!bundleID)return;
    	if([_bundleIDs containsObject:bundleID])return ;
    	NSLog(@"bundleID:%@",bundleID);
    	NSLog(@"appNotify:%@",appNotify);
    	dispatch_async(dispatch_get_main_queue(), ^{
	        [_bundleIDs addObject:bundleID];
	    	__block VMHUDView* hudView=[[VMHUDView alloc] initWithFrame:CGRectMake(0,0,47,148)];
	    	[_hudViews addObject:hudView];
	    	__weak VMHUDView*weakHUDView=hudView;
	    	[hudView setVolumeChangedCallBlock:^{
	    		//send volume
	    		NSData*scaleData=[NSKeyedArchiver archivedDataWithRootObject:[NSNumber numberWithDouble:[weakHUDView curScale]]];
	    		[[UIPasteboard generalPasteboard] setData:scaleData forPasteboardType:@"com.brend0n.volumemixer"];
	    		
	    		// NSLog(@"%@",appNotify);
	    		notify_post([appNotify UTF8String]);
	    	}];
		    
	        [self.collectionView reloadData];
		});
    	
	});
}
@end
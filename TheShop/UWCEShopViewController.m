//
//  UWCEShopViewController.m
//  TheShop
//
//  Created by Doug Russell on 5/20/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCEShopViewController.h"
#import <CoreData/CoreData.h>
#import "UWCEDataController.h"
#import "UWCEShopItemCell.h"
#import "UWCEShopGridLayout.h"

@interface UWCEShopViewController () <NSFetchedResultsControllerDelegate, UWCEShopItemCellDelegate>
@property (nonatomic) NSFetchedResultsController *frc;
@property (nonatomic) BOOL displayingExpandedCell;
@end

@implementation UWCEShopViewController

#pragma mark - Setup Cleanup

- (instancetype)init
{
	UWCEShopGridLayout *flow = [UWCEShopGridLayout new];
	self = [super initWithCollectionViewLayout:flow];
	if (self)
	{
		
	}
	return self;
}

#pragma mark - View Life Cycle

- (UWCEShopGridLayout *)flowLayout
{
	return (UWCEShopGridLayout *)self.collectionView.collectionViewLayout;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	[self flowLayout].itemSize = CGSizeMake(300.0f, 500.0f);
	[self flowLayout].minimumLineSpacing = 30.0f;
	
	[self.collectionView registerClass:[UWCEShopItemCell class] forCellWithReuseIdentifier:[UWCEShopItemCell uwce_identifier]];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newManifestNotification:) name:UWCEDataControllerNewManifestAvailableNotification object:nil];
	
	[self.frc performFetch:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[self configureForOrientation:self.interfaceOrientation];
}

- (void)newManifestNotification:(NSNotificationCenter *)note
{
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		self.frc.delegate = nil;
		self.frc = nil;
		[self.frc performFetch:nil];
		[self.collectionView reloadData];
	});
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self configureForOrientation:toInterfaceOrientation];
}

- (void)configureForOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if (UIInterfaceOrientationIsLandscape(interfaceOrientation))
	{
		[self flowLayout].sectionInset = UIEdgeInsetsMake(30.0f, 30.0f, 30.0f, 30.0f);
	}
	else if (UIInterfaceOrientationIsPortrait(interfaceOrientation))
	{
		[self flowLayout].sectionInset = UIEdgeInsetsMake(30.0f, 50.0f, 30.0f, 50.0f);
	}
}

#pragma mark - Collection View Delegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return [((id<NSFetchedResultsSectionInfo>)[self.frc sections][section]) numberOfObjects];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	UWCEShopItemCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[UWCEShopItemCell uwce_identifier] forIndexPath:indexPath];
	cell.backgroundColor = [UIColor whiteColor];
	cell.delegate = self;
	if ([indexPath compare:[self flowLayout].expandedIndexPath] == NSOrderedSame)
	{
		cell.expanded = true;
	}
	
	UWCEShopItem *item = ((UWCEShopItem *)self.frc.fetchedObjects[indexPath.row]);

	cell.titleLbl.text = item.title;
	cell.authorLbl.text = item.author;
	cell.smallDetailsLbl.text = item.details;
	cell.smallImageURL = item.smallVideoPosterFrameURL;
	cell.largeDetailsView.text = item.details;
	[cell.largeDetailsView setNeedsLayout];
	cell.largeImageURL = item.largeVideoPosterFrameURL;
	
	[self fetchImageForCell:cell];
	[self.view setNeedsLayout];

	return cell;
}

#pragma mark - Fetched Results Controller

- (NSFetchedResultsController *)frc
{
	if (_frc)
		return _frc;
	NSManagedObjectContext *context = [[UWCEDataController sharedInstance] readerContext];
	NSFetchRequest *fetchRequest = [NSFetchRequest new];
	fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES]];
	NSEntityDescription *entity = [NSEntityDescription entityForName:[UWCEShopItem uwce_entityName] inManagedObjectContext:context];
	fetchRequest.entity = entity;
	if (!entity)
	{
		return nil;
	}
	UWCEShopManifest *manifest = [[UWCEDataController sharedInstance] currentManifest];
	if (!manifest)
	{
		return nil;
	}
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"manifest == %@", manifest];
	fetchRequest.predicate = predicate;
	_frc = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:context sectionNameKeyPath:nil cacheName:nil];
	_frc.delegate = self;
	return _frc;
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
	[self.collectionView reloadData];
}

#pragma mark - 

- (void)uwce_cellTapped:(UWCEShopItemCell *)cell
{
	NSIndexPath *new = [self.collectionView indexPathForCell:cell];
	if (cell.expanded)
	{
		cell.expanded = NO;
		[self fetchImageForCell:cell];
		NSIndexPath *current = [self flowLayout].expandedIndexPath;
		if ([new compare:current] != NSOrderedSame)
		{
			return;
		}
		[self flowLayout].expandedIndexPath = nil;
		self.collectionView.scrollEnabled = YES;
	}
	else
	{
		cell.expanded = YES;
		[self fetchImageForCell:cell];
		if (!self.collectionView.scrollEnabled)
		{
			return;
		}
		self.collectionView.scrollEnabled = NO;
		[self flowLayout].expandedIndexPath = new;
	}
	[UIView transitionWithView:cell duration:0.3f options:UIViewAnimationOptionTransitionFlipFromRight|UIViewAnimationOptionLayoutSubviews animations:^{
		[[self flowLayout] invalidateLayout];
	} completion:^(BOOL finished) {
		if (finished)
		{
			
		}
	}];
}

-(void)fetchImageForCell:(UWCEShopItemCell *) cell {
    NSURL *url;
	CGSize size;
	
	if (cell.expanded) {
		url = [NSURL URLWithString:cell.largeImageURL];
		size = cell.largePosterView.bounds.size;
	}
	else {
		return;
	}
    
	NSLog(@"%@", url);
    if (!url)
    {
        return;
    }
    
    __weak typeof(*cell) *weakCell = cell;
    void (^completionBlock)(UIImage *, NSError *) = ^(UIImage *image, NSError *error) {
        if (image)
        {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [weakCell assignImage:image];
            });
        }
        else
        {
            NSLog(@"%@", error);
        }
    };
	
    [[UWCEImageCache imageCache] imageForURL:url size:size completionHandler:completionBlock];
}


@end

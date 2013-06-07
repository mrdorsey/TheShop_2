//
//  UWCEShopItemCell.m
//  TheShop
//
//  Created by Doug Russell on 5/20/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCEImageCache.h"
#import "UWCEShopItemCell.h"

// HW 3:
// Write two layouts for this cell
// One expanded, one collapsed
// based on expanded property

// Collapsed will show:

// Title, Author, truncated details (optionally small poster frame)

// Expanded will show large poster frame, title, author, full details (this should be scrollable)

@interface UWCEShopItemCell () <UIGestureRecognizerDelegate>

@end

@implementation UWCEShopItemCell 

+ (NSString *)uwce_identifier
{
	return @"ShopCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self)
	{
		UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
		tap.delegate = self;
		[self.contentView addGestureRecognizer:tap];
		
		UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		titleLabel.textAlignment = NSTextAlignmentCenter;
		[self.contentView addSubview:titleLabel];
		_titleLbl = titleLabel;
		
		UILabel *authorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		authorLabel.textAlignment = NSTextAlignmentCenter;
		[self.contentView addSubview:authorLabel];
		_authorLbl = authorLabel;
		
		UILabel *smallDetailsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		smallDetailsLabel.textAlignment = NSTextAlignmentCenter;
		[self.contentView addSubview:smallDetailsLabel];
		[smallDetailsLabel setNumberOfLines:2];
		_smallDetailsLbl = smallDetailsLabel;
		
		UITextView *largeDetailsView = [[UITextView alloc] initWithFrame:CGRectZero];
		largeDetailsView.textAlignment = NSTextAlignmentCenter;
		[largeDetailsView setEditable:NO];
		[self.contentView addSubview:largeDetailsView];
		_largeDetailsView = largeDetailsView;
		
		/*UIImageView *smallImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
		[smallImageView setContentMode:UIViewContentModeScaleAspectFill];
		[self.contentView addSubview:smallImageView];
		_smallPosterView = smallImageView;*/
		
		UIImageView *largeImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
		[largeImageView setContentMode:UIViewContentModeScaleAspectFill];
		[self.contentView addSubview:largeImageView];
		_largePosterView = largeImageView;
		
		[self uglifyUI];
	}
	return self;
}

- (void)dealloc
{
	[self.gestureRecognizers makeObjectsPerformSelector:@selector(setDelegate:) withObject:nil];
}

- (void)setExpanded:(bool)expanded
{
	[self setExpanded:expanded animated:FALSE];
}

- (void)setExpanded:(bool)expanded animated:(bool)animated
{
	_expanded = expanded;
}

- (void)prepareForReuse
{
	[super prepareForReuse];
	self.expanded = false;
	self.titleLbl.text = nil;
	self.authorLbl.text = nil;
	self.smallDetailsLbl.text = nil;
	//self.smallPosterView.image = nil;
	self.smallImageURL = nil;
	self.largeDetailsView.text = nil;
	self.largePosterView.image = nil;
	self.largeImageURL = nil;
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	// TODO: Make sizing / spacing more constraint-driven
	CGFloat margin = 10;
	CGFloat height = 30.0f;
	
	if ([self expanded]) {
		margin = 20;
		height = 60.0f;
	}
	
	self.titleLbl.frame = CGRectMake(margin, margin, self.contentView.frame.size.width - (margin * 2), height);
	self.authorLbl.frame = CGRectMake(margin, (margin * 2) + height, self.contentView.frame.size.width - (margin * 2), height);
	
	if (self.expanded) {
		[self.smallDetailsLbl setHidden:TRUE];
		//[self.smallPosterView setHidden:TRUE];
		[self.largeDetailsView setHidden:FALSE];
		[self.largePosterView setHidden:FALSE];
		self.largeDetailsView.frame = CGRectMake(margin, (margin * 3) + (height * 2), self.contentView.frame.size.width - (margin * 2), height * 3);
		self.largePosterView.frame = CGRectMake(margin, (margin * 4) + (height * 5), self.contentView.frame.size.width - (margin * 2), 500);
		[self.largePosterView setNeedsLayout];
		[self.largePosterView setNeedsDisplay];
	}
	else {
		[self.smallDetailsLbl setHidden:FALSE];
		//[self.smallPosterView setHidden:FALSE];
		[self.largeDetailsView setHidden:TRUE];
		[self.largePosterView setHidden:TRUE];
		self.smallDetailsLbl.frame = CGRectMake(margin, (margin * 3) + (height * 2), self.contentView.frame.size.width - (margin * 2), height);
		//self.smallPosterView.frame = CGRectMake(margin, (margin * 4) + (height * 3), self.contentView.frame.size.width - (margin * 2), 300);
		//[self.smallPosterView setNeedsLayout];
		//[self.smallPosterView setNeedsDisplay];
	}
}

- (void)tapped:(UITapGestureRecognizer *)gestureRecognizer
{
	[self.delegate uwce_cellTapped:self];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
	return YES;
}

- (void)assignImage:(UIImage *)image
{
	if (self.expanded) {
		self.largePosterView.image = image;
		[self.largePosterView setNeedsDisplay];
		[self.largePosterView setNeedsLayout];
		[self setNeedsLayout];
	}
	else {
		/*self.smallPosterView.image = image;
		[self.smallPosterView setNeedsDisplay];
		[self.smallPosterView setNeedsLayout];
		[self setNeedsLayout];*/
	}
}

#pragma mark - private helper
- (void)uglifyUI
{
	[_titleLbl setBackgroundColor:[UIColor greenColor]];
	[_authorLbl setBackgroundColor:[UIColor grayColor]];
	[_smallDetailsLbl setBackgroundColor:[UIColor purpleColor]];
	[_largeDetailsView setBackgroundColor:[UIColor yellowColor]];
}

@end

//
//  UWCEShopItemCell.h
//  TheShop
//
//  Created by Doug Russell on 5/20/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol UWCEShopItemCellDelegate;

@interface UWCEShopItemCell : UICollectionViewCell

+ (NSString *)uwce_identifier;

@property (weak, nonatomic) UILabel *titleLbl;
@property (weak, nonatomic) UILabel *authorLbl;
@property (weak, nonatomic) UILabel *smallDetailsLbl;
@property (weak, nonatomic) UIImageView *smallPosterView;
@property (weak, nonatomic) UIImageView *largePosterView;
@property (weak, nonatomic) UITextView *largeDetailsView;
@property (weak, nonatomic) NSString *smallImageURL;
@property (weak, nonatomic) NSString *largeImageURL;
@property (weak, nonatomic) id<UWCEShopItemCellDelegate> delegate;
@property (nonatomic) bool expanded;

- (void)assignImage:(UIImage *)image;

@end

@protocol UWCEShopItemCellDelegate <NSObject>
- (void)uwce_cellTapped:(UWCEShopItemCell *)cell;
@end

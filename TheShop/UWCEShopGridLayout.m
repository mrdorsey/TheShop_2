//
//  UWCEShopGridLayout.m
//  TheShop
//
//  Created by Doug Russell on 5/20/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCEShopGridLayout.h"

@implementation UWCEShopGridLayout

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
	NSArray *attributesArray = [super layoutAttributesForElementsInRect:rect];
	for (UICollectionViewLayoutAttributes *attributes in attributesArray)
	{
		if ([attributes.indexPath compare:self.expandedIndexPath] == NSOrderedSame)
		{
			CGRect frame;
			frame.origin = self.collectionView.contentOffset;
			frame.size = self.collectionView.frame.size;
			attributes.frame = frame;
		}
		else
		{
			attributes.zIndex = -1;
		}
	}
	return attributesArray;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
	UICollectionViewLayoutAttributes *attributes = [super layoutAttributesForItemAtIndexPath:indexPath];
	if ([attributes.indexPath compare:self.expandedIndexPath] == NSOrderedSame)
	{
		CGRect frame;
		frame.origin = self.collectionView.contentOffset;
		frame.size = self.collectionView.frame.size;
		attributes.frame = frame;
	}
	return attributes;
}

@end

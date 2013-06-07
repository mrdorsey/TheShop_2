//
//  UWCEDataController.m
//  UWCEImageCaching
//
//  Created by Doug Russell on 5/6/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCEDataController.h"

#import "UWCEHTTPOperation.h"

#import "NSLock+UWCELockBlock.h"

#import "UWCEDataControllerConfig.h"

#import "UWCEDatabase.h"
#import "UWCEShopManifest.h"
#import "UWCEShopItem.h"
#import "UWCEShopKeyword.h"

NSString *const UWCEDataControllerNewManifestAvailableNotification = @"UWCEDataControllerNewManifestAvailableNotification";

static NSString *const kUWCEBaseURLString = @"http://fierce-refuge-6970.herokuapp.com";
static NSString *const kUWCEConfigURLString = @"/config";

static NSString *UWCECreatedKey = @"created";
static NSString *UWCEItemsKey = @"items";

@interface UWCEDataController ()
@property (nonatomic) NSOperationQueue *networkQueue;
@property (nonatomic) NSOperationQueue *workQueue;
@property UWCEDataControllerConfig *currentConfig;
@property (nonatomic) NSRecursiveLock *configLock;
@property (nonatomic) UWCEDatabase *database;
@end

@implementation UWCEDataController
@synthesize currentConfig=_currentConfig;

+ (instancetype)sharedInstance
{
	static id instance;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [self new];
	});
	return instance;
}

- (instancetype)init
{
	self = [super init];
	if (self)
	{
		_database = [UWCEDatabase new];
		_networkQueue = [NSOperationQueue new];
		_networkQueue.name = @"com.uwce.networkqueue";
		_networkQueue.maxConcurrentOperationCount = 10;
		_workQueue = [NSOperationQueue new];
		_workQueue.name = @"com.uwce.workqueue";
		_configLock = [NSRecursiveLock new];
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void) {
			[self deleteOldManifests];
		});
	}
	return self;
}

#pragma mark - Config

- (void)fetchConfig
{
	NSURL *url = [NSURL URLWithString:kUWCEConfigURLString relativeToURL:[NSURL URLWithString:kUWCEBaseURLString]];
	NSParameterAssert(url);
	UWCEHTTPOperation *op = [[UWCEHTTPOperation alloc] initWithURL:url];
	__unsafe_unretained typeof(*op) *unsafeOp = op;
	[op setCompletionBlock:^{
		NSData *data = unsafeOp.result;
		[self processConfigData:data];
	}];
	[self.networkQueue addOperation:op];
}

- (void)processConfigData:(NSData *)data
{
	if (!data)
		return;
	[self.workQueue addOperationWithBlock:^{
		NSError *error;
		id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
		if (object)
		{
			NSLog(@"%@", object);
			UWCEDataControllerConfig *config = [[UWCEDataControllerConfig alloc] initWithDictionary:object];
			if (config)
			{
				self.currentConfig = config;
				[self fetchManifest];
			}
		}
		else
		{
			NSLog(@"%@", error);
		}
	}];
}

+ (BOOL)automaticallyNotifiesObserversOfCurrentConfig
{
	return NO;
}

- (UWCEDataControllerConfig *)currentConfig
{
	__block UWCEDataControllerConfig *config;
	NSParameterAssert(self.configLock);
	[self.configLock uwce_lockBlock:^{
		config = self->_currentConfig;
	}];
	return config;
}

- (void)setCurrentConfig:(UWCEDataControllerConfig *)newConfig
{
	NSParameterAssert(self.configLock);
	[self.configLock uwce_lockBlock:^{
		if (newConfig && newConfig != self->_currentConfig && ([newConfig compare:self->_currentConfig] == NSOrderedAscending))
		{
			[self willChangeValueForKey:@"currentConfig"];
			self->_currentConfig = newConfig;
			if (self->_currentConfig && !self.ready)
			{
				self.ready = true;
			}
			[self didChangeValueForKey:@"currentConfig"];
		}
	}];
}

#pragma mark - 

- (void)fetchManifest
{
	if (!self.ready)
	{
		return;
	}
	NSURL *url = [NSURL URLWithString:@"?unique=12" relativeToURL:self.currentConfig.shopManifestURL];
	if (!url)
	{
		return;
	}
	UWCEHTTPOperation *op = [[UWCEHTTPOperation alloc] initWithURL:url];
	__unsafe_unretained typeof(*op) *unsafeOp = op;
	[op setCompletionBlock:^{
		NSData *data = unsafeOp.result;
		[self processShopManifestData:data];
	}];
	[self.networkQueue addOperation:op];
}

- (void)processShopManifestData:(NSData *)data
{
	if (!data)
		return;
	[self.workQueue addOperationWithBlock:^{
		NSError *error;
		id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
		if (object)
		{
			if ([object isKindOfClass:[NSDictionary class]])
			{
				NSDictionary *dictionary = (NSDictionary *)object;
				NSNumber *createdTimeStamp = dictionary[UWCECreatedKey];
				NSArray *items = dictionary[UWCEItemsKey];
				if ([createdTimeStamp isKindOfClass:[NSNumber class]] && [items isKindOfClass:[NSArray class]])
				{
					NSDate *created = [NSDate dateWithTimeIntervalSince1970:[createdTimeStamp doubleValue]];
					if (created)
					{
						NSManagedObjectContext *context = [self.database childContext];
						[context performBlock:^{
							// If the manifest for this date already exists, we're done
							UWCEShopManifest *manifest = [self fetchShopManifestWithDateCreated:created context:context];
							// Otherwise make it
							if (!manifest)
							{
								manifest = [self insertShopManifestWithDateCreated:created items:items context:context];
								if ([self.database saveContext:context] && [self.database saveWriterContext])
								{
									[[NSNotificationCenter defaultCenter] postNotificationName:UWCEDataControllerNewManifestAvailableNotification object:[manifest objectID]];
								}
							}
						}];
					}
				}
			}
		}
		else
		{
			NSLog(@"%@", error);
		}
	}];
}

- (UWCEShopManifest *)fetchShopManifestWithDateCreated:(NSDate *)created context:(NSManagedObjectContext *)context
{
	NSParameterAssert(context);
	NSParameterAssert(created);
	NSFetchRequest *request = [NSFetchRequest new];
	request.fetchLimit = 1;
	NSEntityDescription *entity = [NSEntityDescription entityForName:[UWCEShopManifest uwce_entityName] inManagedObjectContext:context];
	request.entity = entity;	
	request.predicate = [NSPredicate predicateWithFormat:@"(%K == %@)", @"created", created];
	NSError *error = nil;
	NSArray *result = [context executeFetchRequest:request error:&error];
	return [result lastObject];
}

- (UWCEShopManifest *)insertShopManifestWithDateCreated:(NSDate *)created items:(NSArray *)items context:(NSManagedObjectContext *)context
{
	NSParameterAssert(context);
	NSParameterAssert(created);
	NSParameterAssert(items);
	UWCEShopManifest *manifest = [NSEntityDescription insertNewObjectForEntityForName:[UWCEShopManifest uwce_entityName] inManagedObjectContext:context];
	if (manifest)
	{
		manifest.created = created;
		NSUInteger index = 0;
		for (NSDictionary *itemDictionary in items)
		{
			UWCEShopItem *item = [self insertItemWithDictionary:itemDictionary shopManifest:manifest context:context];
			if (item)
			{
				item.index = @(index);
				index++;
				[manifest addItemsObject:item];
			}
		}
	}
	return manifest;
}

- (UWCEShopItem *)insertItemWithDictionary:(NSDictionary *)dictionary shopManifest:(UWCEShopManifest *)shopManifest context:(NSManagedObjectContext *)context
{
	NSParameterAssert(context);
	NSParameterAssert(dictionary);
	NSParameterAssert(shopManifest);
	UWCEShopItem *item = [NSEntityDescription insertNewObjectForEntityForName:[UWCEShopItem uwce_entityName] inManagedObjectContext:context];
	if (item)
	{
		item.identifier = dictionary[@"identifier"];
		item.title = dictionary[@"title"];
		item.author = dictionary[@"author"];
		item.smallVideoPosterFrameURL = dictionary[@"smallVideoPosterFrameURL"];
		item.largeVideoPosterFrameURL = dictionary[@"largeVideoPosterFrameURL"];
		item.details = dictionary[@"description"];
		for (NSString *keyword in dictionary[@"keywords"])
		{
			(void)[self fetchOrInsertKeyword:keyword item:item shopManifest:shopManifest context:context];
		}
		item.manifest = shopManifest;
	}
	return item;
}

- (UWCEShopKeyword *)fetchOrInsertKeyword:(NSString *)keywordValue item:(UWCEShopItem *)item shopManifest:(UWCEShopManifest *)shopManifest context:(NSManagedObjectContext *)context
{
	NSParameterAssert(context);
	NSParameterAssert(keywordValue);
	NSParameterAssert(shopManifest);
	NSParameterAssert(item);
	NSFetchRequest *request = [NSFetchRequest new];
	request.fetchLimit = 1;
	NSEntityDescription *entity = [NSEntityDescription entityForName:[UWCEShopKeyword uwce_entityName] inManagedObjectContext:context];
	request.entity = entity;	
	request.predicate = [NSPredicate predicateWithFormat:@"(%K == %@) AND (%K == %@)", @"manifest", shopManifest, @"value", keywordValue];
	NSError *error = nil;
	NSArray *result = [context executeFetchRequest:request error:&error];
	UWCEShopKeyword *keyword = [result lastObject];
	if (keyword)
	{
		[item addKeywordsObject:keyword];
		[keyword addItemsObject:item];
		keyword.manifest = shopManifest;
	}
	else
	{
		keyword = [NSEntityDescription insertNewObjectForEntityForName:[UWCEShopKeyword uwce_entityName] inManagedObjectContext:context];
		if (keyword)
		{
			keyword.value = keywordValue;
			[item addKeywordsObject:keyword];
			[keyword addItemsObject:item];
			keyword.manifest = shopManifest;
		}
	}
	return keyword;
}

- (NSManagedObjectContext *)readerContext
{
	NSParameterAssert([NSThread isMainThread]);
	return self.database.readerContext;
}

#pragma mark - Assignment

// Start by manipulating the unique value in the request for the manifest to populate your database with multiple manifests

- (void)deleteOldManifests
{
	// Fetch all manifests sorted by created date and delete all but the newest one
	NSManagedObjectContext *context = [self.database childContext];
	[context performBlock:^{
		UWCEShopManifest *manifest = [self currentManifestWithContext:context];
		if (manifest == nil)
		{
			return;
		}
		NSFetchRequest *request = [NSFetchRequest new];
		NSEntityDescription *entity = [NSEntityDescription entityForName:[UWCEShopManifest uwce_entityName] inManagedObjectContext:context];
		request.entity = entity;
		request.predicate = [NSPredicate predicateWithFormat:@"self != %@", manifest];
		NSError *error = nil;
		NSArray *results = [context executeFetchRequest:request error:&error];
		for (NSManagedObject *mo in results)
		{
			[context deleteObject:mo];
		}
		if ([self.database saveContext:context] && [self.database saveWriterContext])
		{
			
		}
	}];
}

- (UWCEShopManifest *)currentManifestWithContext:(NSManagedObjectContext *)context
{
	NSFetchRequest *request = [NSFetchRequest new];
	NSEntityDescription *entity = [NSEntityDescription entityForName:[UWCEShopManifest uwce_entityName] inManagedObjectContext:context];
	request.entity = entity;	
	NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"created" ascending:NO]];
	request.sortDescriptors = sortDescriptors;
	NSError *error = nil;
	NSArray *results = [context executeFetchRequest:request error:&error];
	return [results lastObject];
}

- (UWCEShopManifest *)currentManifest
{
	NSParameterAssert([NSThread isMainThread]);
	return [self currentManifestWithContext:self.readerContext];
}

@end

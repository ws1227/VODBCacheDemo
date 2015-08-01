//
//  VODBCache.m
//  VODBCacheDemo
//
//  Created by Valo on 15/7/31.
//  Copyright (c) 2015年 Valo. All rights reserved.
//

#import "VODBCache.h"
static VODBCache *_sharedCache;

@interface VODBCache ()
@property (nonatomic, copy  ) NSString         *dbPath;   /**< 数据库文件路径 */

@end

@implementation VODBCache
+ (instancetype)sharedCache{
    @synchronized(self){
        if (!_sharedCache) {
            _sharedCache = [[self alloc] init];
        }
    }
    return _sharedCache;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone{
    return [self sharedCache];
}

+ (id)copyWithZone:(struct _NSZone *)zone{
    return [self sharedCache];
}

- (NSString *)dbPath{
    @synchronized(self){
        if (!_dbPath) {
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            NSString *cacheDir  = paths[0];
            _dbPath    = [cacheDir stringByAppendingPathComponent:@"vodbcache.sqlite"] ;
        }
    }
    return _dbPath;
}

- (FMDatabaseQueue *)cacheQueue{
    @synchronized(self){
        if (!_cacheQueue) {
            _cacheQueue = [FMDatabaseQueue databaseQueueWithPath:self.dbPath flags:
                          SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX | SQLITE_OPEN_WAL];
        }
    }
    return _cacheQueue;
}

- (void)clearCacheOnCompletion:(void (^)())completion{
    //1.删除数据库
    [self.cacheQueue close];
    self.cacheQueue = nil;
    NSError *err;
    [[NSFileManager defaultManager] removeItemAtPath:self.dbPath error:&err];
    VOLog(@"delete cache db: %@", err);
}

- (NSUInteger)dbCacheSize{
    //1.数据库文件大小
    NSError *error = nil;
    NSDictionary *dbFileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:self.dbPath error:&error];
    return  (error)? 0: (NSUInteger)dbFileAttrs.fileSize;
}


@end

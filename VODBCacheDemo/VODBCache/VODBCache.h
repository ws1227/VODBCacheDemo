//
//  VODBCache.h
//  VODBCacheDemo
//
//  Created by Valo on 15/7/31.
//  Copyright (c) 2015年 Valo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"
#ifdef VO_DEBUG
#define VOLog( s, ... ) NSLog( @"<%@:(%d)> %@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#define VODebugTimeStart NSDate *debugTimeStart = [NSDate date]
#define VODebugTimeEnd(str)  VOLog(@"(%@)excute time: %@", str, @([[NSDate date] timeIntervalSinceDate:debugTimeStart]))
#else
#define VOLog( s, ... )
#define VODebugTimeStart
#define VODebugTimeEnd(str)

#endif

@interface VODBCache : NSObject

@property (nonatomic, strong) FMDatabaseQueue *cacheQueue;

/**
 *  共享缓存,单例对象
 *
 *  @return 单例对象
 */
+ (instancetype)sharedCache;

/**
 *  清除缓存
 *
 *  @param completion 清除缓存完成后的操作
 */
- (void)clearCacheOnCompletion:(void (^)())completion;

/**
 *  获取缓存大小
 *
 *  @return 缓存数据大小
 */
- (NSUInteger)dbCacheSize;

/**
 *  数据库操作完成后执行的动作
 *
 *  @param db      执行操作的数据库
 *  @param data    数据库操作成功后的block参数
 *  @param success 成功后执行操作,参数为data
 *  @param failure 失败后执行的操作,参数为error
 */
- (void)completionActionWithDB:(FMDatabase *)db
                          data:(id)data
                       success:(void (^)(id data))success
                       failure:(void (^)(NSError *error))failure;

@end

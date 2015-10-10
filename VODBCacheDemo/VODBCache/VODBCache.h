//
//  VODBCache.h
//  VODBCacheDemo
//
//  Created by Valo on 15/7/31.
//  Copyright (c) 2015年 Valo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"

//#define VO_DEBUG
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

@end

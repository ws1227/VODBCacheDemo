//
//  VOURLCache.h
//  VOURLCache
//
//  Created by Valo on 15/8/13.
//  Copyright (c) 2015年 Valo. All rights reserved.
//

#import <Foundation/Foundation.h>

/** 以下2个Key,在NSURLRequest的header中进行设置,用于缓存处理 */
/** 用于设置缓存时间, 0为不缓存*/
FOUNDATION_EXTERN NSString * const VOURLCacheAgeKey;
/** 用于设置是否缓存到磁盘, YES缓存到磁盘,NO不缓存到磁盘*/
FOUNDATION_EXTERN NSString * const VOURLCacheDiskKey;

typedef NS_ENUM(NSUInteger, VOURLCacheType) {
    VOURLCacheTypeUndefined,
    VOURLCacheTypeMemoryAndDisk,
    VOURLCacheTypeMemoryOnly,
    VOURLCacheTypeMemoryNotAllow,
};

@interface VOURLCache : NSURLCache
/** NSURLRequest的header和body中的这些字段对应的参数将不用于生成缓存的key */
@property (nonatomic, strong) NSArray *ignoreRequestFields;
/** 指定缓存的的方式 */
@property (nonatomic, assign) VOURLCacheType cacheType;

@end

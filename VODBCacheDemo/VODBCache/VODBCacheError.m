//
//  VODBCacheError.m
//  VODBCacheDemo
//
//  Created by Valo on 15/8/1.
//  Copyright (c) 2015年 Valo. All rights reserved.
//

#import "VODBCacheError.h"

NSString *const VODBCacheErrorDomain          = @"com.valo.vodbcache";   /**< REAL */

@implementation VODBCacheError

+ (NSError *)errorWithVODBCacheErrorCode:(VODBCacheErrorCode)code{
    NSString *errorString = @"未知错误";
    switch (code) {
        case VODBCacheSuccess: {
            return nil;
        }
        case VODBCacheErrorNoConstraint: {
            errorString = @"无效的约束,或者没有约束字段";
            break;
        }
        case VODBCacheErrorNoCacheField: {
            errorString = @"没有可缓存的字段";
            break;
        }
        case VODBCacheErrorNoCacheObject: {
            errorString = @"没有可缓存的数据";
            break;
        }
        case VODBCacheErrorInvalidValueOrCondition: {
            errorString = @"无效的值或条件";
            break;
        }
            
        case VODBCacheErrorUnknown:
        default:
            break;
    }
    return [NSError errorWithDomain:VODBCacheErrorDomain code:code userInfo:@{@"message":errorString}];
}
@end

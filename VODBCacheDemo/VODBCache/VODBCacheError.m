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
            
            break;
        }
        case VODBCacheErrorNoConstraint: {
            
            break;
        }
        default: {
            break;
        }
    }
    return [NSError errorWithDomain:VODBCacheErrorDomain code:code userInfo:@{@"message":errorString}];
}
@end

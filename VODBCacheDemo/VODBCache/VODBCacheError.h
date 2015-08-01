//
//  VODBCacheError.h
//  VODBCacheDemo
//
//  Created by Valo on 15/8/1.
//  Copyright (c) 2015年 Valo. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, VODBCacheErrorCode) {
    VODBCacheSuccess  = 0,
    
    VODBCacheErrorNoConstraint = 1001,
    VODBCacheErrorNoCacheField,
    VODBCacheErrorNoCacheObject,
    VODBCacheErrorInvalidValueOrCondition,
    
    VODBCacheErrorUnknown = 9999,
};

@interface VODBCacheError : NSObject

+ (NSError *)errorWithVODBCacheErrorCode:(VODBCacheErrorCode)code;

@end

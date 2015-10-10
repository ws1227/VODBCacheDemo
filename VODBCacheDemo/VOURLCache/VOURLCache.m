//
//  VOURLCache.m
//  VOURLCache
//
//  Created by Valo on 15/8/13.
//  Copyright (c) 2015年 Valo. All rights reserved.
//

#import "VOURLCache.h"
#import "AFHTTPRequestOperationManager.h"

NSString * const VOURLCacheAgeKey        = @"vourlcacheage";
NSString * const VOURLCacheTimeKey       = @"vourlcachetime";

@interface AFHTTPRequestOperationManager (VOURLCache)

@end


@implementation AFHTTPRequestOperationManager (VOURLCache)

- (AFHTTPRequestOperation *)HTTPRequestOperationWithHTTPMethod:(NSString *)method
                                                     URLString:(NSString *)URLString
                                                    parameters:(id)parameters
                                                       success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                                                       failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
    NSError *serializationError = nil;
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:method URLString:[[NSURL URLWithString:URLString relativeToURL:self.baseURL] absoluteString] parameters:parameters error:&serializationError];
    if (serializationError) {
        if (failure) {
            dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
                failure(nil, serializationError);
            });
        }
        return nil;
    }
    NSCachedURLResponse *cachedURLResponse = [[VOURLCache sharedURLCache] cachedResponseForRequest:request];
    if (cachedURLResponse){
        NSError *error = nil;
        id responseObject = [self.responseSerializer responseObjectForResponse:cachedURLResponse.response data:cachedURLResponse.data error:&error];
        if (error) {
            if (failure) {
                dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
                    failure(nil, serializationError);
                });
            }
        }
        else{
            if (success) {
                dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
                    success(nil, responseObject);
                });
            }
        }
        return nil;
    }
#pragma clang diagnostic pop
    return [self HTTPRequestOperationWithRequest:request success:success failure:failure];
}

@end


@implementation VOURLCache

+ (void)load{
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    VOURLCache *cache = [[VOURLCache alloc] initWithMemoryCapacity:20 * 1024 * 1024 diskCapacity:200 * 1024 * 1024 diskPath:path];
    [VOURLCache setSharedURLCache:cache];
}

- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request {
    NSURLRequest *cachedRequest = [self cachedRequestFromOriginalRequest:request];
    if (!cachedRequest) {
        return nil;
    }
    NSCachedURLResponse *cachedResponse = [super cachedResponseForRequest:cachedRequest];
    if (cachedResponse) {
        if (!cachedResponse.userInfo) {
            return nil;
        }
        NSInteger cacheAge = [request.allHTTPHeaderFields[VOURLCacheAgeKey] integerValue];
        NSNumber *cacheTimeVal = cachedResponse.userInfo[VOURLCacheTimeKey];
        if (cacheTimeVal && [cacheTimeVal integerValue] + cacheAge > (NSInteger)[[NSDate date] timeIntervalSince1970] ) {
            NSMutableDictionary *userInfo = [cachedResponse.userInfo mutableCopy];
            [userInfo removeObjectForKey:VOURLCacheTimeKey];
            NSURLCacheStoragePolicy storagePolicy = self.cacheType == VOURLCacheTypeUndefined ? cachedResponse.storagePolicy : (NSURLCacheStoragePolicy)(self.cacheType - VOURLCacheTypeMemoryAndDisk);
            NSCachedURLResponse *response = [[NSCachedURLResponse alloc] initWithResponse:cachedResponse.response data:cachedResponse.data userInfo:userInfo storagePolicy:storagePolicy];
            NSLog(@"NSCachedURLResponse:\n%@",[NSJSONSerialization JSONObjectWithData:response.data options:0 error:nil]);
            return response;
        }
        else {
            [self removeCachedResponseForRequest:cachedRequest];
            return nil;
        }
    }
    return nil;
}

- (void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse forRequest:(NSURLRequest *)request{
    // 1.生成实际缓存使用的NSURLRequest
    NSURLRequest *cachedRequest = [self cachedRequestFromOriginalRequest:request];
    if (!cachedRequest) {
        return;
    }
    // 2. 生成实际缓存使用的NSCachedURLResponse
    NSDictionary *userInfo = cachedResponse.userInfo;
    if (!userInfo) {
        userInfo = [NSDictionary dictionary];
    }
    NSMutableDictionary *cacheUserInfo = [userInfo mutableCopy];
    [cacheUserInfo addEntriesFromDictionary:@{VOURLCacheTimeKey:@((NSInteger)[[NSDate date] timeIntervalSince1970])}];
    NSURLCacheStoragePolicy storagePolicy = self.cacheType == VOURLCacheTypeUndefined ? cachedResponse.storagePolicy : (NSURLCacheStoragePolicy)(self.cacheType - VOURLCacheTypeMemoryAndDisk);
    NSCachedURLResponse *realCachedResponse = [[NSCachedURLResponse alloc] initWithResponse:cachedResponse.response data:cachedResponse.data userInfo:cacheUserInfo storagePolicy:storagePolicy];
    // 3.缓存
    [super storeCachedResponse:realCachedResponse forRequest:cachedRequest];
}

- (NSURLRequest *)cachedRequestFromOriginalRequest:(NSURLRequest *)request{
    // 1.检查是否需要缓存
    NSInteger cacheAge = 0;
    id cacheTimeVal     =  request.allHTTPHeaderFields[VOURLCacheAgeKey];
    if (cacheTimeVal) {
        cacheAge = [cacheTimeVal integerValue];
    }
    if (cacheAge <= 0) {
        // 缓存时间<=0时,不进行缓存
        return nil;
    }
    
    NSMutableURLRequest *cachedRequest = [request mutableCopy];
    NSMutableDictionary *allHTTPHeaderFields = [request.allHTTPHeaderFields mutableCopy];
    if (self.ignoreRequestFields) {
        [allHTTPHeaderFields removeObjectsForKeys:self.ignoreRequestFields];
        [cachedRequest setAllHTTPHeaderFields:allHTTPHeaderFields];
    }
    
    if (request.HTTPBody) {
        NSDictionary *body = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
        if (body && [body isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *cachedBody = [body mutableCopy];
            if (self.ignoreRequestFields) {
                [cachedBody removeObjectsForKeys:self.ignoreRequestFields];
                [cachedRequest setHTTPBody:[NSJSONSerialization dataWithJSONObject:cachedBody options:0 error:nil]];
            }
        }
    }
    return cachedRequest;
}



@end


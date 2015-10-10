//
//  VOWeather.m
//  VODBCacheDemo
//
//  Created by Valo on 15/8/3.
//  Copyright (c) 2015年 Valo. All rights reserved.
//

#import "VOWeather.h"

@implementation VOWeather

+ (void)load{
    [self initVODBCache];
}

+ (NSString *)manualTableName{
    return @"weather";
}

- (NSString *)uniquenessConstraint{
    return [NSString stringWithFormat:@"%@%@%@", self.postCode, self.citycode, self.pinyin];
}

+ (NSArray  *)ignoredPropertyNamesForCache{
    return @[@"WD",@"WS"];
}

@end

//
//  VOWeather.h
//  VODBCacheDemo
//
//  Created by Valo on 15/8/3.
//  Copyright (c) 2015年 Valo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NSObject+VODBCache.h"

@interface VOWeather : NSObject

@property (nonatomic, copy) NSString *postCode;

@property (nonatomic, copy) NSString *h_tmp;

@property (nonatomic, copy) NSString *temp;

@property (nonatomic, assign) CGFloat longitude;

@property (nonatomic, copy) NSString *time;

@property (nonatomic, assign) CGFloat latitude;

@property (nonatomic, copy) NSString *l_tmp;

@property (nonatomic, copy) NSString *WD;

@property (nonatomic, copy) NSString *pinyin;

@property (nonatomic, copy) NSString *date;

@property (nonatomic, copy) NSString *weather;

@property (nonatomic, copy) NSString *city;

@property (nonatomic, copy) NSString *citycode;

@property (nonatomic, copy) NSString *WS;

@property (nonatomic, copy) NSString *sunrise;

@property (nonatomic, copy) NSString *altitude;

@property (nonatomic, copy) NSString *sunset;

@end

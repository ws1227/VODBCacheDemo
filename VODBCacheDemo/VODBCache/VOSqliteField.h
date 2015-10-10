//
//  VOSqliteField.h
//  VODBCacheDemo
//
//  Created by Valo on 15/8/3.
//  Copyright (c) 2015年 Valo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VOSqliteField : NSObject

@property (nonatomic, assign) NSInteger cid;
@property (nonatomic, copy  ) NSString  *name;
@property (nonatomic, copy  ) NSString  *type;
@property (nonatomic, assign) BOOL      notnull;
@property (nonatomic, copy  ) NSString  *dflt_value;
@property (nonatomic, assign) BOOL      pk;
@end

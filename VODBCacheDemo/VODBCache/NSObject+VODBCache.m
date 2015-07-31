//
//  NSObject+VODBCache.m
//  VODBCacheDemo
//
//  Created by Valo on 15/7/31.
//  Copyright (c) 2015年 Valo. All rights reserved.
//

#import "NSObject+VODBCache.h"
#import "MJExtension.h"
#import "VODBCache.h"
#import <objc/runtime.h>
#import "VODBCacheError.h"

/**
 *  SQL语句Const
 */
NSString *const SQL_INTEGER       = @"INTEGER NOT NULL DEFAULT 0";  /**< INTEGER */
NSString *const SQL_TEXT          = @"TEXT NOT NULL DEFAULT ''";    /**< TEXT */
NSString *const SQL_REAL          = @"REAL NOT NULL DEFAULT 0.0";   /**< REAL */

NSString *const SQL_ConstraintKey = @"voconstraint";                /**< 主键名,用于唯一性约束 */

static const void *VOConstraintKey = &VOConstraintKey;
static const void *VOCreateTimeKey = &VOCreateTimeKey;
static const void *VOUpdateTimeKey = &VOUpdateTimeKey;

@implementation NSObject (VODBCache)

+ (void)initVODBCache{
    [self createCacheTable];
}

- (void)setVoconstraint:(NSString *)voconstraint{
    objc_setAssociatedObject(self, &VOConstraintKey, voconstraint, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)voconstraint{
    return objc_getAssociatedObject(self, VOConstraintKey);
}

- (void)setVocreatetime:(NSTimeInterval)vocreatetime{
    objc_setAssociatedObject(self, &VOCreateTimeKey, @(vocreatetime), OBJC_ASSOCIATION_ASSIGN);
}

- (NSTimeInterval)vocreatetime{
    return [objc_getAssociatedObject(self, VOCreateTimeKey) floatValue];
}

- (void)setVoupdatetime:(NSTimeInterval)voupdatetime{
    objc_setAssociatedObject(self, &VOUpdateTimeKey, @(voupdatetime), OBJC_ASSOCIATION_ASSIGN);
}

- (NSTimeInterval)voupdatetime{
    return [objc_getAssociatedObject(self, VOUpdateTimeKey) floatValue];
}


#pragma mark - 缓存数据
- (void)cacheObject{
    [self cacheObjectCompletion:nil];
}

- (void)cacheObjectCompletion:(void (^)(id obj, NSError *error))completion{
    // 1.表名
    NSString *tableName = [[self class] dbTableName];
    // 2.生成字段区域和值区域
    NSDictionary *cacheKeyValues = [self insertKeyValues];
    if (!cacheKeyValues) {
        if (completion) {
            completion(self, [VODBCacheError errorWithVODBCacheErrorCode:VODBCacheErrorNoCacheField]);
        }
        return;
    }
    // 3.生成SQL语句
    NSString *sql = [NSString stringWithFormat:@"insert into \"%@\" (%@) values (%@)",tableName, [cacheKeyValues allKeys].firstObject, [cacheKeyValues allValues].firstObject];
    // 4.执行SQL语句
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        BOOL result = [db executeQuery:sql];
        if (result) {
            NSString *query = [NSString stringWithFormat:@"SELECT \"%@\" FROM \"%@\" ORDER BY \"vocreatetime\" DESC LIMIT 0,1", SQL_ConstraintKey, tableName];
            FMResultSet *rs = [db executeQuery:query];
            NSString *constraint = [rs stringForColumnIndex:0];
            if ([self respondsToSelector:@selector(setVoconstraint:)]) {
                [self setVoconstraint:constraint];
            }
        }
        if (completion) {
            completion(self, result ? nil: [db lastError]);
        }
    }];
}

+ (void)cacheObjectArray:(NSArray *)array{
    [self cacheObjectArray:array completion:nil];
}

+ (void)cacheObjectArray:(NSArray *)array completion:(void (^)(NSArray *array, NSError *error))completion{
    // 1.表名
    NSString *tableName = [self dbTableName];
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (id obj in array) {
            if ([obj isKindOfClass:[self class]]) {
                NSDictionary *cacheKeyValues = [obj insertKeyValues];
                if (cacheKeyValues) {
                    // 3.生成SQL语句
                    NSString *sql = [NSString stringWithFormat:@"insert into \"%@\" (%@) values (%@)",tableName, [cacheKeyValues allKeys].firstObject, [cacheKeyValues allValues].firstObject];
                    // 4.执行SQL语句
                    BOOL result = [db executeQuery:sql];
                    if (result) {
                        NSString *query = [NSString stringWithFormat:@"SELECT \"%@\" FROM \"%@\" ORDER BY \"vocreatetime\" DESC LIMIT 0,1", SQL_ConstraintKey, tableName];
                        FMResultSet *rs = [db executeQuery:query];
                        NSString *constraint = [rs stringForColumnIndex:0];
                        if ([obj respondsToSelector:@selector(setVoconstraint:)]) {
                            [obj setVoconstraint:constraint];
                        }
                    }
                }
            }
        }
        *rollback = [db lastErrorCode] == 10;
        if (completion) {
            completion(array, [db lastError]);
        }
    }];
}

- (void)updateCacheObject{
    [self updateCacheObjectCompletion:nil];
}

- (void)updateCacheObjectCompletion:(void (^)(id obj, NSError *error))completion{
    // 1.表名
    NSString *tableName = [[self class] dbTableName];
    // 2.生成字段区域和值区域
    NSString *cacheKeyValues = [self updateKeyValues];
    if (!cacheKeyValues) {
        if (completion) {
            completion(self, [VODBCacheError errorWithVODBCacheErrorCode:VODBCacheErrorNoCacheField]);
        }
        return;
    }
    // 3.生成SQL语句
    NSString *sql = nil;
    sql = [NSString stringWithFormat:@"update \"%@\" SET %@ WHERE %@ = %@",
           tableName,cacheKeyValues, SQL_ConstraintKey,self.voconstraint];
    // 4.执行SQL语句
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        BOOL result = [db executeQuery:sql];
        if (result) {
            NSString *query = [NSString stringWithFormat:@"SELECT \"%@\" FROM \"%@\" ORDER BY \"vocreatetime\" DESC LIMIT 0,1", SQL_ConstraintKey, tableName];
            FMResultSet *rs = [db executeQuery:query];
            NSString *constraint = [rs stringForColumnIndex:0];
            if ([self respondsToSelector:@selector(setVoconstraint:)]) {
                [self setVoconstraint:constraint];
            }
        }
        if (completion) {
            completion(self, result ? nil: [db lastError]);
        }
    }];
}

+ (void)updateCacheObjects:(NSArray *)array withValues:(NSArray *)values completion:(void (^)(id obj, NSError *error))completion{
    // 1.表名
    NSString *tableName = [[self class] dbTableName];
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (id obj in array) {
            if ([obj isKindOfClass:[self class]]) {
                NSString *cacheValues = [self linkStringArrayWithAND:values updateTime:YES];
                if (cacheValues) {
                    // 3.生成SQL语句
                    NSString *sql = [NSString stringWithFormat:@"update \"%@\" SET %@ WHERE %@ = %@",
                                     tableName,cacheValues, SQL_ConstraintKey,self.voconstraint];
                    // 4.执行SQL语句
                    BOOL result = [db executeQuery:sql];
                    if (result) {
                        NSString *query = [NSString stringWithFormat:@"SELECT \"%@\" FROM \"%@\" ORDER BY \"vocreatetime\" DESC LIMIT 0,1", SQL_ConstraintKey, tableName];
                        FMResultSet *rs = [db executeQuery:query];
                        NSString *constraint = [rs stringForColumnIndex:0];
                        if ([obj respondsToSelector:@selector(setVoconstraint:)]) {
                            [obj setVoconstraint:constraint];
                        }
                    }
                }
            }
        }
        *rollback = [db lastErrorCode] == 10;
        if (completion) {
            completion(array, [db lastError]);
        }
    }];
}


+ (void)updateCacheObjectWithValues:(NSArray *)values condition:(NSArray *)condition{
    [self updateCacheObjectWithValues:values condition:condition completion:nil];
}

+ (void)updateCacheObjectWithValues:(NSArray *)values condition:(NSArray *)condition completion:(void (^)(NSArray *array, NSError *error))completion{
    // 1.表名
    NSString *tableName = [[self class] dbTableName];
    // 2.生成字段区域和值区域
    NSString *cacheValues    = [self linkStringArrayWithAND:values updateTime:YES];
    NSString *cacheCondition = [self linkStringArrayWithAND:condition updateTime:NO];
    if (!cacheValues || !cacheCondition) {
        if (completion) {
            completion(nil, [VODBCacheError errorWithVODBCacheErrorCode:VODBCacheErrorInvalidValueOrCondition]);
        }
        return;
    }
    // 3.生成SQL语句
    NSString *sql = nil;
    sql = [NSString stringWithFormat:@"update \"%@\" SET %@ WHERE %@",
           tableName,cacheValues, cacheCondition];
    // 4.执行SQL语句
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        BOOL result = [db executeQuery:sql];
        if (completion) {
            completion(nil, result ? nil: [db lastError]);
        }
    }];
}

#pragma mark - 从缓存中删除数据
- (void)removefromCache{
    [self removefromCacheCompletion:nil];
}

- (void)removefromCacheCompletion:(void (^)(id obj))completion{
    
}

+ (void)objectArrayRemoveFromCache:(NSArray *)array{
    [self objectArrayRemoveFromCache:array completion:nil];
}

+ (void)objectArrayRemoveFromCache:(NSArray *)array completion:(void (^)(NSArray *array))completion{
    
}

#pragma mark - 从缓存中读取数据
+ (void)objectArrayFromCache:(NSString *)sql completion:(void (^)(NSArray *array))completion{
    
}

+ (void)objectArrayFromCache:(NSDictionary *)condition sort:(NSDictionary *)sort start:(NSInteger)start count:(NSInteger)count completion:(void (^)(NSArray *array))completion{
    
}

#pragma mark - 执行指定的操作
+ (void)queryObjectCountInCacheCompletion:(void (^)(NSInteger count))completion{
    
}

+ (void)queryObjectCountInCacheWithCondition:(NSArray *)condition Completion:(void (^)(NSInteger count))completion{
    
}

+ (void)querySQL:(NSString *)sql completion:(void (^)(FMResultSet *rs))completion{
    
}

+ (void)updateSQL:(NSString *)sql completion:(void (^)(BOOL result))completion{
    
}


#pragma mark - 私有方法
/**
 *  在数据库中创建缓存此数据模型的表
 */
+ (void)createCacheTable{
    // 1.遍历成员变量,生成SQL语句创建字段部分,并记录要缓存的属性
    NSMutableString *fieldsSql     = [NSMutableString string];
    NSMutableArray *properties     = [NSMutableArray array];
    [self enumerateProperties:^(MJProperty *property, BOOL *stop) {
        NSString *field = [self fieldSQL:property];
        BOOL skip       = [self ignoreProperty:property];
        // 如果遇到了模型字段，则需要跳过
        if(!field && !skip){
            [fieldsSql appendFormat:@"%@,",field];
            [properties addObject:property];
        }
    }];
    if (fieldsSql.length == 0) {
        VOLog(@"Class \"%@\" 没有要缓存的字段,无需创建表",NSStringFromClass([self class]));
        return;
    }
    // 删除SQL语句创建字段部分的最后一个逗号
    [fieldsSql deleteCharactersInRange:NSMakeRange(fieldsSql.length - 1, 1)];
    // 2.表名
    NSString *tableName = [self dbTableName];
    // 3.唯一性约束,主键(缓存只使用一个主键作为唯一性约束)
    NSString *primeryKey = [NSString stringWithFormat:@",PRIMARY KEY(\"%@\")", SQL_ConstraintKey];
    // 4.创建缓存用的数据表
    NSString *sql =[NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@%@)",tableName, fieldsSql, primeryKey];
    VOLog(@"Class \"%@\"表: %@",NSStringFromClass([self class]),sql);
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        BOOL result =[db executeUpdate:sql];
        VOLog(@"Class \"%@\" 创建表%@!",NSStringFromClass([self class]),result?@"成功":@"失败");
        if (result) {
            [self checkProperties:properties inTable:tableName inDataBase:db];
        }
    }];
}

+ (NSString *)dbTableName{
    NSString *tableName = nil;
    if ([self respondsToSelector:@selector(manualTableName)]) {
        tableName = [self manualTableName];
    }
    if (!tableName || tableName.length == 0) {
        tableName = NSStringFromClass([self class]);
    }
    return tableName;
}

/**
 *  生成SQL语句中创建字段的字符串对("column" type)
 *
 *  @param property 要缓存的属性
 *
 *  @return "column" type 字符串对
 */
+ (NSString *)fieldSQL:(MJProperty *)property{
    NSString *name    = property.name;
    NSString *type    = property.type.code.lowercaseString;
    NSDictionary *map = @{SQL_INTEGER:@[MJTypeInt, MJTypeShort, MJTypeFloat, MJTypeDouble, MJTypeLong, MJTypeChar],
                        SQL_TEXT:@[@"NSString"],
                        SQL_REAL:@[MJTypeBOOL1,MJTypeBOOL2]};
    __block NSString *propertySql = nil ;
    [map enumerateKeysAndObjectsUsingBlock:^(NSString *typeSql, NSArray *mjTypes, BOOL *stop) {
        if ([mjTypes containsObject:type]) {
            propertySql = typeSql;
        }
    }];
    return (propertySql) ? [NSString stringWithFormat:@"\"%@\" \%@",name, propertySql] : nil;
}

/**
 *  转换成创建表的SQL语句时,是否忽略该属性
 *
 *  @param property 字段属性
 *
 *  @return 是-忽略,否-转换
 */
+ (BOOL)ignoreProperty:(MJProperty *)property{
    // 默认忽略项
    NSArray *ignoredPropertyNames = @[@"hash",@"superclass",@"description",@"debugDescription"];
    // 自定义忽略项
    if ([self respondsToSelector:@selector(ignoredPropertyNamesForCache)]) {
        ignoredPropertyNames = [ignoredPropertyNames arrayByAddingObjectsFromArray:[self ignoredPropertyNamesForCache]];
    }
    return [ignoredPropertyNames containsObject:property.name];
}

/**
 *  检查缓存的属性值,如果缓存数据表中不存在相应的字段,则添加该字段
 *
 *  @param properties 要检查的属性值数组
 *  @param table      指定的数据表名
 *  @param db         指定的数据库
 */
+ (void)checkProperties:(NSArray *)properties inTable:(NSString *)table inDataBase:(FMDatabase *)db{
    NSArray *columns = [self columnsInTable:table inDataBase:db];
    // 1.添加缺失的字段
    for (MJProperty *property in properties) {
        BOOL found = NO;
        for (NSString *field in columns) {
            if ([property.name isEqualToString:field]) {
                found = YES;
                break;
            }
        }
        BOOL ignore = [self ignoreProperty:property];
        if (!found && !ignore) {
            BOOL result = NO;
            NSString *fieldSQL = [self fieldSQL:property];
            if (fieldSQL && fieldSQL.length > 0) {
                NSString *sql = [NSString stringWithFormat:@"ALTER TABLE \"%@\" ADD COLUMN %@",table,fieldSQL];
                result =[db executeUpdate:sql];
            }
            VOLog(@"新增字段%@:%@",result?@"成功":@"失败", property.name);
        }
    }
    // 2.删除列
    //IGNORE:因为sqlite不支持删除列,所以保持冗余列.可以采用清除缓存(删除数据库),重新创建的方式清除冗余列.
}

/**
 *  查询指定数据库中指定表所拥有的字段名
 *
 *  @param table 指定表名
 *  @param db    指定数据库
 *
 *  @return 数据表的字段名数组
 */
+ (NSArray *)columnsInTable:(NSString *)table inDataBase:(FMDatabase *)db{
    NSMutableArray *columns=[NSMutableArray array];
    NSString *sql=[NSString stringWithFormat:@"PRAGMA table_info (\"%@\");",table];
    FMResultSet *rs = [db executeQuery:sql];
    while ([rs next]) {
        NSString *col = [rs stringForColumn:@"name"];
        if (col && col.length > 0) {
            [columns addObject:col];
        }
    }
    return columns;
}

/**
 *  根据对象生成SQL插入数据语句的字段区域和值区域,count为0时无效
 *
 *  @return SQL语句的字段区域和值区域.key表示字段区域,value表示值区域
 */
- (NSDictionary *)insertKeyValues{
    NSMutableString *keys   = [NSMutableString string];
    NSMutableString *values = [NSMutableString string];
    self.vocreatetime = [[NSDate date] timeIntervalSince1970];
    self.voupdatetime = self.vocreatetime;
    NSMutableDictionary *keyValues = self.keyValues;
    NSArray *uniqueKeys = nil;
    NSMutableString *uniqueValue = [NSMutableString string];
    if ([self respondsToSelector:@selector(uniqueKeyPropertyNames)]) {
        uniqueKeys = [[self class] uniqueKeyPropertyNames];
    }
    [keyValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if (obj && ![obj isEqual:[NSNull null]] && ![key isEqualToString:SQL_ConstraintKey]) {
            if ([obj isKindOfClass:[NSString class]] && [obj length] > 0  && ![obj isEqualToString:@"(null)"] ) {
                NSString *val = [obj stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
                [keys appendFormat:@"\"%@\",", key];
                [values appendFormat:@"\"%@\",", val];
                if (uniqueKeys && [uniqueKeys containsObject:key]) {
                    [uniqueValue appendString:val];
                }
            }
            if ([obj isKindOfClass:[NSNumber class]]) {
                [keys appendFormat:@"\"%@\",", key];
                [values appendFormat:@"%@,", obj];
                if (uniqueKeys && [uniqueKeys containsObject:key]) {
                    [uniqueValue appendFormat:@"%@,", obj];
                }
            }
        }
    }];
    if (uniqueValue.length > 0) {
        [keys appendFormat:@"\"%@\",", SQL_ConstraintKey];
        [values appendFormat:@"\"%@\",", uniqueValue];
    }
    if (keys.length > 0 && values.length > 0) {
        [keys deleteCharactersInRange:NSMakeRange(keys.length - 1, 1)];
        [values deleteCharactersInRange:NSMakeRange(keys.length - 1, 1)];
    }
    
    return (keys.length > 0 && values.length > 0)? @{keys:values} : nil;
}

/**
 *  根据对象生成SQL更新数据语句的字段和值区域
 *
 *  @return SQL语句的字段和值区域, nil时无效
 */
- (NSString *)updateKeyValues{
    self.voupdatetime = [[NSDate date] timeIntervalSince1970];
    NSMutableString *updateString = [NSMutableString string];
    NSMutableDictionary *keyValues = self.keyValues;
    NSArray *allowPropertyNames = nil;
    if ([[self class] respondsToSelector:@selector(allowUpdatePropertyNamesForCache)]) {
        allowPropertyNames = [[self class] allowUpdatePropertyNamesForCache];
    }
    if (allowPropertyNames && allowPropertyNames.count > 0) {
        NSMutableArray *removeKeys = [[keyValues allKeys] mutableCopy];
        [removeKeys removeObjectsInArray:allowPropertyNames];
        [keyValues removeObjectsForKeys:removeKeys];
    }
    [keyValues removeObjectForKey:SQL_ConstraintKey];
    [keyValues enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (obj && ![obj isEqual:[NSNull null]]) {
            if ([obj isKindOfClass:[NSString class]] && [obj length] > 0  && ![obj isEqualToString:@"(null)"] ) {
                NSString *val = [obj stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
                [updateString appendFormat:@"\"%@\" = \"%@\" AND ",key,val];
            }
            if ([obj isKindOfClass:[NSNumber class]]) {
                [updateString appendFormat:@"\"%@\" = \"%@\" AND ",key,obj];
            }
        }
    }];
    if (updateString.length > 5) {
        [updateString deleteCharactersInRange:NSMakeRange(updateString.length - 5, 5)];
    }
    else{
        updateString = nil;
    }
    
    return updateString;
}

+ (NSString *)linkStringArrayWithAND:(NSArray *)array updateTime:(BOOL)flag{
    if (!array || array.count == 0) {
        return nil;
    }
    NSMutableString *resultString = [NSMutableString string];
    [array enumerateObjectsUsingBlock:^(NSString *str, NSUInteger idx, BOOL *stop) {
        [resultString appendFormat:@"\"%@\" AND ", str];
    }];
    if (flag) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        [resultString appendFormat:@"\"voupdatetime\" = %@ AND ", @(now)];
    }
    if (resultString.length > 5) {
        [resultString deleteCharactersInRange:NSMakeRange(resultString.length - 5, 5)];
    }
    else{
        resultString = nil;
    }
    return resultString;
}

@end

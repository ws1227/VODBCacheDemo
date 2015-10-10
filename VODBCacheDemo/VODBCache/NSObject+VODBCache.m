//
//  NSObject+VODBCache.m
//  VODBCacheDemo
//
//  Created by Valo on 15/7/31.
//  Copyright (c) 2015年 Valo. All rights reserved.
//

#import "NSObject+VODBCache.h"
#import <objc/runtime.h>
#import "VOSqliteField.h"

/**
 *  SQL语句Const
 */
NSString *const SQL_INTEGER       = @"INTEGER NOT NULL DEFAULT 0";  /**< INTEGER */
NSString *const SQL_TEXT          = @"TEXT NOT NULL DEFAULT ''";    /**< TEXT */
NSString *const SQL_REAL          = @"REAL NOT NULL DEFAULT 0.0";   /**< REAL */

NSString *const VODBConstraint = @"voconstraint";                /**< 主键名,用于唯一性约束 */
NSString *const VODBCreateTime = @"vocreatetime";                /**< 创建时间 */
NSString *const VODBUpdateTime = @"voupdatetime";                /**< 最后一次修改时间 */

static const void *VOConstraintKey = &VOConstraintKey;
static const void *VOCreateTimeKey = &VOCreateTimeKey;
static const void *VOUpdateTimeKey = &VOUpdateTimeKey;

@implementation NSObject (VODBCache)

#pragma mark - 初始化
+ (void)initVODBCache{
    [self createCacheTable];
}

#pragma mark - 附加属性
- (void)setVoconstraint:(NSString *)voconstraint{
    objc_setAssociatedObject(self, &VOConstraintKey, voconstraint, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)voconstraint{
    return objc_getAssociatedObject(self, VOConstraintKey);
}

- (void)setVocreatetime:(NSTimeInterval)vocreatetime{
    objc_setAssociatedObject(self, &VOCreateTimeKey, @(vocreatetime), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSTimeInterval)vocreatetime{
    return [objc_getAssociatedObject(self, VOCreateTimeKey) doubleValue];
}

- (void)setVoupdatetime:(NSTimeInterval)voupdatetime{
    objc_setAssociatedObject(self, &VOUpdateTimeKey, @(voupdatetime), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSTimeInterval)voupdatetime{
    return [objc_getAssociatedObject(self, VOUpdateTimeKey) doubleValue];
}

#pragma mark - 缓存数据
- (void)cacheObject{
    [self cacheObjectSuccess:nil failure:nil];
}

- (void)cacheObjectSuccess:(void (^)(id data))success
                   failure:(void (^)(NSError *error))failure{
    [self cacheObjectUpdateWhenConflict:NO success:success failure:failure];
}

- (void)cacheObjectUpdateWhenConflict:(BOOL)update
                              success:(void (^)(id data))success
                              failure:(void (^)(NSError *error))failure{
    // 1.表名
    NSString *tableName = [[self class] dbTableName];
    // 2.生成字段区域和值区域
    NSDictionary *cacheKeyValues = [self insertKeyValues];
    if (!cacheKeyValues) {
        NSError *error = [VODBCacheError errorWithVODBCacheErrorCode:VODBCacheErrorNoCacheField];
        [[self class] completionActionWithDB:nil data:error success:success failure:failure];
        return;
    }
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        // 3.生成SQL语句
        NSString *sql = [NSString stringWithFormat:@"insert into \"%@\" (%@) values (%@)",tableName, [cacheKeyValues allKeys].firstObject, [cacheKeyValues allValues].firstObject];
        // 4.执行SQL语句
        [db executeUpdate:sql];
        // 5.检查是否需要update
        if (update && [db lastErrorCode] == 19) {
            NSString *cacheKeyValues = [self updateKeyValues];
            if (cacheKeyValues) {
                // 生成update SQL语句
                sql = [NSString stringWithFormat:@"update \"%@\" SET %@ WHERE \"%@\" = \"%@\"",
                       tableName,cacheKeyValues, VODBConstraint,self.voconstraint];
                [db executeUpdate:sql];
            }
        }
        [[self class] completionActionWithDB:db data:self success:success failure:failure];
        *rollback = [db lastErrorCode] == 10;
    }];
}

+ (void)cacheObjects:(NSArray *)array{
    [self cacheObjects:array success:nil failure:nil];
}

+ (void)cacheObjects:(NSArray *)array
             success:(void (^)(NSArray *array))success
             failure:(void (^)(NSError *error))failure{
    return [self cacheObjects:array updateWhenConflict:NO success:success failure:failure];
}

+ (void)cacheObjects:(NSArray *)array
  updateWhenConflict:(BOOL)update
             success:(void (^)(NSArray *array))success
             failure:(void (^)(NSError *error))failure{
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
                    [db executeUpdate:sql];
                    // 5.检查是否需要update
                    if (update && [db lastErrorCode] == 19) {
                        NSString *cacheKeyValues = [obj updateKeyValues];
                        if (cacheKeyValues) {
                            // 生成update SQL语句
                            sql = [NSString stringWithFormat:@"update \"%@\" SET %@ WHERE \"%@\" = \"%@\"",
                                   tableName,cacheKeyValues, VODBConstraint,[obj voconstraint]];
                            [db executeUpdate:sql];
                        }
                    }
                }
            }
        }
        [self completionActionWithDB:db data:array success:success failure:failure];
        *rollback = [db lastErrorCode] == 10;
    }];
}

#pragma mark - 更新数据
- (void)updateCacheObject{
    [self updateCacheObjectSuccess:nil failure:nil];
}

- (void)updateCacheObjectSuccess:(void (^)(id))success failure:(void (^)(NSError *))failure{
    // 1.表名
    NSString *tableName = [[self class] dbTableName];
    // 2.生成字段区域和值区域
    NSString *cacheKeyValues = [self updateKeyValues];
    if (!cacheKeyValues) {
        NSError *error = [VODBCacheError errorWithVODBCacheErrorCode:VODBCacheErrorNoCacheField];
        [[self class] completionActionWithDB:nil data:error success:success failure:failure];
        return;
    }
    // 3.生成SQL语句
    NSString *sql = nil;
    sql = [NSString stringWithFormat:@"update \"%@\" SET %@ WHERE \"%@\" = \"%@\"",
           tableName,cacheKeyValues, VODBConstraint,self.voconstraint];
    // 4.执行SQL语句
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:sql];
        [[self class] completionActionWithDB:db data:self success:success failure:failure];
    }];
}

+ (void)updateCacheObjects:(NSArray *)array withValues:(NSArray *)values success:(void (^)(NSArray *array))success failure:(void (^)(NSError *error))failure{
    // 1.表名
    NSString *tableName = [[self class] dbTableName];
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (id obj in array) {
            if ([obj isKindOfClass:[self class]]) {
                NSString *cacheValues = [self linkStringArray:values withComponent:@"," updateTime:YES];
                if (cacheValues) {
                    // 3.生成SQL语句
                    NSString *sql = [NSString stringWithFormat:@"update \"%@\" SET %@ WHERE \"%@\" = \"%@\"",
                                     tableName,cacheValues, VODBConstraint,self.voconstraint];
                    // 4.执行SQL语句
                    [db executeUpdate:sql];
                }
            }
        }
        *rollback = [db lastErrorCode] == 10;
        [self completionActionWithDB:db data:array success:success failure:failure];
    }];
}


+ (void)updateCacheObjectsWithValues:(NSArray *)values condition:(NSArray *)condition{
    [self updateCacheObjectsWithValues:values condition:condition success:nil failure:nil];
}

+ (void)updateCacheObjectsWithValues:(NSArray *)values condition:(NSArray *)condition success:(void (^)(NSArray *array))success failure:(void (^)(NSError *error))failure{
    // 1.表名
    NSString *tableName = [[self class] dbTableName];
    // 2.生成字段区域和值区域
    NSString *cacheValues    = [self linkStringArray:values withComponent:@"," updateTime:YES];
    NSString *cacheCondition = [self linkStringArray:condition withComponent:@"AND" updateTime:NO];
    if (!cacheValues || !cacheCondition) {
        NSError *error = [VODBCacheError errorWithVODBCacheErrorCode:VODBCacheErrorInvalidValueOrCondition];
        [self completionActionWithDB:nil data:error success:success failure:failure];
        return;
    }
    // 3.生成SQL语句
    NSString *sql = nil;
    sql = [NSString stringWithFormat:@"update \"%@\" SET %@ WHERE %@",
           tableName,cacheValues, cacheCondition];
    // 4.执行SQL语句
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:sql];
        [self completionActionWithDB:db data:nil success:success failure:failure];
    }];
}

#pragma mark - 从缓存中删除数据
- (void)removefromCache{
    [self removefromCacheSuccess:nil failure:nil];
}

- (void)removefromCacheSuccess:(void (^)(id obj))success failure:(void (^)(NSError *error))failure{
    // 1.表名
    NSString *tableName = [[self class] dbTableName];
    if (!self.voconstraint) {
        NSError *error = [VODBCacheError errorWithVODBCacheErrorCode:VODBCacheErrorNoConstraint];
        [[self class] completionActionWithDB:nil data:error success:success failure:failure];
        return;
    }
    // 2.生成SQL语句
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" WHERE \"%@\" = \"%@\"", tableName, VODBConstraint, self.voconstraint];
    // 3.执行SQL语句
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:sql];
        [[self class] completionActionWithDB:db data:self success:success failure:failure];
    }];
}

+ (void)removeAllCachedObjectsSuccess:(void (^)(NSArray *array))success
                              failure:(void (^)(NSError *error))failure{
    NSString *tableName = [[self class] dbTableName];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\"", tableName];
    // 3.执行SQL语句
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:sql];
        [self completionActionWithDB:db data:self success:success failure:failure];
    }];
}

+ (void)removeCachedObjects:(NSArray *)array{
    [self removeCachedObjects:array success:nil failure:nil];
}

+ (void)removeCachedObjects:(NSArray *)array
                    success:(void (^)(NSArray *array))success
                    failure:(void (^)(NSError *error))failure{
    // 1.表名
    NSString *tableName = [[self class] dbTableName];
    // 2.生成SQL语句
    NSMutableString *constaintStr = [NSMutableString string];
    if (array && array.count > 0) {
        for (id obj in array) {
            if (obj && [obj respondsToSelector:@selector(voconstraint)]) {
                [constaintStr appendFormat:@"\"%@\",",[obj voconstraint]];
            }
        }
    }
    if (constaintStr.length <= 1) {
        NSError *error = [VODBCacheError errorWithVODBCacheErrorCode:VODBCacheErrorNoCacheObject];
        [self completionActionWithDB:nil data:error success:success failure:failure];
        return;
    }
    [constaintStr deleteCharactersInRange:NSMakeRange(constaintStr.length - 1, 1)];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" WHERE \"%@\" IN (%@)", tableName, VODBConstraint, constaintStr];
    // 3.执行SQL语句
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:sql];
        [self completionActionWithDB:db data:self success:success failure:failure];
    }];
}

+ (void)removeCachedObjectsWithCondition:(NSArray *)condition
                                 success:(void (^)(NSArray *array))success
                                 failure:(void (^)(NSError *error))failure{
    // 1.表名
    NSString *tableName = [[self class] dbTableName];
    // 2.生成SQL语句
    NSString *conditionStr = [self linkStringArray:condition withComponent:@"AND" updateTime:NO];
    if (!conditionStr) {
        NSError *error = [VODBCacheError errorWithVODBCacheErrorCode:VODBCacheErrorInvalidValueOrCondition];
        [self completionActionWithDB:nil data:error success:success failure:failure];
        return;
    }
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" WHERE %@", tableName, conditionStr];
    // 3.执行SQL语句
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:sql];
        [self completionActionWithDB:db data:nil success:success failure:failure];
    }];
}


#pragma mark - 从缓存中读取数据
+ (void)objectsFromCacheWithSQL:(NSString *)sql
                        success:(void (^)(NSArray *array))success
                        failure:(void (^)(NSError *error))failure{
    // 1.执行SQL语句
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *rs = [db executeQuery:sql];
        NSMutableArray *array = [NSMutableArray array];
        while ([rs next]) {
            id obj = [[self class] objectWithKeyValues:rs.resultDictionary];
            if (obj) {
                if ([obj respondsToSelector:@selector(setVoconstraint:)]) {
                    [obj setVoconstraint: [rs stringForColumn:VODBConstraint]];
                }
                if ([obj respondsToSelector:@selector(setVocreatetime:)]) {
                    [obj setVocreatetime: [rs doubleForColumn:VODBCreateTime]];
                }
                if ([obj respondsToSelector:@selector(setVoupdatetime:)]) {
                    [obj setVoupdatetime: [rs doubleForColumn:VODBUpdateTime]];
                }
                [array addObject:obj];
            }
        }
        [self completionActionWithDB:db data:array success:success failure:failure];
    }];
}

+ (void)objectsFromCacheWithCondition:(NSArray *)condition
                                 sort:(NSArray *)sort
                                start:(NSInteger)start
                                count:(NSInteger)count
                              success:(void (^)(NSArray *array))success
                              failure:(void (^)(NSError *error))failure{
    // 1.表名
    NSString *tableName = [[self class] dbTableName];
    // 2.生成SQL语句
    NSMutableString *sql = [NSMutableString stringWithFormat:@"SELECT * FROM \"%@\"", tableName];
    NSString *conditionStr = [self linkStringArray:condition withComponent:@"AND" updateTime:NO];
    NSString *sortStr      = [self linkStringArray:sort withComponent:@"AND" updateTime:NO];
    if (conditionStr) {
        [sql appendFormat:@" WHERE %@", conditionStr];
    }
    if (sortStr) {
        [sql appendFormat:@" ORDER BY %@", sortStr];
    }
    [sql appendFormat:@" LIMIT %@,%@", @(start), @(count)];
    // 3.执行SQL语句
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *rs = [db executeQuery:sql];
        NSMutableArray *array = [NSMutableArray array];
        while ([rs next]) {
            id obj = [[self class] objectWithKeyValues:rs.resultDictionary];
            if (obj) {
                if ([obj respondsToSelector:@selector(setVoconstraint:)]) {
                    [obj setVoconstraint: [rs stringForColumn:VODBConstraint]];
                }
                if ([obj respondsToSelector:@selector(setVocreatetime:)]) {
                    [obj setVocreatetime: [rs doubleForColumn:VODBCreateTime]];
                }
                if ([obj respondsToSelector:@selector(setVoupdatetime:)]) {
                    [obj setVoupdatetime: [rs doubleForColumn:VODBUpdateTime]];
                }
                [array addObject:obj];
            }
        }
        [self completionActionWithDB:db data:array success:success failure:failure];
    }];
}

#pragma mark - 执行指定的操作
+ (void)queryObjectsCountInCacheSuccess:(void (^)(NSNumber *count))success
                                failure:(void (^)(NSError *error))failure{
    // 1.表名
    NSString *tableName = [[self class] dbTableName];
    // 2.生成SQL语句
    NSString *sql = [NSString stringWithFormat:@"SELECT count(*) FROM \"%@\"", tableName];
    // 3.执行SQL语句
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *rs = [db executeQuery:sql];
        NSInteger count = 0;
        while ([rs next]) {
            count = [rs longForColumnIndex:0];
        }
        [self completionActionWithDB:db data:@(count) success:success failure:failure];
    }];
}

+ (void)queryObjectsCountInCacheWithCondition:(NSArray *)condition
                                     success:(void (^)(NSNumber *count))success
                                      failure:(void (^)(NSError *error))failure{
    // 1.表名
    NSString *tableName = [[self class] dbTableName];
    // 2.生成SQL语句
    NSString *conditionStr = [self linkStringArray:condition withComponent:@"AND" updateTime:NO];
    if (!conditionStr) {
        NSError *error = [VODBCacheError errorWithVODBCacheErrorCode:VODBCacheErrorInvalidValueOrCondition];
        [self completionActionWithDB:nil data:error success:success failure:failure];
        return;
    }
    NSString *sql = [NSString stringWithFormat:@"SELECT count(*) FROM \"%@\" WHERE %@", tableName, conditionStr];
    // 3.执行SQL语句
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *rs = [db executeQuery:sql];
        NSInteger count = 0;
        while ([rs next]) {
            count = [rs longForColumnIndex:0];
        }
        [self completionActionWithDB:db data:@(count) success:success failure:failure];
    }];
}

+ (void)querySQL:(NSString *)sql
         success:(void (^)(FMResultSet *rs))success
         failure:(void (^)(NSError *error))failure{
    // 1.执行SQL语句
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *rs = [db executeQuery:sql];
        [self completionActionWithDB:db data:rs success:success failure:failure];
    }];
}

+ (void)updateSQL:(NSString *)sql
          success:(void (^)(NSNumber  *result))success
          failure:(void (^)(NSError *error))failure{
    // 1.执行SQL语句
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        BOOL result = [db executeUpdate:sql];
        [self completionActionWithDB:db data:@(result) success:success failure:failure];
    }];
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
        if(field && !skip){
            [fieldsSql appendFormat:@"%@,",field];
            [properties addObject:property];
        }
    }];
    if (fieldsSql.length == 0) {
        VOLog(@"Class \"%@\" 没有要缓存的字段,无需创建表",NSStringFromClass([self class]));
        return;
    }
    // 2.创建时间和最后一次更新时间
    [fieldsSql appendFormat:@"\"%@\" INTEGER NOT NULL DEFAULT 0,", VODBCreateTime];
    [fieldsSql appendFormat:@"\"%@\" INTEGER NOT NULL DEFAULT 0,", VODBUpdateTime];
    // 3.唯一性约束,主键(缓存只使用一个主键作为唯一性约束)
    if ([[self class] instancesRespondToSelector:@selector(uniquenessConstraint)]) {
        [fieldsSql appendFormat:@"\"%@\" TEXT NOT NULL ON CONFLICT FAIL PRIMARY KEY", VODBConstraint];
    }
    else{
        [fieldsSql appendFormat:@"\"%@\" INTEGER NOT NULL ON CONFLICT FAIL PRIMARY KEY AUTOINCREMENT", VODBConstraint];
    }

    // 4.表名
    NSString *tableName = [self dbTableName];
    // 5.创建缓存用的数据表
    NSString *sql =[NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@)",tableName, fieldsSql];
    VOLog(@"Class \"%@\"表: %@",NSStringFromClass([self class]),sql);
    [[VODBCache sharedCache].cacheQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        BOOL result =[db executeUpdate:sql];
        VOLog(@"Class \"%@\" 创建表%@!",NSStringFromClass([self class]),result?@"成功":@"失败");
        if (result) {
            [self checkProperties:properties inTable:tableName inDataBase:db];
        }
    }];
}

/**
 *  数据库操作完成后执行的动作
 *
 *  @param db      执行操作的数据库,若为nil,则用data传入自定义错误
 *  @param data    数据库操作成功后的block参数,db为空时传入自定义错误
 *  @param success 成功后执行操作,参数为data
 *  @param failure 失败后执行的操作,参数为error
 */
+ (void)completionActionWithDB:(FMDatabase *)db
                          data:(id)data
                       success:(void (^)(id data))success
                       failure:(void (^)(NSError *error))failure{
    NSError *error = db ? [db lastError] : ((data && [data isKindOfClass:[NSError class]]) ? data : [VODBCacheError errorWithVODBCacheErrorCode:VODBCacheErrorUnknown]);
    /** 数据库错误只考虑IO类型,自定义错误则处理所有 */
    if ((db && error && error.code == 10) || (!db && error)) {
        if (failure) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(error);
            });
        }
    }
    else{
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                success(data);
            });
        }
    }
}

/**
 *  返回当前缓存Class对应的数据表名
 *
 *  @return 数据表名
 */
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


+ (NSString *)fieldType:(MJProperty *)property{
    NSString *type    = property.type.code.lowercaseString;
    NSDictionary *map = @{@"integer":@[MJPropertyTypeInt, MJPropertyTypeShort, MJPropertyTypeFloat, MJPropertyTypeDouble, MJPropertyTypeLong, MJPropertyTypeChar],
                          @"text":@[@"NSString", @"nsstring"],
                          @"real":@[MJPropertyTypeBOOL1,MJPropertyTypeBOOL2]};
    __block NSString *sqliteType = nil ;
    [map enumerateKeysAndObjectsUsingBlock:^(NSString *typeSql, NSArray *mjTypes, BOOL *stop) {
        if ([mjTypes containsObject:type]) {
            sqliteType = typeSql;
            *stop = YES;
        }
    }];
    return (sqliteType) ? sqliteType : nil;
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
    if ([self respondsToSelector:@selector(replacedKeyFromPropertyName)]) {
        NSDictionary *dic = [self performSelector:@selector(replacedKeyFromPropertyName)];
        if (dic[name]) {
            name = dic[name];
        }
    }
    NSString *type    = property.type.code.lowercaseString;
    NSDictionary *map = @{SQL_INTEGER:@[MJPropertyTypeInt, MJPropertyTypeShort, MJPropertyTypeFloat, MJPropertyTypeDouble, MJPropertyTypeLong,MJPropertyTypeLongLong, MJPropertyTypeChar],
                        SQL_TEXT:@[@"NSString", @"nsstring"],
                        SQL_REAL:@[MJPropertyTypeBOOL1,MJPropertyTypeBOOL2]};
    __block NSString *propertySql = nil ;
    [map enumerateKeysAndObjectsUsingBlock:^(NSString *typeSql, NSArray *mjTypes, BOOL *stop) {
        if ([mjTypes containsObject:type]) {
            propertySql = typeSql;
            *stop = YES;
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
+ (BOOL)checkProperties:(NSArray *)properties inTable:(NSString *)table inDataBase:(FMDatabase *)db{
    NSArray *fields = [self fieldsInTable:table inDataBase:db];
    // 1.添加缺失的字段
    for (MJProperty *property in properties) {
        NSString *checkName = [[self class] originalFieldName:property.name];
        VOSqliteField *found = nil;
        for (VOSqliteField *field in fields) {
            if ([checkName isEqualToString:field.name]) {
                found = field;
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
            if(result){} //NO warning
            VOLog(@"新增字段%@:%@",result?@"成功":@"失败", property.name);
        }
    }
    // 2.删除列
    //IGNORE:因为sqlite不支持删除列,所以保持冗余列.可以采用清除缓存(删除数据库),重新创建的方式清除冗余列.
    return NO;
}

/**
 *  查询指定数据库中指定表所拥有的字段名
 *
 *  @param table 指定表名
 *  @param db    指定数据库
 *
 *  @return 数据表中的字段
 */
+ (NSArray *)fieldsInTable:(NSString *)table inDataBase:(FMDatabase *)db{
    NSMutableArray *columns=[NSMutableArray array];
    NSString *sql=[NSString stringWithFormat:@"PRAGMA table_info (\"%@\");",table];
    FMResultSet *rs = [db executeQuery:sql];
    while ([rs next]) {
        VOSqliteField *field = [VOSqliteField objectWithKeyValues:rs.resultDictionary];
        if (field) {
            [columns addObject:field];
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
    NSMutableDictionary *keyValues = self.keyValues;
    NSArray *ignoreKeys = [NSArray array];
    if ([[self class] respondsToSelector:@selector(ignoredPropertyNamesForCache)]) {
        ignoreKeys = [[self class] ignoredPropertyNamesForCache];
    }
    [keyValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        NSString *newKey = [[self class] originalFieldName:key];
         if (obj && ![obj isEqual:[NSNull null]] && ![ignoreKeys containsObject:key]) {
            if ([obj isKindOfClass:[NSString class]] && [obj length] > 0  && ![obj isEqualToString:@"(null)"] ) {
                NSString *val = [[self class] convertToEscapeString:obj];
                [keys appendFormat:@"\"%@\",", newKey];
                [values appendFormat:@"\"%@\",", val];
            }
            if ([obj isKindOfClass:[NSNumber class]]) {
                [keys appendFormat:@"\"%@\",", newKey];
                [values appendFormat:@"%@,", obj];
            }
        }
    }];
    NSString *uniqueValue = nil;
    if ([self respondsToSelector:@selector(uniquenessConstraint)]) {
        uniqueValue = [self uniquenessConstraint];
    }
    if (uniqueValue && uniqueValue.length > 0) {
        [keys appendFormat:@"\"%@\",", VODBConstraint];
        [values appendFormat:@"\"%@\",", uniqueValue];
        self.voconstraint = uniqueValue;
    }
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    self.vocreatetime = now;
    self.voupdatetime = now;
    [keys appendFormat:@"\"%@\",", VODBCreateTime];
    [values appendFormat:@"%@,", @(now)];
    [keys appendFormat:@"\"%@\",", VODBUpdateTime];
    [values appendFormat:@"%@,", @(now)];
    if (keys.length > 0 && values.length > 0) {
        [keys deleteCharactersInRange:NSMakeRange(keys.length - 1, 1)];
        [values deleteCharactersInRange:NSMakeRange(values.length - 1, 1)];
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
    NSArray *ignoredNames = nil;        /** 不缓存的属性 */
    NSArray *ignoredUpdateNames = nil;  /** 不更新的属性 */
    NSArray *allowUpdateNames = nil;    /** 只更新这些属性 */
    if ([[self class] respondsToSelector:@selector(ignoredPropertyNamesForCache)]) {
        ignoredNames = [[self class] ignoredPropertyNamesForCache];
    }
    if ([[self class] respondsToSelector:@selector(ignoredUpdatePropertyNamesForCache)]) {
        ignoredUpdateNames = [[self class] ignoredUpdatePropertyNamesForCache];
    }
    if ([[self class] respondsToSelector:@selector(allowUpdatePropertyNamesForCache)]) {
        allowUpdateNames = [[self class] allowUpdatePropertyNamesForCache];
    }
    if (ignoredNames && ignoredNames.count > 0){
        [keyValues removeObjectsForKeys:ignoredNames];
    }
    if (ignoredUpdateNames && ignoredUpdateNames.count > 0){
        [keyValues removeObjectsForKeys:ignoredUpdateNames];
    }
    else if (allowUpdateNames && allowUpdateNames.count > 0) {
        NSMutableArray *removeKeys = [[keyValues allKeys] mutableCopy];
        [removeKeys removeObjectsInArray:allowUpdateNames];
        [keyValues removeObjectsForKeys:removeKeys];
    }
    [keyValues removeObjectForKey:VODBConstraint];
    [keyValues enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *newKey = [[self class] originalFieldName:key];
        if (obj && ![obj isEqual:[NSNull null]]) {
            if ([obj isKindOfClass:[NSString class]] && [obj length] > 0  && ![obj isEqualToString:@"(null)"] ) {
                NSString *val = [[self class] convertToEscapeString:obj];
                [updateString appendFormat:@"\"%@\" = \"%@\" , ",newKey,val];
            }
            if ([obj isKindOfClass:[NSNumber class]]) {
                [updateString appendFormat:@"\"%@\" = \"%@\" , ",newKey,obj];
            }
        }
    }];
    if (updateString.length > 3) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        self.vocreatetime = now;
        [updateString appendFormat:@"\"%@\" = \"%@\"",VODBUpdateTime,@(now)];
    }
    else{
        updateString = nil;
    }
    
    return updateString;
}

+ (NSString *)originalFieldName:(NSString *)name{
    NSString *origName = name;
    if ([self respondsToSelector:@selector(replacedKeyFromPropertyName)]) {
        NSDictionary *dic = [self performSelector:@selector(replacedKeyFromPropertyName)];
        if (dic[name]) {
            origName = dic[name];
        }
    }
    return origName;
}

+ (NSString *)convertToEscapeString:(NSString *)string{
    NSMutableString *resultString = [NSMutableString stringWithString:string];
    /** 因为所有字符串都已经使用 " " 包括起来, 所以转义字符只需处理双引号 */
    [resultString replaceOccurrencesOfString:@"\"" withString:@"\"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, resultString.length)];
//    [resultString replaceOccurrencesOfString:@"'" withString:@"''" options:NSCaseInsensitiveSearch range:NSMakeRange(0, resultString.length)];
//    [resultString replaceOccurrencesOfString:@"/" withString:@"//" options:NSCaseInsensitiveSearch range:NSMakeRange(0, resultString.length)];
//    [resultString replaceOccurrencesOfString:@"[" withString:@"/[" options:NSCaseInsensitiveSearch range:NSMakeRange(0, resultString.length)];
//    [resultString replaceOccurrencesOfString:@"]" withString:@"/]" options:NSCaseInsensitiveSearch range:NSMakeRange(0, resultString.length)];
//    [resultString replaceOccurrencesOfString:@"%" withString:@"/%" options:NSCaseInsensitiveSearch range:NSMakeRange(0, resultString.length)];
//    [resultString replaceOccurrencesOfString:@"&" withString:@"/%" options:NSCaseInsensitiveSearch range:NSMakeRange(0, resultString.length)];
//    [resultString replaceOccurrencesOfString:@"_" withString:@"/_" options:NSCaseInsensitiveSearch range:NSMakeRange(0, resultString.length)];
//    [resultString replaceOccurrencesOfString:@"(" withString:@"/(" options:NSCaseInsensitiveSearch range:NSMakeRange(0, resultString.length)];
//    [resultString replaceOccurrencesOfString:@"/)" withString:@"/)" options:NSCaseInsensitiveSearch range:NSMakeRange(0, resultString.length)];
    return resultString;
}

+ (NSString *)linkStringArray:(NSArray *)array withComponent:(NSString *)component  updateTime:(BOOL)flag{
    if (!array || array.count == 0) {
        return nil;
    }
    NSMutableString *resultString = [NSMutableString string];
    [array enumerateObjectsUsingBlock:^(NSString *str, NSUInteger idx, BOOL *stop) {
        [resultString appendFormat:@"%@ %@ ", str, component];
    }];
    if (flag) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        [resultString appendFormat:@"\"voupdatetime\" = %@ %@ ", @(now), component];
    }
    if (resultString.length > 5) {
        [resultString deleteCharactersInRange:NSMakeRange(resultString.length - (component.length + 2), component.length + 2)];
    }
    else{
        resultString = nil;
    }
    return resultString;
}

@end

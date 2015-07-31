//
//  NSObject+VODBCache.h
//  VODBCacheDemo
//
//  Created by Valo on 15/7/31.
//  Copyright (c) 2015年 Valo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"

@protocol VODBCache <NSObject>
@optional
/**
 *  自定义数据表名
 *
 *  @return 自定义表名
 */
+ (NSString *)manualTableName;

/**
 *  此数组中的属性值将用于创建唯一性约束.
 *  如果数据模型实现了此方法,将会用数组中的属性值组合生成voconstraint字段,用作唯一性约束.
 *
 *  @return 用于创建约束的属性值
 */
+ (NSArray  *)uniqueKeyPropertyNames;

/**
 *  自定义不缓存的属性
 *
 *  @return 不缓存的属性名称数组
 */
+ (NSArray  *)ignoredPropertyNamesForCache;

/**
 *  当发生冲突时只更新指定的属性
 *
 *  @return 当缓存发生冲突时,只更新指定的属性的名称数组
 */
+ (NSArray  *)allowUpdatePropertyNamesForCache;

@end

@interface NSObject (VODBCache) <VODBCache>

@property (nonatomic, copy  ) NSString       *voconstraint;     /**< 唯一性约束 */
@property (nonatomic, assign) NSTimeInterval vocreatetime;      /**< 创建时间  */
@property (nonatomic, assign) NSTimeInterval voupdatetime;      /**< 更新时间  */

/**
 *  初始化此数据模型的缓存
 */
+ (void)initVODBCache;

#pragma mark - 缓存数据
/**
 *  缓存一条数据
 */
- (void)cacheObject;

/**
 *  缓存一条数据,指定缓存完成后执行指定的操作
 *
 *  @param completion 缓存完成后执行指定的操作
 */
- (void)cacheObjectCompletion:(void (^)(id obj, NSError *error))completion;

/**
 *  缓存一组数据
 *
 *  @param array 要缓存的数据数组
 */
+ (void)cacheObjectArray:(NSArray *)array;

/**
 *  缓存一组数据,指定缓存完成后执行指定的操作
 *
 *  @param array      要缓存的数据数组
 *  @param completion 缓存完成后执行指定的操作
 */
+ (void)cacheObjectArray:(NSArray *)array completion:(void (^)(NSArray *array, NSError *error))completion;

#pragma mark - 更新数据
/**
 *  更新一条数据
 */
- (void)updateCacheObject;

/**
 *  缓存一条数据,指定缓存完成后执行指定的操作
 *
 *  @param completion 缓存完成后执行指定的操作
 */
- (void)updateCacheObjectCompletion:(void (^)(id obj, NSError *error))completion;

/**
 *  缓存一组数据,指定缓存完成后执行指定的操作
 *
 *  @param array      要更新的数据数组
 *  @param values     要更新的值的表达式(字符串)数组,比如 'name'='张三','score'=100 等,只能用等号.
 *                    可以是复杂的表达式,数组中的每个表达式以AND连接
 *  @param completion 缓存完成后执行指定的操作
 */
+ (void)updateCacheObjects:(NSArray *)array withValues:(NSArray *)values completion:(void (^)(id obj, NSError *error))completion;

/**
 *  更新一组数据,指定要更新数据的条件
 *
 *  @param values     要更新的值的表达式(字符串)数组,比如 'name'='张三','score'=100 等,只能用等号.
 *                    可以是复杂的表达式,数组中的每个表达式以AND连接
 *  @param condition  条件(字符串)数组,比如 'status'=1,'age'>18 等.
 *                    可以是复杂的表达式,数组中的每个表达式以AND连接
 */
+ (void)updateCacheObjectWithValues:(NSArray *)values condition:(NSArray *)condition;

/**
 *  更新一组数据,指定要更新数据的条件和缓存完成后执行指定的操作
 *
 *  @param values     要更新的值的表达式(字符串)数组,比如 'name'='张三','score'=100 等,只能用等号.
 *                    可以是复杂的表达式,数组中的每个表达式以AND连接
 *  @param condition  条件(字符串)数组,比如 'status'=1,'age'>18 等.
 *                    可以是复杂的表达式,数组中的每个表达式以AND连接
 *  @param completion 缓存完成后执行指定的操作
 */
+ (void)updateCacheObjectWithValues:(NSArray *)values condition:(NSArray *)condition completion:(void (^)(NSArray *array, NSError *error))completion;

#pragma mark - 从缓存中删除数据
/**
 *  从缓存中删除一条数据
 */
- (void)removefromCache;

/**
 *  从缓存中删除一条数据,并指定删除完成后执行的操作
 *
 *  @param completion 删除完成后执行的操作
 */
- (void)removefromCacheCompletion:(void (^)(id obj))completion;

/**
 *  从缓存中删除一组数据
 *
 *  @param array 要删除的数据数组
 */
+ (void)objectArrayRemoveFromCache:(NSArray *)array;

/**
 *  从缓存中删除一组数据,并指定删除完成后执行的操作
 *
 *  @param array      要删除的数据数组
 *  @param completion 删除完成后执行的操作
 */
+ (void)objectArrayRemoveFromCache:(NSArray *)array completion:(void (^)(NSArray *array))completion;

#pragma mark - 从缓存中读取数据
/**
 *  使用自定义SQL语句从缓存中读取数据
 *
 *  @param sql        读取数据的SQL语句
 *  @param completion 读取完成后的操作
 */
+ (void)objectArrayFromCache:(NSString *)sql completion:(void (^)(NSArray *array))completion;

/**
 *  按指定条件从缓存中读取数据
 *
 *  @param condition  条件(字符串)数组,比如 'name'='张三','age'>18 等.
 *                    可以是复杂的表达式,数组中的每个表达式以AND连接
 *  @param sort       排序方式(字符串)数组,比如 name DESC, age ASC 等
 *                    可以是复杂的表达式,数组中的每个表达式以AND连接
 *  @param start      起始条目数
 *  @param count      要读取的条目数
 *  @param completion 读取完成后的操作
 */
+ (void)objectArrayFromCache:(NSArray *)condition sort:(NSArray *)sort start:(NSInteger)start count:(NSInteger)count completion:(void (^)(NSArray *array))completion;

#pragma mark - 执行指定的操作
/**
 *  查询缓存数据的总数
 *
 *  @param completion 查询完成的操作
 */
+ (void)queryObjectCountInCacheCompletion:(void (^)(NSInteger count))completion;

/**
 *  查询缓存中符合条件的数据总数
 *
 *  @param condition  条件(字符串)数组,比如 'name'='张三','age'>18 等.
 *                    可以是复杂的表达式,数组中的每个表达式以AND连接
 *  @param completion 查询完成的操作
 */
+ (void)queryObjectCountInCacheWithCondition:(NSArray *)condition Completion:(void (^)(NSInteger count))completion;

/**
 *  执行指定的查询操作
 *
 *  @param sql        查询操作的SQL语句
 *  @param completion 查询完成的操作
 */
+ (void)querySQL:(NSString *)sql completion:(void (^)(FMResultSet *rs))completion;

/**
 *  执行指定的更新操作
 *
 *  @param sql        更新操作的SQL语句
 *  @param completion 查询完成的操作
 */
+ (void)updateSQL:(NSString *)sql completion:(void (^)(BOOL result))completion;


@end

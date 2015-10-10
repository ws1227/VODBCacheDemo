# 基于MJExtension和FMDB的数据缓存

注:  本项目包含了 数据缓存(VODBCache), 网络请求缓存(VOURLCache).VOURLCache未经严格测试,慎用.

数据缓存(VODBCache)说明:

1. 项目中必须包含MJExtension和FMDB,主要用于缓存网络请求获取的JSON对象

2. 只缓存数字和字符串类型的数据

3. 支持数据的 增 删 改 查

4. 可自动添加新字段(不支持从旧字段更名)

5. 可自定义表名,默认使用数据模型的类名作为表名

6. 可自动更新数据,结合allowUpdatePropertyNamesForCache 和 ignoredUpdatePropertyNamesForCache, 具体请参考注释

7. 创建数据表时,会自动创建3个字段 voconstraint(唯一性约束), vocreatetime(创建时间), 更新时间(voupdatetime)

数据缓存(VODBCache)具体用法:

1. 在数据模型的.h或者.m文件中包含

	#import "NSObject+VODBCache.h"

	实现 + load 方法如下:

		+ (void)load{
	    	[self initVODBCache];
		}

2. 自定义表名

		+ (NSString *)manualTableName{
		    return @"weather";
		}

3. 数据唯一性约束

		- (NSString *)uniquenessConstraint{
		    return [NSString stringWithFormat:@"%@%@%@", self.postCode, self.citycode, self.pinyin];
		}

4. 不缓存的属性字段

		+ (NSArray  *)ignoredPropertyNamesForCache{
		    return @[@"WD",@"WS"];
		}

5. 当发生冲突时只更新指定的属性(用法和4相同,示例代码中没有)

		+ (NSArray  *)allowUpdatePropertyNamesForCache{
		    return @[@"WD",@"WS"];
		}

6. 当发生冲突时忽略更新的属性,优先级高于5(用法和4相同,示例代码中没有)

		+ (NSArray  *)ignoredUpdatePropertyNamesForCache{
		    return @[@"WD",@"WS"];
		}

7. 增删改查使用方法请直接查看注释,增删改查使用的condition和sort均为NSArray类型,示例如下(来自目前开发的项目):

        NSArray *condition = @[[NSString stringWithFormat:@"commentId = \"%@\"",@(comment.identifier)]];
        NSArray *sort = @[@"submitTime DESC"];
        [WXCommentReply objectsFromCacheWithCondition:condition sort:sort start:0 count:1 success:^(NSArray *array) {
            //do something with array (array 是 WXCommentReply 对象数组)
        } failure:^(NSError *error) {
            //do something with error;
        }];

   a.具体查询是根据condition和sort拼接成SQL语句,当然也可以自己写SQL语句.
   b.condition和sort数组的的字符串应注意双引号的使用

 8. 如运行时候,出现如下错误:

 		(19: UNIQUE constraint failed: weather.voconstraint)

   此错误说明唯一性冲突,一般可忽略.如果缓存数据时 updateWhenConflict 为 YES, 出现此冲突则会自动更新相关字段的值

   运行时console可能会有各种db操作的提示,此版本仍保持显示, 若要关闭,请自行修改代码, 在inTransaction的block中加入

   		db.logsErrors = NO;

此版本VODBCache已经使用在公司的项目中,暂未发现明显问题.

后续版本可能考虑自动缓存 NSArray 和 NSDictionary.

欢迎大家多提issue.


网络请求缓存(VOURLCache)说明:

1. VOURLCache基于AFNetworking, 并在 AFHTTPRequestOperationManager 的分类中重写了方法(编译会有警告,请忽略):

		- (AFHTTPRequestOperation *)HTTPRequestOperationWithHTTPMethod:(NSString *)method
		                                                     URLString:(NSString *)URLString
		                                                    parameters:(id)parameters
		                                                       success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
		                                                       failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error));

2. 在 VOURLCache 的 + load 方法中设置了sharedURLCache, 如果需要请自行修改. 如果要使用VOURLCache,必须将sharedURLCache 设置为 VOURLCache,否则不起作用.

网络请求缓存(VOURLCache)使用方法:

1. 参照 VOURLCache的 + load 方法的代码,  设置 cache 的 ignoreRequestFields属性, 通常忽略一些每次请求都会发生变化的属性, 比如各种时间戳;

2. 在具体请求的 HTTPHeaderFields, 添加缓存时间项: 

    	[manager.requestSerializer setValue:@"10" forHTTPHeaderField:VOURLCacheAgeKey];

此版本VOURLCache 还不够完善,仅作了简单验证,请慎用!!!.

欢迎大家多提issue.




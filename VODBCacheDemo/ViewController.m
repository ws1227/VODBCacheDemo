//
//  ViewController.m
//  VODBCacheDemo
//
//  Created by Valo on 15/7/31.
//  Copyright (c) 2015年 Valo. All rights reserved.
//

#import "ViewController.h"
#import "VOWeather.h"
#import "ViewUtils.h"
#import "AFNetworking.h"
#import "VOWeatherCell.h"
#import "UIView+Toast.h"
#import "VOURLCache.h"

@interface ViewController () <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITextField *addCityTextField;
@property (weak, nonatomic) IBOutlet UITextField *deleteCityTextField;
@property (weak, nonatomic) IBOutlet UITextField *modiTextField;
@property (weak, nonatomic) IBOutlet UITextField *hTmpTextField;
@property (weak, nonatomic) IBOutlet UITextField *lTmpTextField;
@property (weak, nonatomic) IBOutlet UITextField *tmpTextField;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) NSArray *weathers;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *jsonPath = [[NSBundle mainBundle] pathForResource:@"weather" ofType:@"json"];
    NSString *jsonStr  = [NSString stringWithContentsOfFile:jsonPath encoding:NSUTF8StringEncoding error:nil];
    NSArray *array = [VOWeather objectArrayWithKeyValuesArray:jsonStr];
    [VOWeather cacheObjects:array success:^(NSArray *array) {
        [self loadData];
    } failure:^(NSError *error) {
        VOLog(@"Error:%@", error);
    }];
}

- (void)loadData{
    [VOWeather objectsFromCacheWithCondition:nil sort:nil start:0 count:100 success:^(NSArray *array) {
        self.weathers = array;
        [self.tableView reloadData];
    } failure:^(NSError *error) {
        VOLog(@"error: %@", error);
    }];
}

- (IBAction)closeKeyboard {
    [self.view.firstResponder resignFirstResponder];
}

- (IBAction)addCity {
    NSString *city = self.addCityTextField.text;
    if (!city || city.length == 0) {
        [self.view makeToast:@"无效的城市拼音" duration:1.0 position:CSToastPositionCenter];
        return;
    }
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    [manager.requestSerializer setValue:@"10" forHTTPHeaderField:VOURLCacheAgeKey];
    [manager.requestSerializer setCachePolicy:NSURLRequestReturnCacheDataElseLoad];
    [manager.requestSerializer setTimeoutInterval:10];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/plain", @"text/html",nil];
    NSDictionary *header = @{@"apikey":@"1d5744bd0cfe5472027b261c93bc2ec1"};
    [manager.requestSerializer setValue:header[@"apikey"] forHTTPHeaderField:@"apikey"];
    NSDictionary *params = @{@"citypinyin": city};
    [manager GET:@"http://apis.baidu.com/apistore/weatherservice/weather" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *dic = [responseObject objectForKey:@"retData"];
        if (dic && dic.count > 0) {
            VOWeather *weather = [VOWeather objectWithKeyValues:dic];
            [weather cacheObjectSuccess:^(id data) {
                [self loadData];
            } failure:^(NSError *error) {
                VOLog(@"error: %@", error);
            }];
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        VOLog(@"error: %@", error);
    }];
}

- (IBAction)deleteCity {
    NSString *city = self.deleteCityTextField.text;
    if (!city || city.length == 0) {
        [self.view makeToast:@"无效的城市拼音" duration:1.0 position:CSToastPositionCenter];
        return;
    }
    NSString *condition = [NSString stringWithFormat:@"\"pinyin\" = \"%@\"",city];
    [VOWeather removeCachedObjectsWithCondition:@[condition] success:^(NSArray *array) {
        [self loadData];
    } failure:^(NSError *error) {
        VOLog(@"error: %@", error);
    }];
}

- (IBAction)modifyCity {
    NSString *city = self.modiTextField.text;
    if (!city || city.length == 0) {
        [self.view makeToast:@"无效的城市拼音" duration:1.0 position:CSToastPositionCenter];
        return;
    }
    NSString *condition = [NSString stringWithFormat:@"\"pinyin\" = \"%@\"",city];
    NSString *lTmp = self.lTmpTextField.text;
    NSString *hTmp = self.hTmpTextField.text;
    NSString *tmp  = self.tmpTextField.text;
    NSMutableArray *values = [NSMutableArray array];
    if (lTmp && lTmp.length > 0) {
        [values addObject:[NSString stringWithFormat:@"\"l_tmp\" = \"%@\"",lTmp]];
    }
    if (hTmp && hTmp.length > 0) {
        [values addObject:[NSString stringWithFormat:@"\"h_tmp\" = \"%@\"",hTmp]];
    }
    if (tmp && tmp.length > 0) {
        [values addObject:[NSString stringWithFormat:@"\"temp\" = \"%@\"",tmp]];
    }
    [VOWeather updateCacheObjectsWithValues:values condition:@[condition] success:^(NSArray *array) {
        [self loadData];
    } failure:^(NSError *error) {
        VOLog(@"error: %@", error);
    }];
    
}

- (IBAction)editList:(UIBarButtonItem *)sender {
    if (self.tableView.editing) {
        NSMutableArray *willDelArray = [NSMutableArray array];
        for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
            [willDelArray addObject:self.weathers[indexPath.row]];
        }
        [VOWeather removeCachedObjects:willDelArray success:^(NSArray *array) {
            [self loadData];
            self.tableView.editing = NO;
        } failure:^(NSError *error) {
            self.tableView.editing = NO;
            VOLog(@"error: %@", error);
        }];
    }
    else{
        self.tableView.editing = YES;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.weathers.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    VOWeatherCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([VOWeatherCell class]) forIndexPath:indexPath];
    cell.weather = self.weathers[indexPath.row];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath{
    VOWeather *weather = self.weathers[indexPath.row];
    [weather removefromCacheSuccess:^(id obj) {
        [self loadData];
    } failure:^(NSError *error) {
        VOLog(@"error: %@",error);
    }];
}

@end

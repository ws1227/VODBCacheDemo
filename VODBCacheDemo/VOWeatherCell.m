//
//  VOWeatherCell.m
//  VODBCacheDemo
//
//  Created by Valo on 15/8/3.
//  Copyright (c) 2015年 Valo. All rights reserved.
//

#import "VOWeatherCell.h"

@interface VOWeatherCell ()

@property (weak, nonatomic) IBOutlet UILabel *cityLabel;
@property (weak, nonatomic) IBOutlet UILabel *lTmpLabel;
@property (weak, nonatomic) IBOutlet UILabel *hTmpLabel;
@property (weak, nonatomic) IBOutlet UILabel *tmpLabel;
@end

@implementation VOWeatherCell

- (void)awakeFromNib {
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setWeather:(VOWeather *)weather{
    self.cityLabel.text = weather.city;
    self.lTmpLabel.text = weather.l_tmp;
    self.hTmpLabel.text = weather.h_tmp;
    self.tmpLabel.text  = weather.temp;
}

@end

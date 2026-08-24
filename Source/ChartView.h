#import <UIKit/UIKit.h>

@interface BarChartView : UIView
@property (nonatomic, strong) NSArray<NSDictionary *> *data; // @[@{@"label": @"1", @"value": @100}]
@property (nonatomic, strong) UIColor *barColor;
@property (nonatomic, assign) CGFloat maxValue;
- (void)reloadData;
@end

@interface DonutChartView : UIView
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *data; // @{@"餐饮": @500, ...}
@property (nonatomic, strong) NSArray<UIColor *> *colors;
- (void)reloadData;
@end

@interface TrendChartView : UIView
@property (nonatomic, strong) NSArray<NSDictionary *> *data; // @[@{@"label": @"1月", @"value": @1000}]
- (void)reloadData;
@end
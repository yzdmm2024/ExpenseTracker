#import "ChartView.h"

#pragma mark - Bar Chart

@implementation BarChartView

- (void)reloadData {
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    if (!self.data.count) return;
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat width = rect.size.width;
    CGFloat height = rect.size.height;
    CGFloat barWidth = 20;
    CGFloat spacing = (width - self.data.count * barWidth) / (self.data.count + 1);
    if (spacing < 4) spacing = 4;
    
    CGFloat maxVal = self.maxValue > 0 ? self.maxValue : 1;
    
    // Draw bars
    for (int i = 0; i < self.data.count; i++) {
        NSDictionary *item = self.data[i];
        double value = [item[@"value"] doubleValue];
        CGFloat barHeight = (value / maxVal) * (height - 30);
        CGFloat x = spacing + i * (barWidth + spacing);
        CGFloat y = height - 20 - barHeight;
        
        // Bar
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(x, y, barWidth, barHeight)
                                                   byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight
                                                         cornerRadii:CGSizeMake(4, 4)];
        [self.barColor ?: [UIColor systemBlueColor] setFill];
        [path fill];
        
        // Label
        NSString *label = item[@"label"];
        if (label) {
            NSDictionary *attrs = @{NSFontAttributeName: [UIFont systemFontOfSize:9],
                                    NSForegroundColorAttributeName: [UIColor lightGrayColor]};
            CGSize labelSize = [label sizeWithAttributes:attrs];
            [label drawAtPoint:CGPointMake(x + (barWidth - labelSize.width) / 2, height - 14) withAttributes:attrs];
        }
    }
}

@end

#pragma mark - Donut Chart

@implementation DonutChartView

- (void)reloadData {
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    if (!self.data.allKeys.count) return;
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat centerX = rect.size.width / 2;
    CGFloat centerY = rect.size.height / 2;
    CGFloat radius = MIN(centerX, centerY) - 20;
    CGFloat lineWidth = 35;
    
    double total = 0;
    for (NSNumber *v in self.data.allValues) total += v.doubleValue;
    if (total <= 0) return;
    
    NSArray *sortedKeys = [self.data keysSortedByValueUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
        return [b compare:a];
    }];
    
    NSArray *defaultColors = self.colors ?: @[
        [UIColor colorWithRed:1 green:0.6 blue:0.2 alpha:1],
        [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:1],
        [UIColor colorWithRed:1 green:0.3 blue:0.3 alpha:1],
        [UIColor colorWithRed:0.4 green:0.7 blue:0.4 alpha:1],
        [UIColor colorWithRed:0.7 green:0.4 blue:0.9 alpha:1],
        [UIColor colorWithRed:0.9 green:0.4 blue:0.4 alpha:1],
        [UIColor colorWithRed:0.3 green:0.6 blue:0.8 alpha:1],
        [UIColor colorWithRed:0.3 green:0.8 blue:0.7 alpha:1],
        [UIColor colorWithRed:0.8 green:0.5 blue:0.2 alpha:1],
        [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1],
    ];
    
    CGFloat startAngle = -M_PI_2;
    
    for (int i = 0; i < sortedKeys.count; i++) {
        NSString *key = sortedKeys[i];
        double value = [self.data[key] doubleValue];
        CGFloat angle = (value / total) * 2 * M_PI;
        
        UIColor *color = i < defaultColors.count ? defaultColors[i] : [UIColor lightGrayColor];
        [color setStroke];
        
        UIBezierPath *arc = [UIBezierPath bezierPathWithArcCenter:CGPointMake(centerX, centerY)
                                                           radius:radius
                                                       startAngle:startAngle
                                                         endAngle:startAngle + angle
                                                        clockwise:YES];
        arc.lineWidth = lineWidth;
        [arc stroke];
        
        startAngle += angle;
    }
    
    // Center hole
    [[UIColor clearColor] setFill];
    CGContextSetBlendMode(ctx, kCGBlendModeClear);
    CGContextFillEllipseInRect(ctx, CGRectMake(centerX - radius/2, centerY - radius/2, radius, radius));
    CGContextSetBlendMode(ctx, kCGBlendModeNormal);
}

@end

#pragma mark - Trend Line Chart

@implementation TrendChartView

- (void)reloadData {
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    if (!self.data.count) return;
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat width = rect.size.width - 20;
    CGFloat height = rect.size.height - 30;
    
    double maxVal = 0;
    for (NSDictionary *item in self.data) {
        double val = [item[@"value"] doubleValue];
        if (val > maxVal) maxVal = val;
    }
    if (maxVal <= 0) maxVal = 1;
    
    CGFloat stepX = width / (self.data.count - 1);
    
    // Draw line
    UIBezierPath *line = [UIBezierPath bezierPath];
    BOOL first = YES;
    
    for (int i = 0; i < self.data.count; i++) {
        double val = [self.data[i][@"value"] doubleValue];
        CGFloat x = 10 + i * stepX;
        CGFloat y = height - (val / maxVal) * (height - 20) + 10;
        
        if (first) {
            [line moveToPoint:CGPointMake(x, y)];
            first = NO;
        } else {
            [line addLineToPoint:CGPointMake(x, y)];
        }
    }
    
    [[UIColor systemBlueColor] setStroke];
    line.lineWidth = 2.5;
    line.lineJoinStyle = kCGLineJoinRound;
    [line stroke];
    
    // Draw dots
    for (int i = 0; i < self.data.count; i++) {
        double val = [self.data[i][@"value"] doubleValue];
        CGFloat x = 10 + i * stepX;
        CGFloat y = height - (val / maxVal) * (height - 20) + 10;
        
        UIBezierPath *dot = [UIBezierPath bezierPathWithArcCenter:CGPointMake(x, y) radius:3 startAngle:0 endAngle:M_PI*2 clockwise:YES];
        [[UIColor systemBlueColor] setFill];
        [dot fill];
        
        // Label
        NSString *label = self.data[i][@"label"];
        if (label) {
            NSDictionary *attrs = @{NSFontAttributeName: [UIFont systemFontOfSize:9],
                                    NSForegroundColorAttributeName: [UIColor lightGrayColor]};
            CGSize s = [label sizeWithAttributes:attrs];
            [label drawAtPoint:CGPointMake(x - s.width/2, height + 5) withAttributes:attrs];
        }
    }
}

@end
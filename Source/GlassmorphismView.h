#import <UIKit/UIKit.h>

@interface GlassmorphismView : UIView

+ (instancetype)cardWithFrame:(CGRect)frame;
+ (instancetype)card;
- (void)addShadow;
- (void)setCornerRadius:(CGFloat)radius;

@end

@interface GradientBackgroundView : UIView
@property (nonatomic, strong) NSArray<UIColor *> *colors;
@end

@interface PillButton : UIButton
+ (instancetype)buttonWithTitle:(NSString *)title color:(UIColor *)color;
@end

@interface ExpenseCard : GlassmorphismView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
- (void)setTitle:(NSString *)title value:(NSString *)value subtitle:(NSString *)subtitle;
@end
#import "GlassmorphismView.h"

#pragma mark - Gradient Background

@implementation GradientBackgroundView

- (void)drawRect:(CGRect)rect {
    if (!self.colors.count) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[] = {0.0, 1.0};
    NSMutableArray *cgColors = [NSMutableArray array];
    for (UIColor *c in self.colors) {
        [cgColors addObject:(id)c.CGColor];
    }
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (CFArrayRef)cgColors, locations);
    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    CGFloat radius = MAX(rect.size.width, rect.size.height) * 0.8;
    CGContextDrawRadialGradient(ctx, gradient, center, 0, center, radius, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

@end

#pragma mark - Glassmorphism Card

@implementation GlassmorphismView

+ (instancetype)cardWithFrame:(CGRect)frame {
    GlassmorphismView *view = [[self alloc] initWithFrame:frame];
    view.backgroundColor = [UIColor colorWithWhite:1 alpha:0.7];
    view.layer.cornerRadius = 20;
    view.layer.masksToBounds = NO;
    view.layer.shadowColor = [UIColor colorWithWhite:0.4 alpha:0.3].CGColor;
    view.layer.shadowOffset = CGSizeMake(0, 4);
    view.layer.shadowOpacity = 1;
    view.layer.shadowRadius = 16;
    view.clipsToBounds = NO;
    
    // Blur effect
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    blur.frame = view.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blur.layer.cornerRadius = 20;
    blur.layer.masksToBounds = YES;
    [view insertSubview:blur atIndex:0];
    
    return view;
}

+ (instancetype)card {
    return [self cardWithFrame:CGRectZero];
}

- (void)addShadow {
    self.layer.shadowColor = [UIColor colorWithWhite:0.4 alpha:0.3].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowOpacity = 1;
    self.layer.shadowRadius = 16;
}

- (void)setCornerRadius:(CGFloat)radius {
    self.layer.cornerRadius = radius;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]]) {
            sub.layer.cornerRadius = radius;
        }
    }
}

@end

#pragma mark - Pill Button

@implementation PillButton

+ (instancetype)buttonWithTitle:(NSString *)title color:(UIColor *)color {
    PillButton *btn = [self buttonWithType:UIButtonTypeSystem];
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.backgroundColor = color;
    btn.layer.cornerRadius = 18;
    btn.clipsToBounds = YES;
    
    // Press animation
    [btn addTarget:btn action:@selector(scaleDown) forControlEvents:UIControlEventTouchDown];
    [btn addTarget:btn action:@selector(scaleUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    
    return btn;
}

- (void)scaleDown {
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformMakeScale(0.95, 0.95);
    }];
}

- (void)scaleUp {
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformIdentity;
    }];
}

@end

#pragma mark - Expense Card

@implementation ExpenseCard

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    _titleLabel.textColor = [UIColor grayColor];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_titleLabel];
    
    _valueLabel = [[UILabel alloc] init];
    _valueLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    _valueLabel.textColor = [UIColor darkTextColor];
    _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_valueLabel];
    
    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    _subtitleLabel.textColor = [UIColor lightGrayColor];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_subtitleLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:16],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        
        [_valueLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
        [_valueLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_valueLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_valueLabel.bottomAnchor constant:4],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [_subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-16],
    ]];
}

- (void)setTitle:(NSString *)title value:(NSString *)value subtitle:(NSString *)subtitle {
    self.titleLabel.text = title;
    self.valueLabel.text = value;
    self.subtitleLabel.text = subtitle;
}

@end
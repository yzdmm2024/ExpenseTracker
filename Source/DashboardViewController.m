#import "DashboardViewController.h"
#import "DatabaseManager.h"
#import "SMSParser.h"
#import "NotificationParser.h"
#import "GlassmorphismView.h"
#import "TransactionListViewController.h"
#import "AddTransactionViewController.h"
#import "MonthlyReportViewController.h"
#import "SettingsViewController.h"

@interface DashboardViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) GradientBackgroundView *bgView;
@property (nonatomic, strong) ExpenseCard *todayCard;
@property (nonatomic, strong) ExpenseCard *monthCard;
@property (nonatomic, strong) ExpenseCard *yearCard;
@property (nonatomic, strong) ExpenseCard *countCard;
@property (nonatomic, strong) UILabel *greetingLabel;
@property (nonatomic, strong) UIButton *syncButton;
@property (nonatomic, strong) UIStackView *quickActionsStack;
@end

@implementation DashboardViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupBackground];
    [self setupScrollView];
    [self setupHeader];
    [self setupCards];
    [self setupQuickActions];
    [self setupBottomNav];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshData];
}

- (void)setupBackground {
    _bgView = [[GradientBackgroundView alloc] initWithFrame:self.view.bounds];
    _bgView.colors = @[
        [UIColor colorWithRed:0.95 green:0.96 blue:0.98 alpha:1],
        [UIColor colorWithRed:0.88 green:0.92 blue:0.98 alpha:1],
    ];
    _bgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_bgView];
}

- (void)setupScrollView {
    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:_scrollView];
    
    _contentView = [[UIView alloc] init];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_contentView];
    
    [NSLayoutConstraint activateConstraints:@[
        [_contentView.topAnchor constraintEqualToAnchor:_scrollView.topAnchor],
        [_contentView.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor],
        [_contentView.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor],
        [_contentView.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor],
        [_contentView.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor],
    ]];
}

- (void)setupHeader {
    _greetingLabel = [[UILabel alloc] init];
    _greetingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _greetingLabel.text = [self greetingText];
    _greetingLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    _greetingLabel.textColor = [UIColor darkTextColor];
    [_contentView addSubview:_greetingLabel];
    
    _syncButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _syncButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_syncButton setImage:[UIImage systemImageNamed:@"arrow.triangle.2.circlepath"] forState:UIControlStateNormal];
    _syncButton.tintColor = [UIColor systemBlueColor];
    [_syncButton addTarget:self action:@selector(syncData) forControlEvents:UIControlEventTouchUpInside];
    [_contentView addSubview:_syncButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [_greetingLabel.topAnchor constraintEqualToAnchor:_contentView.topAnchor constant:60],
        [_greetingLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        
        [_syncButton.centerYAnchor constraintEqualToAnchor:_greetingLabel.centerYAnchor],
        [_syncButton.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],
        [_syncButton.widthAnchor constraintEqualToConstant:36],
        [_syncButton.heightAnchor constraintEqualToConstant:36],
    ]];
}

- (void)setupCards {
    CGFloat cardW = (UIScreen.mainScreen.bounds.size.width - 44) / 2;
    
    _todayCard = [ExpenseCard cardWithFrame:CGRectZero];
    _todayCard.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:_todayCard];
    
    _monthCard = [ExpenseCard cardWithFrame:CGRectZero];
    _monthCard.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:_monthCard];
    
    _yearCard = [ExpenseCard cardWithFrame:CGRectZero];
    _yearCard.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:_yearCard];
    
    _countCard = [ExpenseCard cardWithFrame:CGRectZero];
    _countCard.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:_countCard];
    
    [NSLayoutConstraint activateConstraints:@[
        [_todayCard.topAnchor constraintEqualToAnchor:_greetingLabel.bottomAnchor constant:20],
        [_todayCard.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:16],
        [_todayCard.widthAnchor constraintEqualToConstant:cardW],
        [_todayCard.heightAnchor constraintEqualToConstant:100],
        
        [_monthCard.topAnchor constraintEqualToAnchor:_todayCard.topAnchor],
        [_monthCard.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-16],
        [_monthCard.widthAnchor constraintEqualToConstant:cardW],
        [_monthCard.heightAnchor constraintEqualToConstant:100],
        
        [_yearCard.topAnchor constraintEqualToAnchor:_todayCard.bottomAnchor constant:12],
        [_yearCard.leadingAnchor constraintEqualToAnchor:_todayCard.leadingAnchor],
        [_yearCard.widthAnchor constraintEqualToConstant:cardW],
        [_yearCard.heightAnchor constraintEqualToConstant:100],
        
        [_countCard.topAnchor constraintEqualToAnchor:_yearCard.topAnchor],
        [_countCard.trailingAnchor constraintEqualToAnchor:_monthCard.trailingAnchor],
        [_countCard.widthAnchor constraintEqualToConstant:cardW],
        [_countCard.heightAnchor constraintEqualToConstant:100],
    ]];
}

- (void)setupQuickActions {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"快捷操作";
    label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    label.textColor = [UIColor darkTextColor];
    [_contentView addSubview:label];
    
    _quickActionsStack = [[UIStackView alloc] init];
    _quickActionsStack.translatesAutoresizingMaskIntoConstraints = NO;
    _quickActionsStack.axis = UILayoutConstraintAxisHorizontal;
    _quickActionsStack.distribution = UIStackViewDistributionFillEqually;
    _quickActionsStack.spacing = 12;
    [_contentView addSubview:_quickActionsStack];
    
    NSArray *items = @[
        @{@"title": @"记一笔", @"icon": @"plus.circle.fill", @"color": [UIColor systemBlueColor]},
        @{@"title": @"账单", @"icon": @"chart.pie.fill", @"color": [UIColor systemOrangeColor]},
        @{@"title": @"流水", @"icon": @"list.bullet.rectangle.fill", @"color": [UIColor systemGreenColor]},
        @{@"title": @"设置", @"icon": @"gearshape.fill", @"color": [UIColor systemGrayColor]},
    ];
    
    for (int i = 0; i < items.count; i++) {
        UIView *actionView = [self createActionView:items[i]];
        actionView.tag = i;
        [_quickActionsStack addArrangedSubview:actionView];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:_yearCard.bottomAnchor constant:24],
        [label.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        
        [_quickActionsStack.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:12],
        [_quickActionsStack.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:16],
        [_quickActionsStack.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-16],
        [_quickActionsStack.heightAnchor constraintEqualToConstant:80],
        [_quickActionsStack.bottomAnchor constraintEqualToAnchor:_contentView.bottomAnchor constant:-100],
    ]];
}

- (UIView *)createActionView:(NSDictionary *)item {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor colorWithWhite:1 alpha:0.7];
    view.layer.cornerRadius = 16;
    view.clipsToBounds = YES;
    
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:item[@"icon"]]];
    icon.tintColor = item[@"color"];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [view addSubview:icon];
    
    UILabel *label = [[UILabel alloc] init];
    label.text = item[@"title"];
    label.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    label.textColor = [UIColor darkGrayColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textAlignment = NSTextAlignmentCenter;
    [view addSubview:label];
    
    [NSLayoutConstraint activateConstraints:@[
        [icon.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:view.centerYAnchor constant:-8],
        [icon.widthAnchor constraintEqualToConstant:28],
        [icon.heightAnchor constraintEqualToConstant:28],
        
        [label.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:4],
        [label.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
    ]];
    
    // Tap gesture
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(actionTapped:)];
    view.userInteractionEnabled = YES;
    [view addGestureRecognizer:tap];
    
    return view;
}

- (void)actionTapped:(UITapGestureRecognizer *)tap {
    UIView *view = tap.view;
    NSInteger idx = view.tag;
    
    UIViewController *vc = nil;
    switch (idx) {
        case 0: vc = [[AddTransactionViewController alloc] init]; break;
        case 1: vc = [[MonthlyReportViewController alloc] init]; break;
        case 2: vc = [[TransactionListViewController alloc] init]; break;
        case 3: vc = [[SettingsViewController alloc] init]; break;
        default: return;
    }
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)setupBottomNav {
    // Simple tab-like navigation at bottom
    UIView *bottomBar = [[UIView alloc] init];
    bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    bottomBar.backgroundColor = [UIColor colorWithWhite:1 alpha:0.9];
    bottomBar.layer.cornerRadius = 0;
    [self.view addSubview:bottomBar];
    
    [NSLayoutConstraint activateConstraints:@[
        [bottomBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [bottomBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bottomBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bottomBar.heightAnchor constraintEqualToConstant:50],
    ]];
}

#pragma mark - Data

- (void)refreshData {
    NSDateFormatter *ymf = [[NSDateFormatter alloc] init];
    ymf.dateFormat = @"yyyy-MM";
    NSString *ym = [ymf stringFromDate:[NSDate date]];
    
    NSDateFormatter *yf = [[NSDateFormatter alloc] init];
    yf.dateFormat = @"yyyy";
    NSString *y = [yf stringFromDate:[NSDate date]];
    
    double todayTotal = [self todayTotal];
    double monthTotal = [[DatabaseManager shared] totalExpenseForMonth:ym];
    
    MonthlySummary *yearSummary = [[MonthlySummary alloc] init];
    yearSummary.totalExpense = 0;
    for (int m = 1; m <= 12; m++) {
        NSString *my = [NSString stringWithFormat:@"%@-%02d", y, m];
        yearSummary.totalExpense += [[DatabaseManager shared] totalExpenseForMonth:my];
    }
    
    NSInteger count = [[DatabaseManager shared] transactionCount];
    
    [_todayCard setTitle:@"今日支出" value:[NSString stringWithFormat:@"¥%.2f", todayTotal] subtitle:[self todaySubtitle]];
    [_monthCard setTitle:@"本月支出" value:[NSString stringWithFormat:@"¥%.2f", monthTotal] subtitle:[self monthSubtitle]];
    [_yearCard setTitle:@"全年支出" value:[NSString stringWithFormat:@"¥%.2f", yearSummary.totalExpense] subtitle:[NSString stringWithFormat:@"%@年", y]];
    [_countCard setTitle:@"总笔数" value:[NSString stringWithFormat:@"%ld笔", (long)count] subtitle:@"累计交易"];
}

- (double)todayTotal {
    NSArray *txns = [[DatabaseManager shared] transactionsForDate:[NSDate date]];
    double total = 0;
    for (TransactionModel *t in txns) {
        if (t.type == TransactionTypeExpense) total += t.amount;
    }
    return total;
}

- (NSString *)todaySubtitle {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"M月d日 EEEE";
    df.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    return [df stringFromDate:[NSDate date]];
}

- (NSString *)monthSubtitle {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"M月";
    return [NSString stringWithFormat:@"%@共%ld天", [df stringFromDate:[NSDate date]], (long)[self daysInMonth]];
}

- (NSInteger)daysInMonth {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSRange range = [cal rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:[NSDate date]];
    return range.length;
}

- (NSString *)greetingText {
    NSInteger hour = [[NSCalendar currentCalendar] component:NSCalendarUnitHour fromDate:[NSDate date]];
    if (hour < 6) return @"夜深了 🌙";
    if (hour < 9) return @"早上好 🌅";
    if (hour < 12) return @"上午好 ☀️";
    if (hour < 14) return @"中午好 🌞";
    if (hour < 18) return @"下午好 🌤";
    return @"晚上好 🌆";
}

- (void)syncData {
    self.syncButton.enabled = NO;
    [UIView animateWithDuration:0.5 animations:^{
        self.syncButton.transform = CGAffineTransformMakeRotation(M_PI);
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL smsEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"sms_enabled"];
        BOOL notifEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"notif_enabled"];
        
        // Default to enabled if not set
        if (![[NSUserDefaults standardUserDefaults] objectForKey:@"sms_enabled"]) smsEnabled = YES;
        if (![[NSUserDefaults standardUserDefaults] objectForKey:@"notif_enabled"]) notifEnabled = YES;
        
        NSMutableArray *all = [NSMutableArray array];
        NSInteger smsCount = 0, notifCount = 0;
        
        if (smsEnabled) {
            NSArray *smsTxns = [[SMSParser shared] parseSMSTransactions];
            [all addObjectsFromArray:smsTxns];
            smsCount = smsTxns.count;
        }
        
        if (notifEnabled) {
            NSArray *notifTxns = [[NotificationParser shared] parseNotificationTransactions];
            [all addObjectsFromArray:notifTxns];
            notifCount = notifTxns.count;
        }
        
        [[DatabaseManager shared] insertTransactions:all];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshData];
            self.syncButton.enabled = YES;
            self.syncButton.transform = CGAffineTransformIdentity;
            
            // Show alert
            NSString *msg;
            if (smsEnabled && notifEnabled) {
                msg = [NSString stringWithFormat:@"短信: %ld条\n通知: %ld条\n共新增: %ld条",
                       (long)smsCount, (long)notifCount, (long)all.count];
            } else if (smsEnabled) {
                msg = [NSString stringWithFormat:@"短信: %ld条\n（通知解析已关闭）", (long)smsCount];
            } else if (notifEnabled) {
                msg = [NSString stringWithFormat:@"通知: %ld条\n（短信解析已关闭）", (long)notifCount];
            } else {
                msg = @"短信和通知解析均已关闭\n请在设置中开启后重试";
            }
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"同步完成"
                                       message:msg
                                       preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
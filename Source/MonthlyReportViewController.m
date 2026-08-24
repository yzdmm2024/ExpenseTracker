#import "MonthlyReportViewController.h"
#import "DatabaseManager.h"
#import "TransactionModel.h"
#import "GlassmorphismView.h"
#import "ChartView.h"

@interface MonthlyReportViewController ()
@property (nonatomic, strong) UISegmentedControl *monthSelector;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) ExpenseCard *totalCard;
@property (nonatomic, strong) ExpenseCard *avgCard;
@property (nonatomic, strong) ExpenseCard *maxCard;
@property (nonatomic, strong) ExpenseCard *countCard;
@property (nonatomic, strong) BarChartView *dailyChart;
@property (nonatomic, strong) DonutChartView *donutChart;
@property (nonatomic, strong) TrendChartView *trendChart;
@property (nonatomic, strong) UILabel *donutLegend;
@property (nonatomic, strong) NSArray *monthLabels;
@property (nonatomic, assign) NSInteger currentMonthOffset;
@end

@implementation MonthlyReportViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.95 green:0.96 blue:0.98 alpha:1];
    self.currentMonthOffset = 0;
    
    // Month labels
    NSMutableArray *labels = [NSMutableArray array];
    for (int i = 5; i >= 0; i--) {
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDateComponents *comp = [[NSDateComponents alloc] init];
        comp.month = -i;
        NSDate *date = [cal dateByAddingComponents:comp toDate:[NSDate date] options:0];
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"M月";
        [labels addObject:[df stringFromDate:date]];
    }
    self.monthLabels = labels;
    
    [self setupHeader];
    [self setupMonthSelector];
    [self setupSummaryCards];
    [self setupCharts];
    [self loadData];
}

- (void)setupHeader {
    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:header];
    
    UILabel *title = [[UILabel alloc] init];
    title.text = @"月度账单";
    title.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:title];
    
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [backBtn setImage:[UIImage systemImageNamed:@"chevron.left"] forState:UIControlStateNormal];
    backBtn.tintColor = [UIColor systemBlueColor];
    backBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [backBtn addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:backBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:100],
        
        [backBtn.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [backBtn.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [backBtn.widthAnchor constraintEqualToConstant:30],
        [backBtn.heightAnchor constraintEqualToConstant:30],
        
        [title.centerXAnchor constraintEqualToAnchor:header.centerXAnchor],
        [title.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-12],
    ]];
}

- (void)setupMonthSelector {
    _monthSelector = [[UISegmentedControl alloc] initWithItems:self.monthLabels];
    _monthSelector.translatesAutoresizingMaskIntoConstraints = NO;
    _monthSelector.selectedSegmentIndex = self.monthLabels.count - 1;
    [_monthSelector addTarget:self action:@selector(monthChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_monthSelector];
    
    [NSLayoutConstraint activateConstraints:@[
        [_monthSelector.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:110],
        [_monthSelector.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_monthSelector.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
    ]];
}

- (void)setupSummaryCards {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:_scrollView];
    
    _contentView = [[UIView alloc] init];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_contentView];
    
    CGFloat cardW = (UIScreen.mainScreen.bounds.size.width - 44) / 2;
    
    _totalCard = [ExpenseCard cardWithFrame:CGRectZero];
    _totalCard.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:_totalCard];
    
    _avgCard = [ExpenseCard cardWithFrame:CGRectZero];
    _avgCard.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:_avgCard];
    
    _maxCard = [ExpenseCard cardWithFrame:CGRectZero];
    _maxCard.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:_maxCard];
    
    _countCard = [ExpenseCard cardWithFrame:CGRectZero];
    _countCard.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:_countCard];
    
    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:_monthSelector.bottomAnchor constant:8],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [_contentView.topAnchor constraintEqualToAnchor:_scrollView.topAnchor],
        [_contentView.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor],
        [_contentView.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor],
        [_contentView.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor],
        [_contentView.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor],
        
        [_totalCard.topAnchor constraintEqualToAnchor:_contentView.topAnchor constant:12],
        [_totalCard.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:16],
        [_totalCard.widthAnchor constraintEqualToConstant:cardW],
        [_totalCard.heightAnchor constraintEqualToConstant:100],
        
        [_avgCard.topAnchor constraintEqualToAnchor:_totalCard.topAnchor],
        [_avgCard.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-16],
        [_avgCard.widthAnchor constraintEqualToConstant:cardW],
        [_avgCard.heightAnchor constraintEqualToConstant:100],
        
        [_maxCard.topAnchor constraintEqualToAnchor:_totalCard.bottomAnchor constant:12],
        [_maxCard.leadingAnchor constraintEqualToAnchor:_totalCard.leadingAnchor],
        [_maxCard.widthAnchor constraintEqualToConstant:cardW],
        [_maxCard.heightAnchor constraintEqualToConstant:100],
        
        [_countCard.topAnchor constraintEqualToAnchor:_maxCard.topAnchor],
        [_countCard.trailingAnchor constraintEqualToAnchor:_avgCard.trailingAnchor],
        [_countCard.widthAnchor constraintEqualToConstant:cardW],
        [_countCard.heightAnchor constraintEqualToConstant:100],
    ]];
}

- (void)setupCharts {
    // Daily bar chart
    GlassmorphismView *dailyCard = [GlassmorphismView cardWithFrame:CGRectZero];
    dailyCard.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:dailyCard];
    
    UILabel *dailyTitle = [[UILabel alloc] init];
    dailyTitle.translatesAutoresizingMaskIntoConstraints = NO;
    dailyTitle.text = @"每日支出";
    dailyTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [dailyCard addSubview:dailyTitle];
    
    _dailyChart = [[BarChartView alloc] init];
    _dailyChart.translatesAutoresizingMaskIntoConstraints = NO;
    _dailyChart.barColor = [UIColor systemBlueColor];
    _dailyChart.backgroundColor = [UIColor clearColor];
    [dailyCard addSubview:_dailyChart];
    
    [NSLayoutConstraint activateConstraints:@[
        [dailyCard.topAnchor constraintEqualToAnchor:_countCard.bottomAnchor constant:16],
        [dailyCard.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:16],
        [dailyCard.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-16],
        [dailyCard.heightAnchor constraintEqualToConstant:200],
        
        [dailyTitle.topAnchor constraintEqualToAnchor:dailyCard.topAnchor constant:12],
        [dailyTitle.leadingAnchor constraintEqualToAnchor:dailyCard.leadingAnchor constant:16],
        
        [_dailyChart.topAnchor constraintEqualToAnchor:dailyTitle.bottomAnchor constant:8],
        [_dailyChart.leadingAnchor constraintEqualToAnchor:dailyCard.leadingAnchor constant:8],
        [_dailyChart.trailingAnchor constraintEqualToAnchor:dailyCard.trailingAnchor constant:-8],
        [_dailyChart.bottomAnchor constraintEqualToAnchor:dailyCard.bottomAnchor constant:-8],
    ]];
    
    // Donut chart
    GlassmorphismView *donutCard = [GlassmorphismView cardWithFrame:CGRectZero];
    donutCard.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:donutCard];
    
    UILabel *donutTitle = [[UILabel alloc] init];
    donutTitle.translatesAutoresizingMaskIntoConstraints = NO;
    donutTitle.text = @"分类占比";
    donutTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [donutCard addSubview:donutTitle];
    
    _donutChart = [[DonutChartView alloc] init];
    _donutChart.translatesAutoresizingMaskIntoConstraints = NO;
    _donutChart.backgroundColor = [UIColor clearColor];
    [donutCard addSubview:_donutChart];
    
    _donutLegend = [[UILabel alloc] init];
    _donutLegend.translatesAutoresizingMaskIntoConstraints = NO;
    _donutLegend.numberOfLines = 0;
    _donutLegend.font = [UIFont systemFontOfSize:12];
    _donutLegend.textColor = [UIColor darkGrayColor];
    [donutCard addSubview:_donutLegend];
    
    [NSLayoutConstraint activateConstraints:@[
        [donutCard.topAnchor constraintEqualToAnchor:dailyCard.bottomAnchor constant:16],
        [donutCard.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:16],
        [donutCard.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-16],
        [donutCard.heightAnchor constraintEqualToConstant:280],
        
        [donutTitle.topAnchor constraintEqualToAnchor:donutCard.topAnchor constant:12],
        [donutTitle.leadingAnchor constraintEqualToAnchor:donutCard.leadingAnchor constant:16],
        
        [_donutChart.topAnchor constraintEqualToAnchor:donutTitle.bottomAnchor constant:8],
        [_donutChart.leadingAnchor constraintEqualToAnchor:donutCard.leadingAnchor constant:8],
        [_donutChart.widthAnchor constraintEqualToConstant:160],
        [_donutChart.heightAnchor constraintEqualToConstant:160],
        
        [_donutLegend.centerYAnchor constraintEqualToAnchor:_donutChart.centerYAnchor],
        [_donutLegend.leadingAnchor constraintEqualToAnchor:_donutChart.trailingAnchor constant:8],
        [_donutLegend.trailingAnchor constraintEqualToAnchor:donutCard.trailingAnchor constant:-8],
    ]];
    
    // Trend chart
    GlassmorphismView *trendCard = [GlassmorphismView cardWithFrame:CGRectZero];
    trendCard.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:trendCard];
    
    UILabel *trendTitle = [[UILabel alloc] init];
    trendTitle.translatesAutoresizingMaskIntoConstraints = NO;
    trendTitle.text = @"月度趋势";
    trendTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [trendCard addSubview:trendTitle];
    
    _trendChart = [[TrendChartView alloc] init];
    _trendChart.translatesAutoresizingMaskIntoConstraints = NO;
    _trendChart.backgroundColor = [UIColor clearColor];
    [trendCard addSubview:_trendChart];
    
    [NSLayoutConstraint activateConstraints:@[
        [trendCard.topAnchor constraintEqualToAnchor:donutCard.bottomAnchor constant:16],
        [trendCard.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:16],
        [trendCard.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-16],
        [trendCard.heightAnchor constraintEqualToConstant:200],
        [trendCard.bottomAnchor constraintEqualToAnchor:_contentView.bottomAnchor constant:-100],
        
        [trendTitle.topAnchor constraintEqualToAnchor:trendCard.topAnchor constant:12],
        [trendTitle.leadingAnchor constraintEqualToAnchor:trendCard.leadingAnchor constant:16],
        
        [_trendChart.topAnchor constraintEqualToAnchor:trendTitle.bottomAnchor constant:8],
        [_trendChart.leadingAnchor constraintEqualToAnchor:trendCard.leadingAnchor constant:8],
        [_trendChart.trailingAnchor constraintEqualToAnchor:trendCard.trailingAnchor constant:-8],
        [_trendChart.bottomAnchor constraintEqualToAnchor:trendCard.bottomAnchor constant:-8],
    ]];
}

- (void)loadData {
    // Get current selected month
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *comp = [[NSDateComponents alloc] init];
    comp.month = -((NSInteger)self.monthLabels.count - 1 - _monthSelector.selectedSegmentIndex);
    NSDate *date = [cal dateByAddingComponents:comp toDate:[NSDate date] options:0];
    
    NSDateFormatter *ymf = [[NSDateFormatter alloc] init];
    ymf.dateFormat = @"yyyy-MM";
    NSString *ym = [ymf stringFromDate:date];
    
    NSDateFormatter *mf = [[NSDateFormatter alloc] init];
    mf.dateFormat = @"M月";
    NSString *monthLabel = [mf stringFromDate:date];
    
    MonthlySummary *summary = [[DatabaseManager shared] summaryForMonth:ym];
    
    // Summary cards
    [_totalCard setTitle:@"总支出" value:[NSString stringWithFormat:@"¥%.2f", summary.totalExpense] subtitle:monthLabel];
    
    NSInteger days = [[DatabaseManager shared] transactionsForMonth:ym].count;
    double avg = days > 0 ? summary.totalExpense / days : 0;
    [_avgCard setTitle:@"日均" value:[NSString stringWithFormat:@"¥%.2f", avg] subtitle:monthLabel];
    
    NSArray *dailyData = [[DatabaseManager shared] dailyTotalsForMonth:ym];
    double max = 0;
    for (NSDictionary *d in dailyData) {
        if ([d[@"total"] doubleValue] > max) max = [d[@"total"] doubleValue];
    }
    [_maxCard setTitle:@"单日最高" value:[NSString stringWithFormat:@"¥%.2f", max] subtitle:monthLabel];
    [_countCard setTitle:@"交易笔数" value:[NSString stringWithFormat:@"%ld笔", (long)summary.transactionCount] subtitle:monthLabel];
    
    // Daily bar chart
    NSMutableArray *barData = [NSMutableArray array];
    NSCalendar *cal2 = [NSCalendar currentCalendar];
    NSRange dayRange = [cal2 rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:date];
    for (int d = 1; d <= dayRange.length; d++) {
        NSString *dayStr = [NSString stringWithFormat:@"%d", d];
        double total = 0;
        for (NSDictionary *item in dailyData) {
            if ([item[@"day"] isEqualToString:dayStr]) {
                total = [item[@"total"] doubleValue];
                break;
            }
        }
        [barData addObject:@{@"label": [NSString stringWithFormat:@"%d", d], @"value": @(total)}];
    }
    _dailyChart.data = barData;
    _dailyChart.maxValue = max * 1.2;
    [_dailyChart reloadData];
    
    // Donut chart
    _donutChart.data = summary.categoryBreakdown;
    [_donutChart reloadData];
    
    // Legend
    NSArray *sortedKeys = [summary.categoryBreakdown keysSortedByValueUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
        return [b compare:a];
    }];
    NSMutableString *legend = [NSMutableString string];
    for (NSString *key in sortedKeys) {
        double val = [summary.categoryBreakdown[key] doubleValue];
        double pct = summary.totalExpense > 0 ? val / summary.totalExpense * 100 : 0;
        [legend appendFormat:@"%@  ¥%.0f  (%.0f%%)\n", key, val, pct];
    }
    _donutLegend.text = legend;
    
    // Monthly trend
    NSMutableArray *trendData = [NSMutableArray array];
    for (int i = 5; i >= 0; i--) {
        NSDateComponents *c = [[NSDateComponents alloc] init];
        c.month = -i;
        NSDate *d = [cal dateByAddingComponents:c toDate:[NSDate date] options:0];
        NSString *ym = [ymf stringFromDate:d];
        double total = [[DatabaseManager shared] totalExpenseForMonth:ym];
        [trendData addObject:@{@"label": [NSString stringWithFormat:@"%d月", [c month]], @"value": @(total)}];
    }
    _trendChart.data = trendData;
    [_trendChart reloadData];
}

- (void)monthChanged {
    [self loadData];
}

- (void)goBack {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
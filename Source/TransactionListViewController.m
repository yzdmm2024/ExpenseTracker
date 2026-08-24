#import "TransactionListViewController.h"
#import "DatabaseManager.h"
#import "TransactionModel.h"
#import "GlassmorphismView.h"
#import "AddTransactionViewController.h"

@interface TransactionListViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray<TransactionModel *> *transactions;
@property (nonatomic, strong) NSArray<TransactionModel *> *filteredTransactions;
@property (nonatomic, strong) UISegmentedControl *filterControl;
@property (nonatomic, strong) UIButton *addButton;
@end

@implementation TransactionListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.95 green:0.96 blue:0.98 alpha:1];
    [self setupHeader];
    [self setupFilter];
    [self setupSearchBar];
    [self setupTableView];
    [self setupAddButton];
    [self loadData];
}

- (void)setupHeader {
    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:header];
    
    UILabel *title = [[UILabel alloc] init];
    title.text = @"交易流水";
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

- (void)setupFilter {
    _filterControl = [[UISegmentedControl alloc] initWithItems:@[@"全部", @"本月", @"微信", @"支付宝", @"银行卡"]];
    _filterControl.translatesAutoresizingMaskIntoConstraints = NO;
    _filterControl.selectedSegmentIndex = 0;
    [_filterControl addTarget:self action:@selector(filterChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_filterControl];
    
    [NSLayoutConstraint activateConstraints:@[
        [_filterControl.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:110],
        [_filterControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_filterControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
    ]];
}

- (void)setupSearchBar {
    _searchBar = [[UISearchBar alloc] init];
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _searchBar.placeholder = @"搜索商户、分类、备注";
    _searchBar.delegate = self;
    _searchBar.backgroundImage = [UIImage new];
    _searchBar.searchTextField.backgroundColor = [UIColor colorWithWhite:1 alpha:0.7];
    _searchBar.searchTextField.layer.cornerRadius = 12;
    _searchBar.searchTextField.clipsToBounds = YES;
    [self.view addSubview:_searchBar];
    
    [NSLayoutConstraint activateConstraints:@[
        [_searchBar.topAnchor constraintEqualToAnchor:_filterControl.bottomAnchor constant:8],
        [_searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [_searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
    ]];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.showsVerticalScrollIndicator = NO;
    _tableView.rowHeight = 72;
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self.view addSubview:_tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:_searchBar.bottomAnchor constant:4],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)setupAddButton {
    _addButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _addButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_addButton setImage:[UIImage systemImageNamed:@"plus.circle.fill"] forState:UIControlStateNormal];
    _addButton.tintColor = [UIColor systemBlueColor];
    _addButton.backgroundColor = [UIColor whiteColor];
    _addButton.layer.cornerRadius = 28;
    _addButton.layer.shadowColor = [UIColor blackColor].CGColor;
    _addButton.layer.shadowOffset = CGSizeMake(0, 2);
    _addButton.layer.shadowOpacity = 0.15;
    _addButton.layer.shadowRadius = 8;
    [_addButton addTarget:self action:@selector(addTransaction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_addButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [_addButton.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-30],
        [_addButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [_addButton.widthAnchor constraintEqualToConstant:56],
        [_addButton.heightAnchor constraintEqualToConstant:56],
    ]];
}

- (void)loadData {
    if (_filterControl.selectedSegmentIndex == 0) {
        self.transactions = [[DatabaseManager shared] allTransactions];
    } else if (_filterControl.selectedSegmentIndex == 1) {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"yyyy-MM";
        self.transactions = [[DatabaseManager shared] transactionsForMonth:[df stringFromDate:[NSDate date]]];
    } else {
        TransactionPlatform platforms[] = {TransactionPlatformWeChat, TransactionPlatformAlipay, TransactionPlatformBankCard};
        NSInteger idx = _filterControl.selectedSegmentIndex - 2;
        if (idx >= 0 && idx < 3) {
            self.transactions = [[DatabaseManager shared] transactionsForPlatform:platforms[idx]];
        }
    }
    self.filteredTransactions = self.transactions;
    [_tableView reloadData];
}

- (void)goBack {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)filterChanged {
    [self loadData];
}

- (void)addTransaction {
    [self.navigationController pushViewController:[[AddTransactionViewController alloc] init] animated:YES];
}

#pragma mark - Search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (!searchText.length) {
        self.filteredTransactions = self.transactions;
    } else {
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"merchant CONTAINS[cd] %@ OR category CONTAINS[cd] %@ OR note CONTAINS[cd] %@", searchText, searchText, searchText];
        self.filteredTransactions = [self.transactions filteredArrayUsingPredicate:pred];
    }
    [_tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MAX(1, self.filteredTransactions.count);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    // Remove old content
    for (UIView *v in cell.contentView.subviews) [v removeFromSuperview];
    
    if (self.filteredTransactions.count == 0) {
        UILabel *empty = [[UILabel alloc] initWithFrame:cell.contentView.bounds];
        empty.text = @"暂无交易记录\n点击右下角 + 记一笔";
        empty.numberOfLines = 0;
        empty.textAlignment = NSTextAlignmentCenter;
        empty.textColor = [UIColor lightGrayColor];
        empty.font = [UIFont systemFontOfSize:15];
        [cell.contentView addSubview:empty];
        return cell;
    }
    
    TransactionModel *t = self.filteredTransactions[indexPath.row];
    
    // Card background
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(16, 4, self.view.frame.size.width - 32, 64)];
    card.backgroundColor = [UIColor colorWithWhite:1 alpha:0.7];
    card.layer.cornerRadius = 16;
    card.layer.shadowColor = [UIColor colorWithWhite:0.4 alpha:0.1].CGColor;
    card.layer.shadowOffset = CGSizeMake(0, 2);
    card.layer.shadowOpacity = 1;
    card.layer.shadowRadius = 8;
    [cell.contentView addSubview:card];
    
    // Platform dot
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(12, 22, 8, 8)];
    dot.backgroundColor = [t platformColor];
    dot.layer.cornerRadius = 4;
    [card addSubview:dot];
    
    // Merchant
    UILabel *merchant = [[UILabel alloc] initWithFrame:CGRectMake(28, 8, card.frame.size.width - 120, 20)];
    merchant.text = t.merchant.length ? t.merchant : t.platformDisplayName;
    merchant.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [card addSubview:merchant];
    
    // Category
    UILabel *cat = [[UILabel alloc] initWithFrame:CGRectMake(28, 30, 100, 16)];
    cat.text = t.category;
    cat.font = [UIFont systemFontOfSize:12];
    cat.textColor = [UIColor lightGrayColor];
    [card addSubview:cat];
    
    // Date
    UILabel *date = [[UILabel alloc] initWithFrame:CGRectMake(28, 46, 120, 14)];
    date.text = [NSString stringWithFormat:@"%@ %@", [t formattedDate], [t formattedTime]];
    date.font = [UIFont systemFontOfSize:11];
    date.textColor = [UIColor lightGrayColor];
    [card addSubview:date];
    
    // Amount
    UILabel *amount = [[UILabel alloc] initWithFrame:CGRectMake(card.frame.size.width - 120, 12, 108, 24)];
    amount.text = t.formattedAmount;
    amount.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    amount.textColor = t.type == TransactionTypeExpense ? [UIColor systemRedColor] : [UIColor systemGreenColor];
    amount.textAlignment = NSTextAlignmentRight;
    [card addSubview:amount];
    
    // Platform label
    UILabel *platform = [[UILabel alloc] initWithFrame:CGRectMake(card.frame.size.width - 120, 38, 108, 16)];
    platform.text = t.platformDisplayName;
    platform.font = [UIFont systemFontOfSize:11];
    platform.textColor = [t platformColor];
    platform.textAlignment = NSTextAlignmentRight;
    [card addSubview:platform];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && indexPath.row < self.filteredTransactions.count) {
        TransactionModel *t = self.filteredTransactions[indexPath.row];
        [[DatabaseManager shared] deleteTransaction:t.recordId];
        [self loadData];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.filteredTransactions.count) return;
    TransactionModel *t = self.filteredTransactions[indexPath.row];
    AddTransactionViewController *vc = [[AddTransactionViewController alloc] init];
    vc.editTransaction = t;
    [self.navigationController pushViewController:vc animated:YES];
}

@end
#import "AddTransactionViewController.h"
#import "DatabaseManager.h"
#import "GlassmorphismView.h"

@interface AddTransactionViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *smartInputField;
@property (nonatomic, strong) UITextField *amountField;
@property (nonatomic, strong) UITextField *merchantField;
@property (nonatomic, strong) UISegmentedControl *typeControl;
@property (nonatomic, strong) UISegmentedControl *platformControl;
@property (nonatomic, strong) UICollectionView *categoryGrid;
@property (nonatomic, strong) UITextField *noteField;
@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) NSArray<CategoryModel *> *categories;
@property (nonatomic, strong) NSString *selectedCategory;
@property (nonatomic, strong) NSArray *platformNames;
@end

@implementation AddTransactionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.95 green:0.96 blue:0.98 alpha:1];
    self.categories = [CategoryModel defaultCategories];
    self.platformNames = @[@"微信", @"支付宝", @"银行卡", @"信用卡", @"云闪付", @"现金", @"手动"];
    self.selectedCategory = @"其他";
    
    [self setupHeader];
    [self setupSmartInput];
    [self setupForm];
    [self setupCategoryGrid];
    [self setupSaveButton];
    
    if (self.editTransaction) {
        [self populateWithTransaction:self.editTransaction];
    }
}

- (void)setupHeader {
    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:header];
    
    UILabel *title = [[UILabel alloc] init];
    title.text = self.editTransaction ? @"编辑交易" : @"记一笔";
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

- (void)setupSmartInput {
    GlassmorphismView *smartCard = [GlassmorphismView cardWithFrame:CGRectZero];
    smartCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:smartCard];
    
    UILabel *hint = [[UILabel alloc] init];
    hint.text = @"智能输入";
    hint.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    hint.textColor = [UIColor grayColor];
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    [smartCard addSubview:hint];
    
    _smartInputField = [[UITextField alloc] init];
    _smartInputField.translatesAutoresizingMaskIntoConstraints = NO;
    _smartInputField.placeholder = @"例如：咖啡 32 微信 或 打车 25 支付宝";
    _smartInputField.font = [UIFont systemFontOfSize:15];
    _smartInputField.borderStyle = UITextBorderStyleNone;
    _smartInputField.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
    _smartInputField.layer.cornerRadius = 12;
    _smartInputField.clipsToBounds = YES;
    _smartInputField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 0)];
    _smartInputField.leftViewMode = UITextFieldViewModeAlways;
    _smartInputField.delegate = self;
    _smartInputField.returnKeyType = UIReturnKeyDone;
    [_smartInputField addTarget:self action:@selector(smartParse) forControlEvents:UIControlEventEditingDidEndOnExit];
    [smartCard addSubview:_smartInputField];
    
    UIButton *parseBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    parseBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [parseBtn setTitle:@"解析" forState:UIControlStateNormal];
    parseBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    parseBtn.backgroundColor = [UIColor systemBlueColor];
    [parseBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    parseBtn.layer.cornerRadius = 14;
    [parseBtn addTarget:self action:@selector(smartParse) forControlEvents:UIControlEventTouchUpInside];
    [smartCard addSubview:parseBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [smartCard.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:110],
        [smartCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [smartCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [smartCard.heightAnchor constraintEqualToConstant:90],
        
        [hint.topAnchor constraintEqualToAnchor:smartCard.topAnchor constant:12],
        [hint.leadingAnchor constraintEqualToAnchor:smartCard.leadingAnchor constant:16],
        
        [_smartInputField.topAnchor constraintEqualToAnchor:hint.bottomAnchor constant:8],
        [_smartInputField.leadingAnchor constraintEqualToAnchor:smartCard.leadingAnchor constant:12],
        [_smartInputField.trailingAnchor constraintEqualToAnchor:parseBtn.leadingAnchor constant:-8],
        [_smartInputField.heightAnchor constraintEqualToConstant:36],
        [_smartInputField.bottomAnchor constraintEqualToAnchor:smartCard.bottomAnchor constant:-12],
        
        [parseBtn.centerYAnchor constraintEqualToAnchor:_smartInputField.centerYAnchor],
        [parseBtn.trailingAnchor constraintEqualToAnchor:smartCard.trailingAnchor constant:-12],
        [parseBtn.widthAnchor constraintEqualToConstant:60],
        [parseBtn.heightAnchor constraintEqualToConstant:30],
    ]];
}

- (void)setupForm {
    GlassmorphismView *formCard = [GlassmorphismView cardWithFrame:CGRectZero];
    formCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:formCard];
    
    CGFloat y = 12;
    CGFloat w = [UIScreen mainScreen].bounds.size.width - 64;
    
    // Type
    UILabel *typeLabel = [self labelWithText:@"类型" frame:CGRectMake(16, y, 60, 20)];
    [formCard addSubview:typeLabel];
    _typeControl = [[UISegmentedControl alloc] initWithItems:@[@"支出", @"收入"]];
    _typeControl.frame = CGRectMake(80, y - 4, 120, 28);
    _typeControl.selectedSegmentIndex = 0;
    [formCard addSubview:_typeControl];
    
    y += 40;
    
    // Amount
    UILabel *amtLabel = [self labelWithText:@"金额" frame:CGRectMake(16, y, 60, 20)];
    [formCard addSubview:amtLabel];
    _amountField = [[UITextField alloc] initWithFrame:CGRectMake(80, y - 4, w - 80, 28)];
    _amountField.placeholder = @"0.00";
    _amountField.keyboardType = UIKeyboardTypeDecimalPad;
    _amountField.font = [UIFont systemFontOfSize:16];
    _amountField.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
    _amountField.layer.cornerRadius = 8;
    _amountField.clipsToBounds = YES;
    _amountField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 0)];
    _amountField.leftViewMode = UITextFieldViewModeAlways;
    [formCard addSubview:_amountField];
    
    y += 36;
    
    // Merchant
    UILabel *merLabel = [self labelWithText:@"商户" frame:CGRectMake(16, y, 60, 20)];
    [formCard addSubview:merLabel];
    _merchantField = [[UITextField alloc] initWithFrame:CGRectMake(80, y - 4, w - 80, 28)];
    _merchantField.placeholder = @"商户名称";
    _merchantField.font = [UIFont systemFontOfSize:16];
    _merchantField.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
    _merchantField.layer.cornerRadius = 8;
    _merchantField.clipsToBounds = YES;
    _merchantField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 0)];
    _merchantField.leftViewMode = UITextFieldViewModeAlways;
    [formCard addSubview:_merchantField];
    
    y += 36;
    
    // Platform
    UILabel *platLabel = [self labelWithText:@"平台" frame:CGRectMake(16, y, 60, 20)];
    [formCard addSubview:platLabel];
    _platformControl = [[UISegmentedControl alloc] initWithItems:self.platformNames];
    _platformControl.frame = CGRectMake(80, y - 4, w - 80, 28);
    _platformControl.selectedSegmentIndex = 6;
    _platformControl.apportionsSegmentWidthsByContent = YES;
    [formCard addSubview:_platformControl];
    
    y += 36;
    
    // Note
    UILabel *noteLabel = [self labelWithText:@"备注" frame:CGRectMake(16, y, 60, 20)];
    [formCard addSubview:noteLabel];
    _noteField = [[UITextField alloc] initWithFrame:CGRectMake(80, y - 4, w - 80, 28)];
    _noteField.placeholder = @"备注（可选）";
    _noteField.font = [UIFont systemFontOfSize:16];
    _noteField.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
    _noteField.layer.cornerRadius = 8;
    _noteField.clipsToBounds = YES;
    _noteField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 0)];
    _noteField.leftViewMode = UITextFieldViewModeAlways;
    [formCard addSubview:_noteField];
    
    // Date
    _datePicker = [[UIDatePicker alloc] init];
    _datePicker.datePickerMode = UIDatePickerModeDateAndTime;
    _datePicker.preferredDatePickerStyle = UIDatePickerStyleCompact;
    _datePicker.frame = CGRectMake(w - 120, 12, 120, 30);
    [formCard addSubview:_datePicker];
    
    y += 36;
    CGFloat cardH = y + 12;
    
    [NSLayoutConstraint activateConstraints:@[
        [formCard.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:210],
        [formCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [formCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [formCard.heightAnchor constraintEqualToConstant:cardH],
    ]];
}

- (UILabel *)labelWithText:(NSString *)text frame:(CGRect)frame {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text;
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    label.textColor = [UIColor darkGrayColor];
    return label;
}

- (void)setupCategoryGrid {
    GlassmorphismView *catCard = [GlassmorphismView cardWithFrame:CGRectZero];
    catCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:catCard];
    
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"分类";
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    label.textColor = [UIColor grayColor];
    [catCard addSubview:label];
    
    // Categories as buttons
    CGFloat btnW = 60;
    CGFloat btnH = 36;
    CGFloat spacing = 8;
    CGFloat startX = 16;
    CGFloat x = startX;
    y = 36;
    
    for (int i = 0; i < self.categories.count; i++) {
        CategoryModel *cat = self.categories[i];
        if (cat.type == TransactionTypeIncome) continue;
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(x, y, btnW, btnH);
        [btn setTitle:cat.name forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        btn.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
        [btn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        btn.layer.cornerRadius = btnH / 2;
        btn.tag = i;
        [btn addTarget:self action:@selector(categoryTapped:) forControlEvents:UIControlEventTouchUpInside];
        [catCard addSubview:btn];
        
        x += btnW + spacing;
        if (x + btnW > [UIScreen mainScreen].bounds.size.width - 32) {
            x = startX;
            y += btnH + spacing;
        }
    }
    
    CGFloat cardH = y + btnH + 16;
    
    [NSLayoutConstraint activateConstraints:@[
        [catCard.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:420],
        [catCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [catCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [catCard.heightAnchor constraintEqualToConstant:cardH],
        
        [label.topAnchor constraintEqualToAnchor:catCard.topAnchor constant:12],
        [label.leadingAnchor constraintEqualToAnchor:catCard.leadingAnchor constant:16],
    ]];
}

- (void)setupSaveButton {
    _saveButton = [PillButton buttonWithTitle:self.editTransaction ? @"更新" : @"保存" color:[UIColor systemBlueColor]];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_saveButton addTarget:self action:@selector(saveTransaction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_saveButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [_saveButton.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-40],
        [_saveButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_saveButton.widthAnchor constraintEqualToConstant:200],
        [_saveButton.heightAnchor constraintEqualToConstant:44],
    ]];
}

- (void)categoryTapped:(UIButton *)sender {
    CategoryModel *cat = self.categories[sender.tag];
    self.selectedCategory = cat.name;
    
    // Update all buttons appearance
    for (UIView *v in sender.superview.subviews) {
        if ([v isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)v;
            btn.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
            [btn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        }
    }
    sender.backgroundColor = [UIColor systemBlueColor];
    [sender setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
}

- (void)smartParse {
    NSString *text = self.smartInputField.text;
    if (!text.length) return;
    
    // Parse: "商户 金额 平台" or "金额 商户" or "商户 金额"
    NSArray *parts = [text componentsSeparatedByString:@" "];
    parts = [parts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
    
    NSString *merchant = @"";
    double amount = 0;
    TransactionPlatform platform = TransactionPlatformManual;
    
    for (NSString *part in parts) {
        // Check if it's an amount
        NSString *clean = [part stringByReplacingOccurrencesOfString:@"¥" withString:@""];
        clean = [clean stringByReplacingOccurrencesOfString:@"￥" withString:@""];
        clean = [clean stringByReplacingOccurrencesOfString:@"元" withString:@""];
        
        double val = [clean doubleValue];
        if (val > 0) {
            amount = val;
            continue;
        }
        
        // Check if it's a platform
        if ([part containsString:@"微信"] || [part containsString:@"微"]) {
            platform = TransactionPlatformWeChat;
            continue;
        }
        if ([part containsString:@"支付宝"] || [part containsString:@"支"] || [part containsString:@"宝"]) {
            platform = TransactionPlatformAlipay;
            continue;
        }
        if ([part containsString:@"银行"] || [part containsString:@"卡"]) {
            platform = TransactionPlatformBankCard;
            continue;
        }
        if ([part containsString:@"信用"] || [part containsString:@"信"]) {
            platform = TransactionPlatformCreditCard;
            continue;
        }
        if ([part containsString:@"云闪付"] || [part containsString:@"银联"]) {
            platform = TransactionPlatformUnionPay;
            continue;
        }
        if ([part containsString:@"现金"]) {
            platform = TransactionPlatformCash;
            continue;
        }
        
        // Otherwise it's a merchant name
        merchant = [merchant stringByAppendingFormat:@"%@ ", part];
    }
    
    merchant = [merchant stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if (amount > 0) {
        self.amountField.text = [NSString stringWithFormat:@"%.2f", amount];
        self.merchantField.text = merchant;
        self.platformControl.selectedSegmentIndex = (NSInteger)platform;
        
        // Auto-categorize
        [self autoCategorize:merchant];
    }
    
    [self.smartInputField resignFirstResponder];
}

- (void)autoCategorize:(NSString *)merchant {
    NSString *lower = merchant.lowercaseString;
    NSDictionary *cats = @{
        @"餐饮": @[@"餐", @"饭", @"吃", @"咖啡", @"茶", @"奶", @"果", @"超", @"便利", @"食", @"菜", @"米", @"面", @"包", @"蛋糕", @"火锅", @"烧烤", @"外卖", @"饿了么", @"美团"],
        @"交通": @[@"打车", @"滴滴", @"出租", @"公交", @"地铁", @"加油", @"停车", @"车", @"汽油", @"柴油"],
        @"购物": @[@"买", @"购", @"淘宝", @"京东", @"拼多多", @"商城", @"店", @"服装", @"鞋", @"数码", @"手机"],
        @"娱乐": @[@"电影", @"游戏", @"KTV", @"健身", @"旅游", @"酒店", @"门票", @"充"],
        @"医疗": @[@"药", @"医院", @"医", @"体检"],
        @"教育": @[@"课", @"书", @"学", @"培训", @"考"],
        @"通讯": @[@"话费", @"流量", @"宽带"],
        @"转账": @[@"转账", @"汇", @"红包", @"还"],
    };
    
    for (NSString *cat in cats) {
        for (NSString *kw in cats[cat]) {
            if ([lower containsString:kw]) {
                self.selectedCategory = cat;
                // Update UI
                [self updateCategoryButton:cat];
                return;
            }
        }
    }
    self.selectedCategory = @"其他";
}

- (void)updateCategoryButton:(NSString *)catName {
    // Find and highlight the matching category button
    UIViewController *parent = self;
    // This is a simplification - in the real app we'd traverse the view hierarchy
    for (UIView *v in self.view.subviews) {
        for (UIView *sv in v.subviews) {
            if ([sv isKindOfClass:[UIButton class]]) {
                UIButton *btn = (UIButton *)sv;
                if ([btn.titleLabel.text isEqualToString:catName]) {
                    btn.backgroundColor = [UIColor systemBlueColor];
                    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                } else {
                    btn.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
                    [btn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
                }
            }
        }
    }
}

- (void)saveTransaction {
    double amount = [self.amountField.text doubleValue];
    if (amount <= 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"请输入有效金额" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    TransactionModel *t = self.editTransaction ?: [[TransactionModel alloc] init];
    t.amount = amount;
    t.type = self.typeControl.selectedSegmentIndex == 0 ? TransactionTypeExpense : TransactionTypeIncome;
    t.merchant = self.merchantField.text ?: @"";
    t.platform = (TransactionPlatform)self.platformControl.selectedSegmentIndex;
    t.category = self.selectedCategory ?: @"其他";
    t.note = self.noteField.text ?: @"";
    t.transactionDate = self.datePicker.date;
    t.source = TransactionSourceManual;
    t.sourceMessageId = [NSString stringWithFormat:@"manual_%@", [NSDate date].description];
    
    if (self.editTransaction) {
        [[DatabaseManager shared] updateTransaction:t];
    } else {
        [[DatabaseManager shared] insertTransaction:t];
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)populateWithTransaction:(TransactionModel *)t {
    self.amountField.text = [NSString stringWithFormat:@"%.2f", t.amount];
    self.merchantField.text = t.merchant;
    self.typeControl.selectedSegmentIndex = t.type == TransactionTypeExpense ? 0 : 1;
    self.platformControl.selectedSegmentIndex = (NSInteger)t.platform;
    self.selectedCategory = t.category;
    self.noteField.text = t.note;
    self.datePicker.date = t.transactionDate;
    [self updateCategoryButton:t.category];
}

- (void)goBack {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
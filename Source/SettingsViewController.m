#import "SettingsViewController.h"
#import "DatabaseManager.h"
#import "SMSParser.h"
#import "NotificationParser.h"
#import "CSVImporter.h"
#import "OCRParser.h"
#import "LLMService.h"
#import "GlassmorphismView.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Photos/Photos.h>

@interface SettingsViewController () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSString *importType;
@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.95 green:0.96 blue:0.98 alpha:1];
    
    self.sections = @[
        @{@"title": @"数据源", @"items": @[
                  @{@"title": @"短信自动解析", @"subtitle": @"读取银行/信用卡消费短信", @"type": @"toggle", @"key": @"sms_enabled"},
                  @{@"title": @"通知自动解析", @"subtitle": @"读取微信/支付宝支付通知", @"type": @"toggle", @"key": @"notif_enabled"},
                  @{@"title": @"立即同步", @"subtitle": @"手动触发数据同步", @"type": @"action", @"action": @"sync"},
                  @{@"title": @"查看数据统计", @"subtitle": @"数据库概况", @"type": @"info", @"action": @"stats"},
              ]},
        @{@"title": @"导入数据", @"items": @[
                  @{@"title": @"导入支付宝账单", @"subtitle": @"从支付宝导出的 CSV 文件", @"type": @"action", @"action": @"import_alipay"},
                  @{@"title": @"导入微信账单", @"subtitle": @"从微信导出的 CSV 文件", @"type": @"action", @"action": @"import_wechat"},
                  @{@"title": @"从相册识别截图", @"subtitle": @"识别支付截图中的交易信息", @"type": @"action", @"action": @"ocr"},
              ]},
        @{@"title": @"识别设置", @"items": @[
                  @{@"title": @"使用大模型识别", @"subtitle": @"开启后截图走云端大模型识别，更准确", @"type": @"toggle", @"key": @"llm_enabled"},
                  @{@"title": @"识别服务商", @"subtitle": @"点击选择服务商", @"type": @"action", @"action": @"select_provider"},
                  @{@"title": @"API Key", @"subtitle": @"显示当前服务商", @"type": @"action", @"action": @"set_api_key"},
              ]},
        @{@"title": @"数据管理", @"items": @[
                  @{@"title": @"导出为 CSV", @"subtitle": @"保存到文件", @"type": @"action", @"action": @"export"},
                  @{@"title": @"清除所有数据", @"subtitle": @"删除全部交易记录", @"type": @"danger", @"action": @"clear"},
              ]},
        @{@"title": @"关于", @"items": @[
                  @{@"title": @"版本", @"subtitle": @"1.1.1", @"type": @"info"},
                  @{@"title": @"数据源存储路径", @"subtitle": [NSString stringWithFormat:@"%@/Documents/expense_tracker.db", NSHomeDirectory()], @"type": @"info"},
              ]},
    ];
    
    [self setupHeader];
    [self setupTableView];
}

- (void)setupHeader {
    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:header];
    
    UILabel *title = [[UILabel alloc] init];
    title.text = @"设置";
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

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16);
    [self.view addSubview:_tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:100],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)goBack {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section][@"items"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section][@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.sections[indexPath.section][@"items"][indexPath.row];
    NSString *type = item[@"type"];
    NSString *action = item[@"action"];
    
    if ([type isEqualToString:@"toggle"]) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        cell.textLabel.text = item[@"title"];
        cell.detailTextLabel.text = item[@"subtitle"];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        
        UISwitch *sw = [[UISwitch alloc] init];
        NSString *key = item[@"key"];
        sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:key];
        // Default to ON for llm_enabled if not set
        if (![[NSUserDefaults standardUserDefaults] objectForKey:key]) {
            sw.on = NO;
        }
        [sw addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    } else if ([type isEqualToString:@"danger"]) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        cell.textLabel.text = item[@"title"];
        cell.detailTextLabel.text = item[@"subtitle"];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        cell.textLabel.textColor = [UIColor systemRedColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    } else if ([action isEqualToString:@"set_api_key"]) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        NSInteger providerIdx = [[NSUserDefaults standardUserDefaults] integerForKey:@"llm_provider"];
        NSString *providerName = [LLMService providerName:(LLMProvider)providerIdx];
        cell.textLabel.text = [NSString stringWithFormat:@"%@ API Key", providerName];
        NSString *key = [[NSUserDefaults standardUserDefaults] stringForKey:@"llm_api_key"];
        if (key.length > 0) {
            NSString *masked = [NSString stringWithFormat:@"••••%@", [key substringFromIndex:MAX(0, (NSInteger)key.length - 4)]];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"已设置: %@", masked];
        } else {
            cell.detailTextLabel.text = @"点击输入";
        }
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    } else if ([action isEqualToString:@"select_provider"]) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        cell.textLabel.text = item[@"title"];
        NSInteger providerIdx = [[NSUserDefaults standardUserDefaults] integerForKey:@"llm_provider"];
        cell.detailTextLabel.text = [LLMService providerName:(LLMProvider)providerIdx];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    } else {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        cell.textLabel.text = item[@"title"];
        cell.detailTextLabel.text = item[@"subtitle"];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = self.sections[indexPath.section][@"items"][indexPath.row];
    NSString *action = item[@"action"];
    
    if ([action isEqualToString:@"sync"]) {
        [self syncData];
    } else if ([action isEqualToString:@"stats"]) {
        [self showStats];
    } else if ([action isEqualToString:@"import_alipay"]) {
        [self importAlipayCSV];
    } else if ([action isEqualToString:@"import_wechat"]) {
        [self importWeChatCSV];
    } else if ([action isEqualToString:@"ocr"]) {
        [self importFromPhoto];
    } else if ([action isEqualToString:@"set_api_key"]) {
        [self showAPIKeyInput];
    } else if ([action isEqualToString:@"select_provider"]) {
        [self showProviderPicker];
    } else if ([action isEqualToString:@"export"]) {
        [self exportCSV];
    } else if ([action isEqualToString:@"clear"]) {
        [self confirmClear];
    }
}

- (void)toggleChanged:(UISwitch *)sender {
    // Find the key from the cell
    UITableViewCell *cell = (UITableViewCell *)sender.superview;
    while (cell && ![cell isKindOfClass:[UITableViewCell class]]) {
        cell = (UITableViewCell *)cell.superview;
    }
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (indexPath) {
        NSDictionary *item = self.sections[indexPath.section][@"items"][indexPath.row];
        NSString *key = item[@"key"] ?: @"";
        [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

#pragma mark - Actions

- (void)syncData {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"同步中" message:@"正在读取数据..." preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL smsEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"sms_enabled"];
        BOOL notifEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"notif_enabled"];
        
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
            [alert dismissViewControllerAnimated:YES completion:^{
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
                
                UIAlertController *done = [UIAlertController alertControllerWithTitle:@"同步完成"
                                           message:msg
                                           preferredStyle:UIAlertControllerStyleAlert];
                [done addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:done animated:YES completion:nil];
            }];
        });
    });
}

- (void)showStats {
    NSInteger count = [[DatabaseManager shared] transactionCount];
    double total = [[DatabaseManager shared] totalExpense];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"数据统计"
                               message:[NSString stringWithFormat:@"总交易数: %ld笔\n总支出: ¥%.2f\n",
                                        (long)count, total]
                               preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)exportCSV {
    NSArray *txns = [[DatabaseManager shared] allTransactions];
    if (!txns.count) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"暂无数据可导出" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    NSMutableString *csv = [NSMutableString stringWithString:@"日期,类型,金额,分类,商户,平台,备注\n"];
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd HH:mm";
    
    for (TransactionModel *t in txns) {
        NSString *type = t.type == TransactionTypeExpense ? @"支出" : @"收入";
        [csv appendFormat:@"%@,%@,%.2f,%@,%@,%@,%@\n",
         [df stringFromDate:t.transactionDate],
         type, t.amount, t.category ?: @"", t.merchant ?: @"",
         t.platformDisplayName, t.note ?: @""];
    }
    
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"expense_export.csv"];
    [csv writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导出成功"
                               message:[NSString stringWithFormat:@"已导出 %ld 条记录到:\n%@", (long)txns.count, path]
                               preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmClear {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认清除"
                               message:@"将删除所有交易记录，此操作不可恢复！"
                               preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确认清除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[DatabaseManager shared] clearAllData];
        UIAlertController *done = [UIAlertController alertControllerWithTitle:@"已清除" message:@"所有数据已删除" preferredStyle:UIAlertControllerStyleAlert];
        [done addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:done animated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - CSV Import

- (void)importAlipayCSV {
    self.importType = @"alipay";
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeCommaSeparatedText] asCopy:YES];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)importWeChatCSV {
    self.importType = @"wechat";
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeCommaSeparatedText] asCopy:YES];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    
    NSString *type = self.importType ?: @"alipay";
    self.importType = nil;
    
    UIAlertController *loading = [UIAlertController alertControllerWithTitle:@"导入中" message:@"正在解析..." preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:loading animated:YES completion:nil];
    
    NSString *filePath = [url path];
    
    void (^importBlock)(NSArray *txns, NSError *error) = ^(NSArray *txns, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [loading dismissViewControllerAnimated:YES completion:^{
                if (error) {
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导入失败"
                                               message:error.localizedDescription
                                               preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:alert animated:YES completion:nil];
                    return;
                }
                
                [[DatabaseManager shared] insertTransactions:txns];
                
                NSString *msg = [NSString stringWithFormat:@"成功导入 %ld 条交易记录", (long)txns.count];
                UIAlertController *done = [UIAlertController alertControllerWithTitle:@"导入完成"
                                           message:msg
                                           preferredStyle:UIAlertControllerStyleAlert];
                [done addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:done animated:YES completion:nil];
            }];
        });
    };
    
    if ([type isEqualToString:@"wechat"]) {
        [[CSVImporter shared] parseWeChatCSV:filePath completion:importBlock];
    } else {
        [[CSVImporter shared] parseAlipayCSV:filePath completion:importBlock];
    }
}

#pragma mark - OCR Screenshot Import

- (void)showProviderPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择识别服务商"
                                message:@"国内大模型，免费使用"
                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSInteger current = [[NSUserDefaults standardUserDefaults] integerForKey:@"llm_provider"];
    
    for (NSInteger i = 0; i <= LLMProviderGemini; i++) {
        NSString *name = [LLMService providerName:(LLMProvider)i];
        NSString *desc = [LLMService providerDescription:(LLMProvider)i];
        BOOL isCurrent = (i == current);
        NSString *title = isCurrent ? [NSString stringWithFormat:@"✅ %@", name] : name;
        UIAlertAction *action = [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction *action) {
            [[NSUserDefaults standardUserDefaults] setInteger:i forKey:@"llm_provider"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.tableView reloadData];
        }];
        [alert addAction:action];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAPIKeyInput {
    NSInteger providerIdx = [[NSUserDefaults standardUserDefaults] integerForKey:@"llm_provider"];
    NSString *providerName = [LLMService providerName:(LLMProvider)providerIdx];
    NSString *providerDesc = [LLMService providerDescription:(LLMProvider)providerIdx];
    NSString *signupURL = [LLMService providerSignupURL:(LLMProvider)providerIdx];
    NSString *currentKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"llm_api_key"] ?: @"";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"%@ API Key", providerName]
                                message:[NSString stringWithFormat:@"%@\n\n获取地址: %@", providerDesc, signupURL]
                                preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = currentKey;
        tf.placeholder = @"输入你的 API Key";
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *key = alert.textFields.firstObject.text ?: @"";
        key = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"llm_api_key"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        if (key.length > 0) {
            [self.tableView reloadData];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)importFromPhoto {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    UIAlertController *loading = [UIAlertController alertControllerWithTitle:@"识别中" message:@"正在分析截图..." preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:loading animated:YES completion:nil];
    
    // Request a smaller image directly from photo library to avoid full-resolution decode
    PHAsset *asset = info[UIImagePickerControllerPHAsset];
    if (asset) {
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        options.synchronous = YES;
        options.resizeMode = PHImageRequestOptionsResizeModeExact;
        
        [[PHImageManager defaultManager] requestImageForAsset:asset
                                                   targetSize:CGSizeMake(600, 600)
                                                  contentMode:PHImageContentModeAspectFit
                                                      options:options
                                                resultHandler:^(UIImage *result, NSDictionary *rinfo) {
            UIImage *image = result ?: info[UIImagePickerControllerOriginalImage];
            [self processOCRImage:image loading:loading];
        }];
    } else {
        UIImage *image = info[UIImagePickerControllerOriginalImage];
        [self processOCRImage:image loading:loading];
    }
}

- (void)processOCRImage:(UIImage *)image loading:(UIAlertController *)loading {
    if (!image) {
        [loading dismissViewControllerAnimated:YES completion:^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"识别失败"
                                       message:@"无法获取图片"
                                       preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }];
        return;
    }
    
    BOOL useLLM = [[NSUserDefaults standardUserDefaults] boolForKey:@"llm_enabled"];
    NSString *apiKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"llm_api_key"];
    NSInteger providerIdx = [[NSUserDefaults standardUserDefaults] integerForKey:@"llm_provider"];
    
    void (^handleResult)(NSArray<TransactionModel *> *, NSError *) = ^(NSArray<TransactionModel *> *transactions, NSError *error) {
        [loading dismissViewControllerAnimated:YES completion:^{
            if (error) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"识别失败"
                                           message:error.localizedDescription
                                           preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
                return;
            }
            
            if (transactions.count == 0) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"识别失败"
                                           message:@"未识别到交易信息，请确保截图包含金额和支付信息"
                                           preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
                return;
            }
            
            [[DatabaseManager shared] insertTransactions:transactions];
            
            TransactionModel *t = transactions.firstObject;
            NSString *detail = [NSString stringWithFormat:@"金额: ¥%.2f\n商户: %@\n平台: %@",
                                fabs(t.amount), t.merchant, [t platformDisplayName]];
            UIAlertController *done = [UIAlertController alertControllerWithTitle:@"识别成功"
                                       message:detail
                                       preferredStyle:UIAlertControllerStyleAlert];
            [done addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:done animated:YES completion:nil];
        }];
    };
    
    if (useLLM && apiKey.length > 0) {
        loading.message = [NSString stringWithFormat:@"正在使用 %@ 识别...", [LLMService providerName:(LLMProvider)providerIdx]];
        [[LLMService shared] recognizeFromImage:image provider:(LLMProvider)providerIdx apiKey:apiKey completion:handleResult];
    } else {
        if (useLLM && apiKey.length == 0) {
            loading.message = @"未设置API Key，使用本地识别...";
        }
        [[OCRParser shared] recognizeFromImage:image completion:handleResult];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end
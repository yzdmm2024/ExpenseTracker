#import "SMSParser.h"
#import <sqlite3.h>
#import <CommonCrypto/CommonDigest.h>

@implementation SMSParser

+ (instancetype)shared {
    static SMSParser *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (NSArray<TransactionModel *> *)parseSMSTransactions {
    NSString *smsPath = @"/var/mobile/Library/SMS/sms.db";
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:smsPath]) return @[];
    
    sqlite3 *smsDB;
    if (sqlite3_open([smsPath UTF8String], &smsDB) != SQLITE_OK) return @[];
    
    // Query: message table with handle_id JOIN to handle table for sender
    NSString *sql = @"SELECT m.text, h.id FROM message m "
    "LEFT JOIN handle h ON m.handle_id = h.ROWID "
    "WHERE m.is_from_me = 0 AND m.text IS NOT NULL "
    "ORDER BY m.date DESC LIMIT 500";
    
    NSMutableArray *transactions = [NSMutableArray array];
    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(smsDB, [sql UTF8String], -1, &stmt, NULL);
    
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        const char *text = (const char *)sqlite3_column_text(stmt, 0);
        const char *sender = (const char *)sqlite3_column_text(stmt, 1);
        
        NSString *body = text ? [NSString stringWithUTF8String:text] : @"";
        NSString *senderStr = sender ? [NSString stringWithUTF8String:sender] : @"";
        
        TransactionModel *t = [self parseSMS:body sender:senderStr];
        if (t) {
            // Dedup key: md5 of body
            t.sourceMessageId = [self md5:body];
            t.source = TransactionSourceSMS;
            [transactions addObject:t];
        }
    }
    
    sqlite3_finalize(stmt);
    sqlite3_close(smsDB);
    
    return transactions;
}

- (TransactionModel *)parseSMS:(NSString *)body sender:(NSString *)sender {
    if (!body.length) return nil;
    
    // Bank name detection from sender
    NSString *bankName = [self detectBankFromSender:sender body:body];
    
    // Extract amount
    double amount = [self extractAmount:body];
    if (amount <= 0) return nil;
    
    // Extract account last 4 digits
    NSString *last4 = [self extractLast4:body];
    
    // Determine platform
    TransactionPlatform platform = [self detectPlatform:body sender:sender bankName:bankName];
    
    // Extract merchant
    NSString *merchant = [self extractMerchant:body];
    
    // Extract date
    NSDate *date = [self extractDate:body];
    if (!date) date = [NSDate date];
    
    // Determine category
    NSString *category = [self categorizeTransaction:body merchant:merchant];
    
    TransactionModel *t = [[TransactionModel alloc] init];
    t.amount = amount;
    t.type = TransactionTypeExpense;
    t.platform = platform;
    t.bankName = bankName;
    t.accountLast4 = last4;
    t.merchant = merchant;
    t.category = category;
    t.note = [body substringToIndex:MIN(100, body.length)];
    t.transactionDate = date;
    t.source = TransactionSourceSMS;
    
    return t;
}

#pragma mark - Regex helpers

- (double)extractAmount:(NSString *)text {
    // Patterns: ¥XX.XX, XX.XX元, 金额XX.XX, 消费XX.XX, 支出XX.XX
    NSArray *patterns = @[
        @"[¥￥]([\\d,.]+)", @"([\\d,.]+)元", @"消费([\\d,.]+)", @"支出([\\d,.]+)",
        @"扣款([\\d,.]+)", @"交易([\\d,.]+)", @"付款([\\d,.]+)", @"([\\d,.]+)人民币"
    ];
    
    for (NSString *pattern in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
        if (match && match.numberOfRanges > 1) {
            NSString *amountStr = [text substringWithRange:[match rangeAtIndex:1]];
            amountStr = [amountStr stringByReplacingOccurrencesOfString:@"," withString:@""];
            return [amountStr doubleValue];
        }
    }
    return 0;
}

- (NSString *)extractLast4:(NSString *)text {
    // Patterns: 尾号XXXX, 尾号****, ****1234, 1234
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?:尾号|尾数|****|\\*{4})(\\d{4})" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (match && match.numberOfRanges > 1) {
        return [text substringWithRange:[match rangeAtIndex:1]];
    }
    // Last 4 digits in context
    regex = [NSRegularExpression regularExpressionWithPattern:@"(\\d{4})(?:消费|支出|扣款|交易)" options:0 error:nil];
    match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (match) return [text substringWithRange:[match rangeAtIndex:1]];
    return @"";
}

- (NSString *)detectBankFromSender:(NSString *)sender body:(NSString *)body {
    NSDictionary *banks = @{
        @"95533": @"建设银行", @"95588": @"工商银行", @"95566": @"中国银行",
        @"95599": @"农业银行", @"95555": @"招商银行", @"95559": @"交通银行",
        @"95561": @"兴业银行", @"95528": @"浦发银行", @"95577": @"华夏银行",
        @"95508": @"广发银行", @"95501": @"平安银行", @"95595": @"光大银行",
        @"95568": @"民生银行", @"95558": @"中信银行", @"95582": @"北京银行",
        @"95526": @"北京农商行", @"95574": @"宁波银行", @"95597": @"南京银行",
    };
    
    if (banks[sender]) return banks[sender];
    
    // Also check body for [XX银行]
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"【(.+?银行)】" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:body options:0 range:NSMakeRange(0, body.length)];
    if (match) return [body substringWithRange:[match rangeAtIndex:1]];
    
    // Check for 银联/云闪付
    if ([body containsString:@"银联"] || [body containsString:@"云闪付"]) return @"银联";
    if ([body containsString:@"支付宝"]) return @"支付宝";
    if ([body containsString:@"微信"]) return @"微信";
    
    return @"";
}

- (TransactionPlatform)detectPlatform:(NSString *)body sender:(NSString *)sender bankName:(NSString *)bankName {
    if ([bankName containsString:@"支付宝"] || [body containsString:@"支付宝"]) return TransactionPlatformAlipay;
    if ([bankName containsString:@"微信"] || [body containsString:@"微信"]) return TransactionPlatformWeChat;
    if ([body containsString:@"云闪付"] || [body containsString:@"银联"]) return TransactionPlatformUnionPay;
    if ([body containsString:@"信用卡"] || [sender containsString:@"信用卡"]) return TransactionPlatformCreditCard;
    if (bankName.length > 0) return TransactionPlatformBankCard;
    return TransactionPlatformManual;
}

- (NSString *)extractMerchant:(NSString *)body {
    // Patterns: 在XX消费, 向XX付款, 商户:XX
    NSArray *patterns = @[
        @"在(.+?)(?:消费|支出|付款|支付)",
        @"向(.+?)(?:转|付款|支付)",
        @"商户[：:]?(.*?)(?:\\d|$)",
        @"消费(?:支出|详情)?[：:](.+?)(?:\\d|$)",
    ];
    
    for (NSString *pattern in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:body options:0 range:NSMakeRange(0, body.length)];
        if (match && match.numberOfRanges > 1) {
            NSString *merchant = [body substringWithRange:[match rangeAtIndex:1]];
            merchant = [merchant stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (merchant.length > 0 && merchant.length < 30) return merchant;
        }
    }
    return @"";
}

- (NSDate *)extractDate:(NSString *)body {
    // Pattern: [MM月DD日] or [MM/DD] or [MM-DD]
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(\\d{1,2})[月/-](\\d{1,2})[日]?" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:body options:0 range:NSMakeRange(0, body.length)];
    if (match) {
        NSInteger month = [[body substringWithRange:[match rangeAtIndex:1]] integerValue];
        NSInteger day = [[body substringWithRange:[match rangeAtIndex:2]] integerValue];
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDateComponents *comp = [cal components:NSCalendarUnitYear fromDate:[NSDate date]];
        comp.month = month;
        comp.day = day;
        comp.hour = [self extractHour:body];
        comp.minute = [self extractMinute:body];
        return [cal dateFromComponents:comp];
    }
    return nil;
}

- (NSInteger)extractHour:(NSString *)body {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(\\d{1,2}):(\\d{2})" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:body options:0 range:NSMakeRange(0, body.length)];
    if (match) return [[body substringWithRange:[match rangeAtIndex:1]] integerValue];
    return 12;
}

- (NSInteger)extractMinute:(NSString *)body {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(\\d{1,2}):(\\d{2})" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:body options:0 range:NSMakeRange(0, body.length)];
    if (match) return [[body substringWithRange:[match rangeAtIndex:2]] integerValue];
    return 0;
}

- (NSString *)categorizeTransaction:(NSString *)body merchant:(NSString *)merchant {
    NSString *fullText = [NSString stringWithFormat:@"%@ %@", body, merchant ?: @""].lowercaseString;
    
    NSDictionary *categories = @{
        @"餐饮": @[@"餐饮", @"吃饭", @"餐厅", @"饭店", @"美食", @"外卖", @"饿了么", @"美团", @"肯德基", @"麦当劳",
                   @"星巴克", @"咖啡", @"奶茶", @"茶饮", @"蛋糕", @"面包", @"食堂", @"小吃", @"火锅", @"烧烤",
                   @"便利店", @"超市", @"生鲜", @"水果店"],
        @"交通": @[@"交通", @"打车", @"滴滴", @"出租车", @"公交", @"地铁", @"高铁", @"火车", @"机票", @"加油",
                   @"加油站", @"停车", @"过路费", @"ETC", @"共享单车"],
        @"购物": @[@"购物", @"淘宝", @"京东", @"拼多多", @"天猫", @"网购", @"商城", @"百货", @"服装", @"鞋",
                   @"箱包", @"数码", @"家电", @"家居", @"日用", @"化妆品", @"饰品"],
        @"居住": @[@"房租", @"水电", @"物业", @"燃气", @"供暖", @"维修", @"装修", @"家具"],
        @"娱乐": @[@"娱乐", @"电影", @"游戏", @"KTV", @"健身", @"旅游", @"酒店", @"门票", @"视频", @"音乐",
                   @"直播", @"打赏", @"充值"],
        @"医疗": @[@"医院", @"药店", @"医疗", @"体检", @"牙科", @"眼科", @"中医", @"挂号", @"药品"],
        @"教育": @[@"教育", @"培训", @"课程", @"学习", @"书", @"教材", @"考试", @"报名", @"学费"],
        @"通讯": @[@"话费", @"流量", @"宽带", @"手机"],
        @"转账": @[@"转账", @"汇款", @"还钱", @"还款", @"红包"],
    };
    
    for (NSString *cat in categories) {
        for (NSString *keyword in categories[cat]) {
            if ([fullText containsString:keyword]) return cat;
        }
    }
    return @"其他";
}

- (NSString *)md5:(NSString *)str {
    const char *cStr = [str UTF8String];
    unsigned char digest[32];
    CC_SHA256(cStr, (CC_LONG)strlen(cStr), digest);
    return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]];
}

@end
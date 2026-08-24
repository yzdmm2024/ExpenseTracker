#import "NotificationParser.h"
#import <sqlite3.h>
#import <CommonCrypto/CommonDigest.h>

@implementation NotificationParser

+ (instancetype)shared {
    static NotificationParser *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (NSArray<TransactionModel *> *)parseNotificationTransactions {
    // Try multiple bulletin board paths for different iOS versions
    NSArray *paths = @[
        @"/var/mobile/Library/BulletinBoard/GlobalBulletinBoard.sqlite",
        @"/var/mobile/Library/BulletinBoard/BBGlobalBulletinBoard.sqlite",
    ];
    
    NSString *bbPath = nil;
    for (NSString *p in paths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
            bbPath = p;
            break;
        }
    }
    if (!bbPath) return @[];
    
    sqlite3 *bbDB;
    if (sqlite3_open([bbPath UTF8String], &bbDB) != SQLITE_OK) return @[];
    
    NSMutableArray *transactions = [NSMutableArray array];
    
    // Try different table structures
    NSArray *queries = @[
        @"SELECT message, sectionID, timestamp FROM record WHERE message IS NOT NULL ORDER BY timestamp DESC LIMIT 500",
        @"SELECT title, sectionID, timestamp FROM record WHERE sectionID IS NOT NULL ORDER BY timestamp DESC LIMIT 500",
        @"SELECT content, sectionID, date FROM bulletin WHERE content IS NOT NULL ORDER BY date DESC LIMIT 500",
    ];
    
    for (NSString *query in queries) {
        sqlite3_stmt *stmt;
        if (sqlite3_prepare_v2(bbDB, [query UTF8String], -1, &stmt, NULL) != SQLITE_OK) continue;
        
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            NSString *text = @"";
            NSString *section = @"";
            
            if (sqlite3_column_type(stmt, 0) == SQLITE_TEXT) {
                const char *t = (const char *)sqlite3_column_text(stmt, 0);
                if (t) text = [NSString stringWithUTF8String:t];
            }
            if (sqlite3_column_type(stmt, 1) == SQLITE_TEXT) {
                const char *s = (const char *)sqlite3_column_text(stmt, 1);
                if (s) section = [NSString stringWithUTF8String:s];
            }
            
            NSString *combined = [NSString stringWithFormat:@"%@ %@", section, text];
            TransactionModel *t = [self parseNotification:combined sectionID:section];
            if (t) {
                t.sourceMessageId = [self md5:[NSString stringWithFormat:@"%@-%@", section, text]];
                t.source = TransactionSourceNotification;
                [transactions addObject:t];
            }
        }
        sqlite3_finalize(stmt);
        break; // Only use first successful query
    }
    
    sqlite3_close(bbDB);
    return transactions;
}

- (TransactionModel *)parseNotification:(NSString *)text sectionID:(NSString *)sectionID {
    if (!text.length) return nil;
    
    // Filter only payment-related apps
    BOOL isPayment = NO;
    NSArray *paymentApps = @[@"com.tencent.xin", @"com.alipay", @"com.tencent.mqq",
                             @"com.unionpay", @"wechat", @"alipay", @"微信", @"支付宝", @"云闪付"];
    for (NSString *app in paymentApps) {
        if ([sectionID.lowercaseString containsString:app.lowercaseString] ||
            [text.lowercaseString containsString:app.lowercaseString]) {
            isPayment = YES;
            break;
        }
    }
    
    // Also check for bank/credit card keywords
    NSArray *bankKeywords = @[@"银行", @"信用卡", @"消费", @"支", @"付款", @"转账", @"还款", @"到账"];
    if (!isPayment) {
        for (NSString *kw in bankKeywords) {
            if ([text containsString:kw]) { isPayment = YES; break; }
        }
    }
    if (!isPayment) return nil;
    
    // Extract amount
    double amount = [self extractAmount:text];
    if (amount <= 0) return nil;
    
    TransactionModel *t = [[TransactionModel alloc] init];
    t.amount = amount;
    t.type = TransactionTypeExpense;
    t.transactionDate = [NSDate date];
    
    // Detect platform
    if ([text containsString:@"微信"] || [sectionID containsString:@"tencent.xin"]) {
        t.platform = TransactionPlatformWeChat;
    } else if ([text containsString:@"支付宝"] || [sectionID containsString:@"alipay"]) {
        t.platform = TransactionPlatformAlipay;
    } else if ([text containsString:@"云闪付"] || [sectionID containsString:@"unionpay"]) {
        t.platform = TransactionPlatformUnionPay;
    } else {
        t.platform = TransactionPlatformBankCard;
    }
    
    // Extract merchant
    t.merchant = [self extractMerchant:text];
    
    // Categorize
    t.category = [self categorizeTransaction:text merchant:t.merchant];
    
    t.note = [text substringToIndex:MIN(100, text.length)];
    
    return t;
}

- (double)extractAmount:(NSString *)text {
    NSArray *patterns = @[
        @"[¥￥]([\\d,.]+)", @"([\\d,.]+)元", @"消费([\\d,.]+)", @"支出([\\d,.]+)",
        @"付款([\\d,.]+)", @"([\\d,.]+)人民币", @"到账([\\d,.]+)",
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

- (NSString *)extractMerchant:(NSString *)text {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?:向|给|在)(.+?)(?:转|付款|支付|消费)" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (match && match.numberOfRanges > 1) {
        NSString *merchant = [text substringWithRange:[match rangeAtIndex:1]];
        merchant = [merchant stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (merchant.length > 0 && merchant.length < 30) return merchant;
    }
    return @"";
}

- (NSString *)categorizeTransaction:(NSString *)text merchant:(NSString *)merchant {
    NSString *full = [NSString stringWithFormat:@"%@ %@", text, merchant ?: @""].lowercaseString;
    NSDictionary *cats = @{
        @"餐饮": @[@"餐饮", @"吃饭", @"餐厅", @"外卖", @"饿了么", @"美团", @"肯德基", @"咖啡", @"奶茶", @"食堂", @"小吃", @"火锅", @"超市", @"便利店", @"水果"],
        @"交通": @[@"打车", @"滴滴", @"出租", @"公交", @"地铁", @"高铁", @"火车", @"加油", @"停车", @"ETC"],
        @"购物": @[@"淘宝", @"京东", @"拼多多", @"天猫", @"购物", @"商城", @"服装", @"数码"],
        @"娱乐": @[@"电影", @"游戏", @"KTV", @"健身", @"旅游", @"酒店", @"充值", @"打赏"],
        @"医疗": @[@"医院", @"药店", @"体检"],
        @"教育": @[@"课程", @"学习", @"书", @"培训"],
        @"通讯": @[@"话费", @"流量", @"宽带"],
        @"转账": @[@"转账", @"汇款", @"红包", @"还款"],
    };
    for (NSString *cat in cats) {
        for (NSString *kw in cats[cat]) {
            if ([full containsString:kw]) return cat;
        }
    }
    return @"其他";
}

- (NSString *)md5:(NSString *)str {
    const char *cStr = [str UTF8String];
    unsigned char digest[16];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
    return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]];
}

@end
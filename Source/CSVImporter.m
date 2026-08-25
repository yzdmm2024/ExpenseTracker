#import "CSVImporter.h"
#import "DatabaseManager.h"
#import <CommonCrypto/CommonDigest.h>

@implementation CSVImporter

+ (instancetype)shared {
    static CSVImporter *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CSVImporter alloc] init];
    });
    return instance;
}

// 支付宝 CSV 格式：
// 前 25 行是说明，第 25 行是表头，第 26 行开始是数据
// 表头: 交易时间, 交易分类, 交易对方, 对方账号, 商品说明, 收/支, 金额, 收/付款方式, 交易状态, 交易订单号, 商家订单号, 备注
- (void)parseAlipayCSV:(NSString *)filePath completion:(void(^)(NSArray<TransactionModel *> *transactions, NSError *error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            // Try GBK encoding
            content = [NSString stringWithContentsOfFile:filePath encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000) error:&error];
        }
        if (error || !content) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error ?: [NSError errorWithDomain:@"CSVImporter" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"无法读取文件"}]);
            });
            return;
        }
        
        NSArray *lines = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        // Skip first 24 lines (header info), line 25 is header, data starts from line 26
        NSMutableArray *transactions = [NSMutableArray array];
        BOOL headerFound = NO;
        NSInteger headerIndex = -1;
        
        for (NSInteger i = 0; i < lines.count; i++) {
            NSString *line = [lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (line.length == 0) continue;
            
            NSArray *cols = [self parseCSVLine:line];
            if (cols.count < 5) continue;
            
            // Detect header row
            if (!headerFound) {
                for (NSString *col in cols) {
                    if ([col containsString:@"交易时间"] || [col containsString:@"收/支"]) {
                        headerFound = YES;
                        headerIndex = i;
                        break;
                    }
                }
                continue;
            }
            
            // Data rows - only after header
            if (i <= headerIndex) continue;
            
            // Map columns: 交易时间, 交易分类, 交易对方, 对方账号, 商品说明, 收/支, 金额, 收/付款方式, 交易状态, 交易订单号, 商家订单号, 备注
            NSString *timeStr = cols.count > 0 ? cols[0] : @"";
            NSString *category = cols.count > 1 ? cols[1] : @"";
            NSString *merchant = cols.count > 2 ? cols[2] : @"";
            NSString *product = cols.count > 4 ? cols[4] : @"";
            NSString *type = cols.count > 5 ? cols[5] : @"";
            NSString *amountStr = cols.count > 6 ? cols[6] : @"";
            NSString *status = cols.count > 8 ? cols[8] : @"";
            NSString *remark = cols.count > 11 ? cols[11] : @"";
            
            // Skip if no amount
            if (amountStr.length == 0) continue;
            
            // Only process completed transactions
            if ([status containsString:@"退款"] || [status containsString:@"关闭"] || [status containsString:@"失败"]) continue;
            
            // Parse amount
            double amount = [amountStr doubleValue];
            if (amount <= 0) continue;
            
            // Determine direction
            BOOL isIncome = [type containsString:@"收入"];
            
            // Parse date
            NSDate *date = [self parseDate:timeStr];
            
            // Determine category
            NSString *finalCategory = [self mapAlipayCategory:category product:product];
            
            TransactionModel *t = [[TransactionModel alloc] init];
            t.amount = amount;
            t.type = isIncome ? TransactionTypeIncome : TransactionTypeExpense;
            t.category = finalCategory;
            t.merchant = merchant.length > 0 ? merchant : (product.length > 0 ? product : @"支付宝");
            t.transactionDate = date ?: [NSDate date];
            t.platform = TransactionPlatformAlipay;
            t.note = [self combineNote:product remark:remark];
            t.source = TransactionSourceManual;
            t.sourceMessageId = [self generateIdForMerchant:merchant amount:amount date:date];
            
            [transactions addObject:t];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(transactions, nil);
        });
    });
}

// 微信 CSV 格式：
// 前 16 行是说明，第 17 行是表头，第 18 行开始是数据
// 表头: 交易时间, 交易类型, 交易对方, 商品, 收/支, 金额, 支付方式, 当前状态, 交易单号, 商户单号, 备注
- (void)parseWeChatCSV:(NSString *)filePath completion:(void(^)(NSArray<TransactionModel *> *transactions, NSError *error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            content = [NSString stringWithContentsOfFile:filePath encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000) error:&error];
        }
        if (error || !content) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error ?: [NSError errorWithDomain:@"CSVImporter" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"无法读取文件"}]);
            });
            return;
        }
        
        NSArray *lines = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        NSMutableArray *transactions = [NSMutableArray array];
        BOOL headerFound = NO;
        NSInteger headerIndex = -1;
        
        for (NSInteger i = 0; i < lines.count; i++) {
            NSString *line = [lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (line.length == 0) continue;
            
            NSArray *cols = [self parseCSVLine:line];
            if (cols.count < 5) continue;
            
            if (!headerFound) {
                for (NSString *col in cols) {
                    if ([col containsString:@"交易时间"] || [col containsString:@"收/支"]) {
                        headerFound = YES;
                        headerIndex = i;
                        break;
                    }
                }
                continue;
            }
            
            if (i <= headerIndex) continue;
            
            // Map columns: 交易时间, 交易类型, 交易对方, 商品, 收/支, 金额, 支付方式, 当前状态, 交易单号, 商户单号, 备注
            NSString *timeStr = cols.count > 0 ? cols[0] : @"";
            NSString *type = cols.count > 1 ? cols[1] : @"";
            NSString *merchant = cols.count > 2 ? cols[2] : @"";
            NSString *product = cols.count > 3 ? cols[3] : @"";
            NSString *direction = cols.count > 4 ? cols[4] : @"";
            NSString *amountStr = cols.count > 5 ? cols[5] : @"";
            NSString *status = cols.count > 7 ? cols[7] : @"";
            NSString *remark = cols.count > 10 ? cols[10] : @"";
            
            if (amountStr.length == 0) continue;
            if ([status containsString:@"退款"] || [status containsString:@"已全额退款"] || [status containsString:@"失败"]) continue;
            
            double amount = [amountStr doubleValue];
            if (amount <= 0) continue;
            
            // "/" means income in WeChat CSV
            BOOL isIncome = [direction containsString:@"/"];
            
            NSDate *date = [self parseDate:timeStr];
            NSString *finalCategory = [self mapWeChatCategory:type product:product];
            
            TransactionModel *t = [[TransactionModel alloc] init];
            t.amount = amount;
            t.type = isIncome ? TransactionTypeIncome : TransactionTypeExpense;
            t.category = finalCategory;
            t.merchant = merchant.length > 0 ? merchant : (product.length > 0 ? product : @"微信");
            t.transactionDate = date ?: [NSDate date];
            t.platform = TransactionPlatformWeChat;
            t.note = [self combineNote:product remark:remark];
            t.source = TransactionSourceManual;
            t.sourceMessageId = [self generateIdForMerchant:merchant amount:amount date:date];
            
            [transactions addObject:t];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(transactions, nil);
        });
    });
}

#pragma mark - Helpers

- (NSArray *)parseCSVLine:(NSString *)line {
    NSMutableArray *result = [NSMutableArray array];
    NSScanner *scanner = [NSScanner scannerWithString:line];
    scanner.charactersToBeSkipped = nil;
    NSCharacterSet *quote = [NSCharacterSet characterSetWithCharactersInString:@"\""];
    NSCharacterSet *comma = [NSCharacterSet characterSetWithCharactersInString:@","];
    NSCharacterSet *newline = [NSCharacterSet newlineCharacterSet];
    
    while (![scanner isAtEnd]) {
        NSString *field = @"";
        if ([scanner scanString:@"\"" intoString:nil]) {
            // Quoted field
            NSMutableString *quoted = [NSMutableString string];
            NSString *part = nil;
            while (![scanner isAtEnd]) {
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\""] intoString:&part];
                if (part) [quoted appendString:part];
                if ([scanner scanString:@"\"\"" intoString:nil]) {
                    [quoted appendString:@"\""];
                } else if ([scanner scanString:@"\"" intoString:nil]) {
                    break;
                }
            }
            field = [quoted copy];
        } else {
            [scanner scanUpToCharactersFromSet:comma intoString:&field];
        }
        [result addObject:[field stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        [scanner scanString:@"," intoString:nil];
    }
    return result;
}

- (NSDate *)parseDate:(NSString *)str {
    str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    
    NSArray *formats = @[@"yyyy-MM-dd HH:mm:ss", @"yyyy/MM/dd HH:mm", @"yyyy-MM-dd HH:mm",
                         @"yyyy/MM/dd HH:mm:ss", @"yyyy-MM-dd"];
    for (NSString *f in formats) {
        fmt.dateFormat = f;
        NSDate *date = [fmt dateFromString:str];
        if (date) return date;
    }
    return [NSDate date];
}

- (NSString *)mapAlipayCategory:(NSString *)category product:(NSString *)product {
    if ([category containsString:@"餐饮"] || [category containsString:@"美食"]) return @"餐饮";
    if ([category containsString:@"交通"] || [category containsString:@"出行"]) return @"交通";
    if ([category containsString:@"购物"] || [category containsString:@"百货"]) return @"购物";
    if ([category containsString:@"日用"] || [category containsString:@"生活"]) return @"生活";
    if ([category containsString:@"娱乐"] || [category containsString:@"休闲"]) return @"娱乐";
    if ([category containsString:@"医疗"] || [category containsString:@"健康"]) return @"医疗";
    if ([category containsString:@"教育"] || [category containsString:@"学习"]) return @"教育";
    if ([category containsString:@"通讯"] || [category containsString:@"话费"]) return @"通讯";
    if ([category containsString:@"转账"] || [category containsString:@"红包"]) return @"转账";
    if ([category containsString:@"理财"]) return @"理财";
    return @"其他";
}

- (NSString *)mapWeChatCategory:(NSString *)type product:(NSString *)product {
    if ([type containsString:@"餐饮"] || [type containsString:@"美食"]) return @"餐饮";
    if ([type containsString:@"交通"] || [type containsString:@"出行"]) return @"交通";
    if ([type containsString:@"购物"] || [type containsString:@"百货"]) return @"购物";
    if ([type containsString:@"生活缴费"] || [type containsString:@"水电"]) return @"生活";
    if ([type containsString:@"娱乐"] || [type containsString:@"休闲"]) return @"娱乐";
    if ([type containsString:@"医疗"] || [type containsString:@"健康"]) return @"医疗";
    if ([type containsString:@"教育"] || [type containsString:@"学习"]) return @"教育";
    if ([type containsString:@"转账"] || [type containsString:@"红包"]) return @"转账";
    if ([type containsString:@"理财"]) return @"理财";
    if ([type containsString:@"商户消费"]) return @"购物";
    return @"其他";
}

- (NSString *)combineNote:(NSString *)product remark:(NSString *)remark {
    if (product.length > 0 && remark.length > 0) {
        return [NSString stringWithFormat:@"%@ | %@", product, remark];
    }
    return product.length > 0 ? product : (remark.length > 0 ? remark : @"");
}

- (NSString *)generateIdForMerchant:(NSString *)merchant amount:(double)amount date:(NSDate *)date {
    NSString *raw = [NSString stringWithFormat:@"csv_%@%@%f", merchant ?: @"", [date description], amount];
    const char *cStr = [raw UTF8String];
    unsigned char digest[32];
    CC_SHA256(cStr, (CC_LONG)strlen(cStr), digest);
    return [NSString stringWithFormat:@"csv_%02x%02x%02x%02x%02x%02x%02x%02x",
            digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7]];
}

@end
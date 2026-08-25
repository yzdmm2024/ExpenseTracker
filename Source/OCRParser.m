#import "OCRParser.h"
#import <Vision/Vision.h>
#import <CommonCrypto/CommonDigest.h>

@implementation OCRParser

+ (instancetype)shared {
    static OCRParser *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[OCRParser alloc] init];
    });
    return instance;
}

- (void)recognizeFromImage:(UIImage *)image completion:(void(^)(NSArray<TransactionModel *> *transactions, NSError *error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGImageRef cgImage = image.CGImage;
        if (!cgImage) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"OCRParser" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"无效图片"}]);
            });
            return;
        }
        
        VNRecognizeTextRequest *request = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest *req, NSError *err) {
            if (err) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, err);
                });
                return;
            }
            
            // Extract all recognized text
            NSMutableArray *allText = [NSMutableArray array];
            NSMutableDictionary *textByY = [NSMutableDictionary dictionary];
            
            for (VNRecognizedTextObservation *obs in req.results) {
                VNRecognizedText *top = [obs topCandidates:1].firstObject;
                if (top) {
                    [allText addObject:top.string];
                    // Group by Y position (line)
                    NSString *yKey = [NSString stringWithFormat:@"%.0f", obs.boundingBox.origin.y * 1000];
                    NSMutableArray *line = textByY[yKey] ?: [NSMutableArray array];
                    [line addObject:top.string];
                    textByY[yKey] = line;
                }
            }
            
            // Try to parse transactions from the recognized text
            NSArray *transactions = [self parseTransactionsFromText:allText groupedByY:textByY];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(transactions, nil);
            });
        }];
        
        request.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
        request.recognitionLanguages = @[@"zh-Hans", @"en-US"];
        request.usesLanguageCorrection = YES;
        
        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cgImage options:@{}];
        NSError *handlerError = nil;
        [handler performRequests:@[request] error:&handlerError];
        
        if (handlerError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, handlerError);
            });
        }
    });
}

- (NSArray<TransactionModel *> *)parseTransactionsFromText:(NSArray *)allText groupedByY:(NSDictionary *)textByY {
    NSString *fullText = [allText componentsJoinedByString:@"\n"];
    
    // Detect platform from text
    NSString *platform = [self detectPlatform:fullText];
    
    // Extract amount
    double amount = [self extractAmount:fullText];
    
    // Extract merchant
    NSString *merchant = [self extractMerchant:fullText platform:platform];
    
    // Extract date
    NSDate *date = [self extractDate:fullText];
    
    // Extract time
    NSString *time = [self extractTime:fullText];
    
    // Determine direction (income/expense)
    BOOL isIncome = [self isIncome:fullText];
    
    // Determine category
    NSString *category = [self determineCategory:fullText merchant:merchant];
    
    if (amount <= 0) return @[];
    
    TransactionModel *t = [[TransactionModel alloc] init];
    t.amount = amount;
    t.type = isIncome ? TransactionTypeIncome : TransactionTypeExpense;
    t.category = category;
    t.merchant = merchant.length > 0 ? merchant : @"截图识别";
    t.transactionDate = date ?: [NSDate date];
    t.platform = [self platformEnum:platform];
    t.note = [NSString stringWithFormat:@"截图识别 | %@", time];
    t.source = TransactionSourceManual;
    t.sourceMessageId = [self generateId:t];
    
    return @[t];
}

#pragma mark - Platform Detection

- (NSString *)detectPlatform:(NSString *)text {
    if ([text containsString:@"支付宝"] || [text containsString:@"Alipay"]) return @"支付宝";
    if ([text containsString:@"微信支付"] || [text containsString:@"微信"]) return @"微信";
    if ([text containsString:@"云闪付"] || [text containsString:@"UnionPay"]) return @"云闪付";
    if ([text containsString:@"Apple Pay"] || [text containsString:@"apple"]) return @"Apple Pay";
    if ([text containsString:@"银行卡"] || [text containsString:@"信用卡"] || [text containsString:@"银行"]) return @"银行卡";
    return @"截图识别";
}

#pragma mark - Amount Extraction

- (double)extractAmount:(NSString *)text {
    // Pattern: ¥123.45, ￥123.45, 123.45元, total/HKD/USD etc
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[¥￥]\\s*([\\d,]+[.]?\\d*)" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (match) {
        NSString *amt = [text substringWithRange:[match rangeAtIndex:1]];
        amt = [amt stringByReplacingOccurrencesOfString:@"," withString:@""];
        return [amt doubleValue];
    }
    
    // Try: xxx.xx元
    regex = [NSRegularExpression regularExpressionWithPattern:@"([\\d,]+[.]?\\d*)\\s*元" options:0 error:nil];
    match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (match) {
        NSString *amt = [text substringWithRange:[match rangeAtIndex:1]];
        amt = [amt stringByReplacingOccurrencesOfString:@"," withString:@""];
        return [amt doubleValue];
    }
    
    // Try: HKD/USD xxx.xx
    regex = [NSRegularExpression regularExpressionWithPattern:@"(?:HKD|USD|CNY)\\s*([\\d,]+[.]?\\d*)" options:0 error:nil];
    match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (match) {
        NSString *amt = [text substringWithRange:[match rangeAtIndex:1]];
        amt = [amt stringByReplacingOccurrencesOfString:@"," withString:@""];
        return [amt doubleValue];
    }
    
    return 0;
}

#pragma mark - Merchant Extraction

- (NSString *)extractMerchant:(NSString *)text platform:(NSString *)platform {
    // Try to find merchant name after "收款方" or "商户"
    NSArray *patterns = @[
        @"收款方[：: ]\\s*(\\S+)",
        @"商户[：: ]\\s*(\\S+)",
        @"商家[：: ]\\s*(\\S+)",
        @"付款给[：: ]\\s*(\\S+)",
        @"转入[：: ]\\s*(\\S+)",
    ];
    
    for (NSString *pattern in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
        if (match) {
            NSString *merchant = [text substringWithRange:[match rangeAtIndex:1]];
            merchant = [merchant stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (merchant.length > 0 && merchant.length < 30) return merchant;
        }
    }
    
    return @"";
}

#pragma mark - Date/Time Extraction

- (NSDate *)extractDate:(NSString *)text {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(\\d{4})[-/年](\\d{1,2})[-/月](\\d{1,2})" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (match) {
        NSInteger year = [[text substringWithRange:[match rangeAtIndex:1]] integerValue];
        NSInteger month = [[text substringWithRange:[match rangeAtIndex:2]] integerValue];
        NSInteger day = [[text substringWithRange:[match rangeAtIndex:3]] integerValue];
        
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDateComponents *comp = [[NSDateComponents alloc] init];
        comp.year = year;
        comp.month = month;
        comp.day = day;
        return [cal dateFromComponents:comp];
    }
    return nil;
}

- (NSString *)extractTime:(NSString *)text {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(\\d{2}:\\d{2}(:\\d{2})?)" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (match) {
        return [text substringWithRange:match.range];
    }
    return @"";
}

#pragma mark - Direction

- (BOOL)isIncome:(NSString *)text {
    // Check for income indicators
    NSArray *incomeWords = @[@"收入", @"收款", @"转入", @"+", @"到账", @"退款", @"退回"];
    for (NSString *w in incomeWords) {
        if ([text containsString:w]) return YES;
    }
    return NO;
}

#pragma mark - Category

- (NSString *)determineCategory:(NSString *)text merchant:(NSString *)merchant {
    NSString *combined = [NSString stringWithFormat:@"%@ %@", text, merchant];
    if ([combined containsString:@"餐饮"] || [combined containsString:@"餐厅"] || [combined containsString:@"美食"] || [combined containsString:@"咖啡"] || [combined containsString:@"茶"]) return @"餐饮";
    if ([combined containsString:@"交通"] || [combined containsString:@"地铁"] || [combined containsString:@"公交"] || [combined containsString:@"打车"] || [combined containsString:@"加油"] || [combined containsString:@"滴滴"]) return @"交通";
    if ([combined containsString:@"购物"] || [combined containsString:@"超市"] || [combined containsString:@"商场"] || [combined containsString:@"便利店"] || [combined containsString:@"京东"] || [combined containsString:@"淘宝"]) return @"购物";
    if ([combined containsString:@"娱乐"] || [combined containsString:@"电影"] || [combined containsString:@"游戏"] || [combined containsString:@"视频"]) return @"娱乐";
    if ([combined containsString:@"医疗"] || [combined containsString:@"药店"] || [combined containsString:@"医院"]) return @"医疗";
    if ([combined containsString:@"教育"] || [combined containsString:@"课程"] || [combined containsString:@"培训"]) return @"教育";
    if ([combined containsString:@"话费"] || [combined containsString:@"流量"] || [combined containsString:@"通讯"]) return @"通讯";
    if ([combined containsString:@"生活"] || [combined containsString:@"水电"] || [combined containsString:@"物业"]) return @"生活";
    return @"其他";
}

- (NSString *)generateId:(TransactionModel *)t {
    NSString *raw = [NSString stringWithFormat:@"ocr_%@%@%@%f", t.merchant, t.category, [t.transactionDate description], t.amount];
    const char *cStr = [raw UTF8String];
    unsigned char digest[32];
    CC_SHA256(cStr, (CC_LONG)strlen(cStr), digest);
    return [NSString stringWithFormat:@"ocr_%02x%02x%02x%02x%02x%02x%02x%02x",
            digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7]];
}

- (TransactionPlatform)platformEnum:(NSString *)platform {
    if ([platform containsString:@"支付宝"]) return TransactionPlatformAlipay;
    if ([platform containsString:@"微信"]) return TransactionPlatformWeChat;
    if ([platform containsString:@"云闪付"]) return TransactionPlatformUnionPay;
    if ([platform containsString:@"Apple"]) return TransactionPlatformCreditCard;
    if ([platform containsString:@"银行卡"]) return TransactionPlatformBankCard;
    return TransactionPlatformManual;
}

@end
#import "TransactionModel.h"

@implementation TransactionModel

- (NSString *)platformDisplayName {
    switch (self.platform) {
        case TransactionPlatformWeChat: return @"微信";
        case TransactionPlatformAlipay: return @"支付宝";
        case TransactionPlatformBankCard: return @"银行卡";
        case TransactionPlatformCreditCard: return @"信用卡";
        case TransactionPlatformUnionPay: return @"云闪付";
        case TransactionPlatformCash: return @"现金";
        case TransactionPlatformManual: return @"手动";
    }
}

- (UIColor *)platformColor {
    switch (self.platform) {
        case TransactionPlatformWeChat: return [UIColor colorWithRed:0.07 green:0.74 blue:0.15 alpha:1];
        case TransactionPlatformAlipay: return [UIColor colorWithRed:0.13 green:0.59 blue:0.95 alpha:1];
        case TransactionPlatformBankCard: return [UIColor colorWithRed:0.95 green:0.40 blue:0.20 alpha:1];
        case TransactionPlatformCreditCard: return [UIColor colorWithRed:0.80 green:0.32 blue:0.80 alpha:1];
        case TransactionPlatformUnionPay: return [UIColor colorWithRed:0.90 green:0.20 blue:0.20 alpha:1];
        case TransactionPlatformCash: return [UIColor colorWithRed:0.30 green:0.75 blue:0.35 alpha:1];
        case TransactionPlatformManual: return [UIColor colorWithRed:0.50 green:0.50 blue:0.50 alpha:1];
    }
}

- (NSString *)sourceDisplayName {
    switch (self.source) {
        case TransactionSourceSMS: return @"短信";
        case TransactionSourceNotification: return @"通知";
        case TransactionSourceManual: return @"手动";
    }
}

- (NSString *)formattedAmount {
    NSString *prefix = self.type == TransactionTypeExpense ? @"-" : @"+";
    return [NSString stringWithFormat:@"%@¥%.2f", prefix, self.amount];
}

- (NSString *)formattedDate {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"MM月dd日";
    return [df stringFromDate:self.transactionDate];
}

- (NSString *)formattedTime {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"HH:mm";
    return [df stringFromDate:self.transactionDate];
}

@end

@implementation CategoryModel

+ (NSArray<CategoryModel *> *)defaultCategories {
    return @[
        [self category:@"餐饮" icon:@"🍜" color:[UIColor colorWithRed:1 green:0.6 blue:0.2 alpha:1] type:TransactionTypeExpense],
        [self category:@"交通" icon:@"🚗" color:[UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:1] type:TransactionTypeExpense],
        [self category:@"购物" icon:@"🛒" color:[UIColor colorWithRed:1 green:0.3 blue:0.3 alpha:1] type:TransactionTypeExpense],
        [self category:@"居住" icon:@"🏠" color:[UIColor colorWithRed:0.4 green:0.7 blue:0.4 alpha:1] type:TransactionTypeExpense],
        [self category:@"娱乐" icon:@"🎮" color:[UIColor colorWithRed:0.7 green:0.4 blue:0.9 alpha:1] type:TransactionTypeExpense],
        [self category:@"医疗" icon:@"💊" color:[UIColor colorWithRed:0.9 green:0.4 blue:0.4 alpha:1] type:TransactionTypeExpense],
        [self category:@"教育" icon:@"📚" color:[UIColor colorWithRed:0.3 green:0.6 blue:0.8 alpha:1] type:TransactionTypeExpense],
        [self category:@"通讯" icon:@"📱" color:[UIColor colorWithRed:0.3 green:0.8 blue:0.7 alpha:1] type:TransactionTypeExpense],
        [self category:@"转账" icon:@"💸" color:[UIColor colorWithRed:0.8 green:0.5 blue:0.2 alpha:1] type:TransactionTypeExpense],
        [self category:@"收入" icon:@"💰" color:[UIColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1] type:TransactionTypeIncome],
        [self category:@"其他" icon:@"📦" color:[UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1] type:TransactionTypeExpense],
    ];
}

+ (instancetype)category:(NSString *)name icon:(NSString *)icon color:(UIColor *)color type:(TransactionType)type {
    CategoryModel *c = [[self alloc] init];
    c.name = name; c.icon = icon; c.color = color; c.type = type;
    return c;
}

@end

@implementation MonthlySummary
@end
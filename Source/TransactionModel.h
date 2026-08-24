#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, TransactionType) {
    TransactionTypeExpense = 0,
    TransactionTypeIncome
};

typedef NS_ENUM(NSInteger, TransactionSource) {
    TransactionSourceSMS = 0,
    TransactionSourceNotification,
    TransactionSourceManual
};

typedef NS_ENUM(NSInteger, TransactionPlatform) {
    TransactionPlatformWeChat = 0,
    TransactionPlatformAlipay,
    TransactionPlatformBankCard,
    TransactionPlatformCreditCard,
    TransactionPlatformUnionPay,
    TransactionPlatformCash,
    TransactionPlatformManual
};

@interface TransactionModel : NSObject

@property (nonatomic, assign) NSInteger recordId;
@property (nonatomic, assign) double amount;
@property (nonatomic, assign) TransactionType type;
@property (nonatomic, strong) NSString *category;
@property (nonatomic, strong) NSString *merchant;
@property (nonatomic, assign) TransactionPlatform platform;
@property (nonatomic, strong) NSString *accountLast4;
@property (nonatomic, strong) NSString *bankName;
@property (nonatomic, strong) NSString *note;
@property (nonatomic, strong) NSDate *transactionDate;
@property (nonatomic, strong) NSString *sourceMessageId;
@property (nonatomic, assign) TransactionSource source;

- (NSString *)platformDisplayName;
- (UIColor *)platformColor;
- (NSString *)sourceDisplayName;
- (NSString *)formattedAmount;
- (NSString *)formattedDate;
- (NSString *)formattedTime;

@end

@interface CategoryModel : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *icon;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) TransactionType type;
@property (nonatomic, assign) NSInteger sortOrder;

+ (NSArray<CategoryModel *> *)defaultCategories;
@end

@interface MonthlySummary : NSObject
@property (nonatomic, strong) NSString *yearMonth;
@property (nonatomic, assign) double totalExpense;
@property (nonatomic, assign) double totalIncome;
@property (nonatomic, assign) NSInteger transactionCount;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *categoryBreakdown;
@end
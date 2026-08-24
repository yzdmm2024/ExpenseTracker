#import <Foundation/Foundation.h>
#import "TransactionModel.h"

@interface SMSParser : NSObject

+ (instancetype)shared;

/// Read SMS database and parse bank/credit card transactions
- (NSArray<TransactionModel *> *)parseSMSTransactions;

/// Test parse a single SMS message
- (TransactionModel *)parseSMS:(NSString *)body sender:(NSString *)sender;

@end
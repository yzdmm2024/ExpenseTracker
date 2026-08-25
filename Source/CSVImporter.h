#import <Foundation/Foundation.h>
#import "TransactionModel.h"

@interface CSVImporter : NSObject

+ (instancetype)shared;

- (void)parseAlipayCSV:(NSString *)filePath completion:(void(^)(NSArray<TransactionModel *> *transactions, NSError *error))completion;
- (void)parseWeChatCSV:(NSString *)filePath completion:(void(^)(NSArray<TransactionModel *> *transactions, NSError *error))completion;

@end

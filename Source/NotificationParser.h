#import <Foundation/Foundation.h>
#import "TransactionModel.h"

@interface NotificationParser : NSObject

+ (instancetype)shared;

/// Read BulletinBoard notification database and parse payment notifications
- (NSArray<TransactionModel *> *)parseNotificationTransactions;

@end
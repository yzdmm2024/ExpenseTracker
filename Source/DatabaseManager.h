#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import "TransactionModel.h"

@interface DatabaseManager : NSObject

+ (instancetype)shared;

- (void)setupDatabase;
- (void)insertTransaction:(TransactionModel *)transaction;
- (void)insertTransactions:(NSArray<TransactionModel *> *)transactions;
- (void)updateTransaction:(TransactionModel *)transaction;
- (void)deleteTransaction:(NSInteger)recordId;
- (TransactionModel *)transactionById:(NSInteger)recordId;
- (NSArray<TransactionModel *> *)allTransactions;
- (NSArray<TransactionModel *> *)transactionsForMonth:(NSString *)yearMonth;
- (NSArray<TransactionModel *> *)transactionsForDate:(NSDate *)date;
- (NSArray<TransactionModel *> *)searchTransactions:(NSString *)keyword;
- (NSArray<TransactionModel *> *)transactionsForPlatform:(TransactionPlatform)platform;
- (BOOL)transactionExistsWithMessageId:(NSString *)messageId;

- (MonthlySummary *)summaryForMonth:(NSString *)yearMonth;
- (NSArray<MonthlySummary *> *)summariesForYear:(NSString *)year;
- (NSArray<NSDictionary *> *)dailyTotalsForMonth:(NSString *)yearMonth;

- (NSInteger)transactionCount;
- (double)totalExpense;
- (double)totalExpenseForMonth:(NSString *)yearMonth;

- (void)clearAllData;

@end
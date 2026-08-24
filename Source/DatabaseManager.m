#import "DatabaseManager.h"

@interface DatabaseManager ()
@property (nonatomic, assign) sqlite3 *db;
@property (nonatomic, strong) NSString *dbPath;
@end

@implementation DatabaseManager

+ (instancetype)shared {
    static DatabaseManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (NSString *)dbPath {
    if (!_dbPath) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docDir = paths.firstObject;
        _dbPath = [docDir stringByAppendingPathComponent:@"expense_tracker.db"];
    }
    return _dbPath;
}

- (void)setupDatabase {
    sqlite3_open([self.dbPath UTF8String], &_db);
    
    NSString *sql = @"CREATE TABLE IF NOT EXISTS transactions ("
    "id INTEGER PRIMARY KEY AUTOINCREMENT,"
    "amount REAL NOT NULL,"
    "type INTEGER NOT NULL DEFAULT 0,"
    "category TEXT,"
    "merchant TEXT,"
    "platform INTEGER NOT NULL DEFAULT 6,"
    "account_last4 TEXT,"
    "bank_name TEXT,"
    "note TEXT,"
    "transaction_date TEXT NOT NULL,"
    "source INTEGER NOT NULL DEFAULT 2,"
    "source_message_id TEXT UNIQUE,"
    "created_at TEXT DEFAULT (datetime('now','localtime'))"
    ");";
    
    sqlite3_exec(self.db, [sql UTF8String], NULL, NULL, NULL);
    sqlite3_exec(self.db, "CREATE INDEX IF NOT EXISTS idx_date ON transactions(transaction_date)", NULL, NULL, NULL);
    sqlite3_exec(self.db, "CREATE INDEX IF NOT EXISTS idx_msgid ON transactions(source_message_id)", NULL, NULL, NULL);
}

- (void)dealloc {
    sqlite3_close(_db);
}

#pragma mark - CRUD

- (void)insertTransaction:(TransactionModel *)t {
    NSString *sql = @"INSERT OR IGNORE INTO transactions "
    "(amount, type, category, merchant, platform, account_last4, bank_name, note, transaction_date, source, source_message_id) "
    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
    
    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(self.db, [sql UTF8String], -1, &stmt, NULL);
    
    sqlite3_bind_double(stmt, 1, t.amount);
    sqlite3_bind_int(stmt, 2, (int)t.type);
    sqlite3_bind_text(stmt, 3, [t.category UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 4, [t.merchant UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_int(stmt, 5, (int)t.platform);
    sqlite3_bind_text(stmt, 6, [t.accountLast4 UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 7, [t.bankName UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 8, [t.note UTF8String], -1, SQLITE_TRANSIENT);
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    sqlite3_bind_text(stmt, 9, [[df stringFromDate:t.transactionDate] UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_int(stmt, 10, (int)t.source);
    sqlite3_bind_text(stmt, 11, [t.sourceMessageId UTF8String], -1, SQLITE_TRANSIENT);
    
    sqlite3_step(stmt);
    sqlite3_finalize(stmt);
}

- (void)insertTransactions:(NSArray<TransactionModel *> *)transactions {
    sqlite3_exec(self.db, "BEGIN TRANSACTION", NULL, NULL, NULL);
    for (TransactionModel *t in transactions) {
        [self insertTransaction:t];
    }
    sqlite3_exec(self.db, "COMMIT", NULL, NULL, NULL);
}

- (void)updateTransaction:(TransactionModel *)t {
    NSString *sql = @"UPDATE transactions SET amount=?, type=?, category=?, merchant=?, "
    "platform=?, account_last4=?, bank_name=?, note=? WHERE id=?";
    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(self.db, [sql UTF8String], -1, &stmt, NULL);
    sqlite3_bind_double(stmt, 1, t.amount);
    sqlite3_bind_int(stmt, 2, (int)t.type);
    sqlite3_bind_text(stmt, 3, [t.category UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 4, [t.merchant UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_int(stmt, 5, (int)t.platform);
    sqlite3_bind_text(stmt, 6, [t.accountLast4 UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 7, [t.bankName UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 8, [t.note UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_int(stmt, 9, (int)t.recordId);
    sqlite3_step(stmt);
    sqlite3_finalize(stmt);
}

- (void)deleteTransaction:(NSInteger)recordId {
    sqlite3_exec(self.db, [[NSString stringWithFormat:@"DELETE FROM transactions WHERE id=%ld", (long)recordId] UTF8String], NULL, NULL, NULL);
}

- (TransactionModel *)transactionById:(NSInteger)recordId {
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM transactions WHERE id=%ld", (long)recordId];
    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(self.db, [sql UTF8String], -1, &stmt, NULL);
    TransactionModel *t = nil;
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        t = [self transactionFromStmt:stmt];
    }
    sqlite3_finalize(stmt);
    return t;
}

#pragma mark - Query

- (NSArray<TransactionModel *> *)allTransactions {
    return [self query:@"SELECT * FROM transactions ORDER BY transaction_date DESC"];
}

- (NSArray<TransactionModel *> *)transactionsForMonth:(NSString *)yearMonth {
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM transactions WHERE transaction_date LIKE '%@%%' ORDER BY transaction_date DESC", yearMonth];
    return [self query:sql];
}

- (NSArray<TransactionModel *> *)transactionsForDate:(NSDate *)date {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd";
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM transactions WHERE transaction_date LIKE '%@%%' ORDER BY transaction_date DESC", [df stringFromDate:date]];
    return [self query:sql];
}

- (NSArray<TransactionModel *> *)searchTransactions:(NSString *)keyword {
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM transactions WHERE merchant LIKE '%%%@%%' OR category LIKE '%%%@%%' OR note LIKE '%%%@%%' ORDER BY transaction_date DESC", keyword, keyword, keyword];
    return [self query:sql];
}

- (NSArray<TransactionModel *> *)transactionsForPlatform:(TransactionPlatform)platform {
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM transactions WHERE platform=%d ORDER BY transaction_date DESC", (int)platform];
    return [self query:sql];
}

- (BOOL)transactionExistsWithMessageId:(NSString *)messageId {
    if (!messageId.length) return NO;
    NSString *sql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM transactions WHERE source_message_id='%@'", messageId];
    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(self.db, [sql UTF8String], -1, &stmt, NULL);
    BOOL exists = NO;
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        exists = sqlite3_column_int(stmt, 0) > 0;
    }
    sqlite3_finalize(stmt);
    return exists;
}

#pragma mark - Summary

- (MonthlySummary *)summaryForMonth:(NSString *)yearMonth {
    NSArray *txns = [self transactionsForMonth:yearMonth];
    MonthlySummary *s = [[MonthlySummary alloc] init];
    s.yearMonth = yearMonth;
    s.transactionCount = txns.count;
    
    NSMutableDictionary *breakdown = [NSMutableDictionary dictionary];
    for (TransactionModel *t in txns) {
        if (t.type == TransactionTypeExpense) {
            s.totalExpense += t.amount;
            NSString *cat = t.category ?: @"其他";
            breakdown[cat] = @([breakdown[cat] doubleValue] + t.amount);
        } else {
            s.totalIncome += t.amount;
        }
    }
    s.categoryBreakdown = breakdown;
    return s;
}

- (NSArray<MonthlySummary *> *)summariesForYear:(NSString *)year {
    NSMutableArray *result = [NSMutableArray array];
    for (int m = 1; m <= 12; m++) {
        NSString *ym = [NSString stringWithFormat:@"%@-%02d", year, m];
        MonthlySummary *s = [self summaryForMonth:ym];
        if (s.transactionCount > 0) [result addObject:s];
    }
    return result;
}

- (NSArray<NSDictionary *> *)dailyTotalsForMonth:(NSString *)yearMonth {
    NSArray *txns = [self transactionsForMonth:yearMonth];
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSMutableDictionary *daily = [NSMutableDictionary dictionary];
    
    for (TransactionModel *t in txns) {
        if (t.type != TransactionTypeExpense) continue;
        NSInteger day = [cal component:NSCalendarUnitDay fromDate:t.transactionDate];
        NSString *key = [NSString stringWithFormat:@"%ld", (long)day];
        daily[key] = @([daily[key] doubleValue] + t.amount);
    }
    
    NSMutableArray *result = [NSMutableArray array];
    [daily enumerateKeysAndObjectsUsingBlock:^(NSString *day, NSNumber *total, BOOL *stop) {
        [result addObject:@{@"day": day, @"total": total}];
    }];
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"day"] compare:b[@"day"]];
    }];
    return result;
}

#pragma mark - Aggregates

- (NSInteger)transactionCount {
    return [self intQuery:@"SELECT COUNT(*) FROM transactions"];
}

- (double)totalExpense {
    return [self doubleQuery:@"SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE type=0"];
}

- (double)totalExpenseForMonth:(NSString *)yearMonth {
    NSString *sql = [NSString stringWithFormat:@"SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE type=0 AND transaction_date LIKE '%@%%'", yearMonth];
    return [self doubleQuery:sql];
}

- (void)clearAllData {
    sqlite3_exec(self.db, "DELETE FROM transactions", NULL, NULL, NULL);
}

#pragma mark - Helpers

- (TransactionModel *)transactionFromStmt:(sqlite3_stmt *)stmt {
    TransactionModel *t = [[TransactionModel alloc] init];
    t.recordId = sqlite3_column_int(stmt, 0);
    t.amount = sqlite3_column_double(stmt, 1);
    t.type = (TransactionType)sqlite3_column_int(stmt, 2);
    
    const char *cat = (const char *)sqlite3_column_text(stmt, 3);
    t.category = cat ? [NSString stringWithUTF8String:cat] : @"其他";
    
    const char *mer = (const char *)sqlite3_column_text(stmt, 4);
    t.merchant = mer ? [NSString stringWithUTF8String:mer] : @"";
    
    t.platform = (TransactionPlatform)sqlite3_column_int(stmt, 5);
    
    const char *last4 = (const char *)sqlite3_column_text(stmt, 6);
    t.accountLast4 = last4 ? [NSString stringWithUTF8String:last4] : @"";
    
    const char *bank = (const char *)sqlite3_column_text(stmt, 7);
    t.bankName = bank ? [NSString stringWithUTF8String:bank] : @"";
    
    const char *note = (const char *)sqlite3_column_text(stmt, 8);
    t.note = note ? [NSString stringWithUTF8String:note] : @"";
    
    const char *date = (const char *)sqlite3_column_text(stmt, 9);
    if (date) {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        t.transactionDate = [df dateFromString:[NSString stringWithUTF8String:date]];
    }
    
    t.source = (TransactionSource)sqlite3_column_int(stmt, 10);
    
    const char *msgId = (const char *)sqlite3_column_text(stmt, 11);
    t.sourceMessageId = msgId ? [NSString stringWithUTF8String:msgId] : @"";
    
    return t;
}

- (NSArray<TransactionModel *> *)query:(NSString *)sql {
    NSMutableArray *results = [NSMutableArray array];
    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(self.db, [sql UTF8String], -1, &stmt, NULL);
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        [results addObject:[self transactionFromStmt:stmt]];
    }
    sqlite3_finalize(stmt);
    return results;
}

- (NSInteger)intQuery:(NSString *)sql {
    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(self.db, [sql UTF8String], -1, &stmt, NULL);
    NSInteger result = 0;
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        result = sqlite3_column_int(stmt, 0);
    }
    sqlite3_finalize(stmt);
    return result;
}

- (double)doubleQuery:(NSString *)sql {
    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(self.db, [sql UTF8String], -1, &stmt, NULL);
    double result = 0;
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        result = sqlite3_column_double(stmt, 0);
    }
    sqlite3_finalize(stmt);
    return result;
}

@end
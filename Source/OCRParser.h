#import <UIKit/UIKit.h>
#import "TransactionModel.h"

@interface OCRParser : NSObject

+ (instancetype)shared;

- (void)recognizeFromImage:(UIImage *)image completion:(void(^)(NSArray<TransactionModel *> *transactions, NSError *error))completion;

@end
#import <UIKit/UIKit.h>
#import "TransactionModel.h"

@interface LLMService : NSObject

+ (instancetype)shared;

/// 使用 Gemini API 识别图片中的交易信息
- (void)recognizeFromImage:(UIImage *)image
                   apiKey:(NSString *)apiKey
               completion:(void(^)(NSArray<TransactionModel *> *transactions, NSError *error))completion;

@end
#import <UIKit/UIKit.h>
#import "TransactionModel.h"

typedef NS_ENUM(NSInteger, LLMProvider) {
    LLMProviderZhipu = 0,   // 智谱 GLM-4V-Flash（完全免费）
    LLMProviderQwen   = 1,  // 通义千问 Qwen-VL-Plus（DashScope）
    LLMProviderGemini = 2,  // Google Gemini 1.5 Flash
};

@interface LLMService : NSObject

+ (instancetype)shared;

/// 使用指定服务商识别图片中的交易信息
- (void)recognizeFromImage:(UIImage *)image
                  provider:(LLMProvider)provider
                   apiKey:(NSString *)apiKey
               completion:(void(^)(NSArray<TransactionModel *> *transactions, NSError *error))completion;

/// 获取服务商名称
+ (NSString *)providerName:(LLMProvider)provider;

/// 获取服务商描述
+ (NSString *)providerDescription:(LLMProvider)provider;

/// 获取服务商注册链接
+ (NSString *)providerSignupURL:(LLMProvider)provider;

@end
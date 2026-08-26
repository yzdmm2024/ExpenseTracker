#import "LLMService.h"
#import <CommonCrypto/CommonDigest.h>

@implementation LLMService

+ (instancetype)shared {
    static LLMService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LLMService alloc] init];
    });
    return instance;
}

+ (NSString *)providerName:(LLMProvider)provider {
    switch (provider) {
        case LLMProviderZhipu: return @"智谱AI (GLM-4V-Flash)";
        case LLMProviderQwen:  return @"通义千问 (Qwen-VL-Plus)";
        case LLMProviderGemini: return @"Google Gemini";
    }
}

+ (NSString *)providerDescription:(LLMProvider)provider {
    switch (provider) {
        case LLMProviderZhipu: return @"GLM-4V-Flash 免费使用，在 open.bigmodel.cn 获取 Key";
        case LLMProviderQwen:  return @"新用户送 ¥200 额度，在 dashscope.aliyun.com 获取 Key";
        case LLMProviderGemini: return @"免费额度充足，在 aistudio.google.com 获取 Key";
    }
}

+ (NSString *)providerSignupURL:(LLMProvider)provider {
    switch (provider) {
        case LLMProviderZhipu: return @"https://open.bigmodel.cn/";
        case LLMProviderQwen:  return @"https://dashscope.aliyun.com/";
        case LLMProviderGemini: return @"https://aistudio.google.com/apikey";
    }
}

#pragma mark - Image Processing

- (UIImage *)resizeImage:(UIImage *)image maxDimension:(CGFloat)maxDim {
    CGFloat w = image.size.width;
    CGFloat h = image.size.height;
    if (w <= maxDim && h <= maxDim) return image;
    CGFloat ratio = (w > h) ? (maxDim / w) : (maxDim / h);
    CGSize newSize = CGSizeMake(w * ratio, h * ratio);
    UIGraphicsBeginImageContextWithOptions(newSize, YES, 1.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resized;
}

- (NSString *)base64Image:(UIImage *)image {
    UIImage *resized = [self resizeImage:image maxDimension:800];
    NSData *jpegData = UIImageJPEGRepresentation(resized, 0.8);
    if (!jpegData) return nil;
    return [jpegData base64EncodedStringWithOptions:0];
}

#pragma mark - Main API

- (void)recognizeFromImage:(UIImage *)image
                  provider:(LLMProvider)provider
                   apiKey:(NSString *)apiKey
               completion:(void(^)(NSArray<TransactionModel *> *transactions, NSError *error))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *base64 = [self base64Image:image];
        if (!base64) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"LLMService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"图片处理失败"}]);
            });
            return;
        }
        
        // Build request based on provider
        NSURL *url = nil;
        NSDictionary *body = nil;
        
        switch (provider) {
            case LLMProviderZhipu:
                url = [NSURL URLWithString:@"https://open.bigmodel.cn/api/paas/v4/chat/completions"];
                body = [self buildZhipuBodyWithBase64:base64];
                break;
            case LLMProviderQwen:
                url = [NSURL URLWithString:@"https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"];
                body = [self buildQwenBodyWithBase64:base64];
                break;
            case LLMProviderGemini:
                url = [NSURL URLWithString:[NSString stringWithFormat:@"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=%@", apiKey]];
                body = [self buildGeminiBodyWithBase64:base64];
                break;
        }
        
        if (!url || !body) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"LLMService" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"无效的配置"}]);
            });
            return;
        }
        
        NSError *jsonError = nil;
        NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
        if (jsonError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"LLMService" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"请求构建失败"}]);
            });
            return;
        }
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = @"POST";
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        request.timeoutInterval = 30;
        
        // Set auth header (Gemini uses URL param, others use Bearer)
        if (provider != LLMProviderGemini) {
            [request setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];
        }
        request.HTTPBody = bodyData;
        
        // Send request
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block NSArray *result = nil;
        __block NSError *resultError = nil;
        
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *connError) {
                
                if (connError) {
                    resultError = [NSError errorWithDomain:@"LLMService" code:-4
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"网络错误: %@", connError.localizedDescription]}];
                    dispatch_semaphore_signal(semaphore);
                    return;
                }
                
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if (httpResponse.statusCode != 200) {
                    NSString *body = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
                    resultError = [NSError errorWithDomain:@"LLMService" code:-5
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"API错误(%ld): %@", (long)httpResponse.statusCode, body]}];
                    dispatch_semaphore_signal(semaphore);
                    return;
                }
                
                // Parse response
                NSError *parseError = nil;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
                if (parseError) {
                    resultError = [NSError errorWithDomain:@"LLMService" code:-6
                                                 userInfo:@{NSLocalizedDescriptionKey: @"解析响应失败"}];
                    dispatch_semaphore_signal(semaphore);
                    return;
                }
                
                // Extract text from provider-specific response
                NSString *text = nil;
                switch (provider) {
                    case LLMProviderZhipu:
                    case LLMProviderQwen: {
                        // OpenAI-compatible response
                        NSString *content = json[@"choices"][0][@"message"][@"content"];
                        if (content) text = content;
                        break;
                    }
                    case LLMProviderGemini: {
                        // Gemini response
                        text = json[@"candidates"][0][@"content"][@"parts"][0][@"text"];
                        if (!text) {
                            NSString *blockReason = json[@"candidates"][0][@"finishReason"];
                            if ([blockReason isEqualToString:@"SAFETY"]) {
                                resultError = [NSError errorWithDomain:@"LLMService" code:-7
                                                             userInfo:@{NSLocalizedDescriptionKey: @"图片内容被安全机制拦截，请选择其他截图"}];
                            }
                        }
                        break;
                    }
                }
                
                if (!text && !resultError) {
                    resultError = [NSError errorWithDomain:@"LLMService" code:-8
                                                 userInfo:@{NSLocalizedDescriptionKey: @"API返回异常，请重试"}];
                }
                
                if (resultError) {
                    dispatch_semaphore_signal(semaphore);
                    return;
                }
                
                // Extract JSON from response text
                NSString *jsonStr = [self extractJSONFromText:text];
                if (!jsonStr) {
                    resultError = [NSError errorWithDomain:@"LLMService" code:-9
                                                 userInfo:@{NSLocalizedDescriptionKey: @"大模型返回格式异常，建议切换到本地识别"}];
                    dispatch_semaphore_signal(semaphore);
                    return;
                }
                
                NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *txnJson = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
                if (!txnJson) {
                    resultError = [NSError errorWithDomain:@"LLMService" code:-10
                                                 userInfo:@{NSLocalizedDescriptionKey: @"解析交易信息失败"}];
                    dispatch_semaphore_signal(semaphore);
                    return;
                }
                
                // Check for error in response
                if (txnJson[@"error"]) {
                    resultError = [NSError errorWithDomain:@"LLMService" code:-11
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"未识别到交易信息: %@", txnJson[@"error"]]}];
                    dispatch_semaphore_signal(semaphore);
                    return;
                }
                
                // Build TransactionModel
                TransactionModel *t = [self transactionFromJSON:txnJson];
                if (t) {
                    result = @[t];
                } else {
                    resultError = [NSError errorWithDomain:@"LLMService" code:-12
                                                 userInfo:@{NSLocalizedDescriptionKey: @"提取的交易信息不完整"}];
                }
                dispatch_semaphore_signal(semaphore);
            }];
        
        [task resume];
        
        // Wait with 30-second timeout
        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC);
        if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
            [task cancel];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"LLMService" code:-13
                                             userInfo:@{NSLocalizedDescriptionKey: @"请求超时，请检查网络连接"}]);
            });
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (resultError) {
                completion(nil, resultError);
            } else {
                completion(result, nil);
            }
        });
    });
}

#pragma mark - Provider-Specific Request Builders

- (NSString *)promptText {
    return @"你是一个支付截图识别助手。请仔细查看这张支付截图，提取以下交易信息并返回JSON：\n"
    "1. amount: 金额（数字，如 123.45）\n"
    "2. merchant: 商户名称\n"
    "3. date: 交易日期（格式 YYYY-MM-DD）\n"
    "4. time: 交易时间（格式 HH:MM）\n"
    "5. platform: 支付方式（支付宝/微信支付/云闪付/银行卡/Apple Pay/其他）\n"
    "6. type: 交易类型（expense 支出 / income 收入）\n"
    "7. category: 消费类别（餐饮/交通/购物/娱乐/医疗/教育/通讯/生活/其他）\n\n"
    "请严格按照JSON格式返回，不要包含其他文字：\n"
    "{\"amount\":123.45,\"merchant\":\"商户名\",\"date\":\"2024-01-01\",\"time\":\"12:00\",\"platform\":\"支付宝\",\"type\":\"expense\",\"category\":\"购物\"}\n"
    "如果无法识别任何信息，返回：{\"error\":\"无法识别\"}";
}

- (NSDictionary *)buildZhipuBodyWithBase64:(NSString *)base64 {
    NSString *dataUrl = [NSString stringWithFormat:@"data:image/jpeg;base64,%@", base64];
    return @{
        @"model": @"glm-4v-flash",
        @"messages": @[@{
            @"role": @"user",
            @"content": @[
                @{@"type": @"text", @"text": [self promptText]},
                @{@"type": @"image_url", @"image_url": @{@"url": dataUrl}}
            ]
        }],
        @"temperature": @0.1,
        @"max_tokens": @256
    };
}

- (NSDictionary *)buildQwenBodyWithBase64:(NSString *)base64 {
    NSString *dataUrl = [NSString stringWithFormat:@"data:image/jpeg;base64,%@", base64];
    return @{
        @"model": @"qwen-vl-plus",
        @"messages": @[@{
            @"role": @"user",
            @"content": @[
                @{@"type": @"image_url", @"image_url": @{@"url": dataUrl}},
                @{@"type": @"text", @"text": [self promptText]}
            ]
        }],
        @"temperature": @0.1,
        @"max_tokens": @256
    };
}

- (NSDictionary *)buildGeminiBodyWithBase64:(NSString *)base64 {
    return @{
        @"contents": @[@{
            @"parts": @[
                @{@"text": [self promptText]},
                @{@"inline_data": @{
                        @"mime_type": @"image/jpeg",
                        @"data": base64
                }}
            ]
        }],
        @"generationConfig": @{
            @"temperature": @0.1,
            @"maxOutputTokens": @256
        }
    };
}

#pragma mark - Response Parsing

- (NSString *)extractJSONFromText:(NSString *)text {
    // Try to find JSON in markdown code block
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"```(?:json)?\\s*([\\s\\S]*?)```" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (match) {
        return [text substringWithRange:[match rangeAtIndex:1]];
    }
    // Try to find {...} directly
    NSRange braceRange = [text rangeOfString:@"{"];
    if (braceRange.location != NSNotFound) {
        NSInteger depth = 0;
        NSInteger start = braceRange.location;
        for (NSInteger i = start; i < text.length; i++) {
            unichar c = [text characterAtIndex:i];
            if (c == '{') depth++;
            else if (c == '}') depth--;
            if (depth == 0) {
                return [text substringWithRange:NSMakeRange(start, i - start + 1)];
            }
        }
    }
    return nil;
}

- (TransactionModel *)transactionFromJSON:(NSDictionary *)json {
    double amount = [json[@"amount"] doubleValue];
    if (amount <= 0) return nil;
    
    NSString *typeStr = json[@"type"] ?: @"expense";
    NSString *platform = json[@"platform"] ?: @"";
    NSString *merchant = json[@"merchant"] ?: @"";
    NSString *category = json[@"category"] ?: @"其他";
    NSString *dateStr = json[@"date"] ?: @"";
    NSString *timeStr = json[@"time"] ?: @"";
    
    TransactionModel *t = [[TransactionModel alloc] init];
    t.amount = amount;
    t.type = [typeStr containsString:@"income"] ? TransactionTypeIncome : TransactionTypeExpense;
    t.merchant = merchant.length > 0 ? merchant : @"大模型识别";
    t.category = category;
    t.platform = [self platformEnum:platform];
    t.transactionDate = [self parseDate:dateStr] ?: [NSDate date];
    t.note = [NSString stringWithFormat:@"大模型识别 | %@", timeStr.length > 0 ? timeStr : @""];
    t.source = TransactionSourceManual;
    t.sourceMessageId = [self generateId:t];
    
    return t;
}

- (NSDate *)parseDate:(NSString *)dateStr {
    if (dateStr.length < 10) return nil;
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyy-MM-dd";
    return [fmt dateFromString:dateStr];
}

- (TransactionPlatform)platformEnum:(NSString *)platform {
    if ([platform containsString:@"支付宝"]) return TransactionPlatformAlipay;
    if ([platform containsString:@"微信"]) return TransactionPlatformWeChat;
    if ([platform containsString:@"云闪付"]) return TransactionPlatformUnionPay;
    if ([platform containsString:@"Apple"]) return TransactionPlatformCreditCard;
    if ([platform containsString:@"银行卡"]) return TransactionPlatformBankCard;
    return TransactionPlatformManual;
}

- (NSString *)generateId:(TransactionModel *)t {
    NSString *raw = [NSString stringWithFormat:@"llm_%@%@%@%f", t.merchant, t.category, [t.transactionDate description], t.amount];
    const char *cStr = [raw UTF8String];
    unsigned char digest[32];
    CC_SHA256(cStr, (CC_LONG)strlen(cStr), digest);
    return [NSString stringWithFormat:@"llm_%02x%02x%02x%02x%02x%02x%02x%02x",
            digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7]];
}

@end
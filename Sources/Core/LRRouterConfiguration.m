#import "LRRouting.h"

static const NSUInteger LRMaximumConfigBytes = 1024 * 1024;

static BOOL LRSetConfigurationError(NSError **error, NSString *message) {
    if (error != NULL) {
        *error = [NSError errorWithDomain:LRRoutingErrorDomain
                                     code:LRRoutingErrorInvalidConfiguration
                                 userInfo:@{NSLocalizedDescriptionKey: message}];
    }
    return NO;
}

static LRBrowserTarget *LRTargetFromDictionary(NSDictionary *dictionary, NSError **error) {
    NSString *app = dictionary[@"app"];
    id profileValue = dictionary[@"profile"];
    if (![app isKindOfClass:NSString.class]) {
        LRSetConfigurationError(error, @"Every browser target needs an 'app' string.");
        return nil;
    }
    if (profileValue != nil && ![profileValue isKindOfClass:NSString.class]) {
        LRSetConfigurationError(error, @"A Chrome 'profile' must be a string.");
        return nil;
    }
    if ([app isEqualToString:@"Safari"]) {
        return [LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari profile:nil];
    }
    if ([app isEqualToString:@"Google Chrome"]) {
        return [LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome
                                              profile:profileValue];
    }
    LRSetConfigurationError(error,
                            [NSString stringWithFormat:@"Unsupported browser '%@'. Use Safari or Google Chrome.", app]);
    return nil;
}

static NSDictionary *LRDictionaryFromTarget(LRBrowserTarget *target) {
    NSMutableDictionary *dictionary = [@{@"app": target.displayName} mutableCopy];
    if (target.application == LRBrowserApplicationChrome && target.profile.length > 0) {
        dictionary[@"profile"] = target.profile;
    }
    return dictionary;
}

static BOOL LRValidateTarget(LRBrowserTarget *target, NSString *location, NSError **error) {
    if (target == nil) {
        return LRSetConfigurationError(error,
                                       [NSString stringWithFormat:@"%@ has no browser target.", location]);
    }
    if (target.application != LRBrowserApplicationChrome || target.profile == nil) {
        return YES;
    }
    NSString *profile = target.profile;
    if (profile.length == 0 || profile.length > 128 || [profile isEqualToString:@"."] ||
        [profile isEqualToString:@".."] || [profile hasPrefix:@"-"]) {
        return LRSetConfigurationError(error,
                                       [NSString stringWithFormat:@"%@ has an invalid Chrome profile directory.", location]);
    }
    NSCharacterSet *forbidden = [NSCharacterSet characterSetWithCharactersInString:@"/\\"];
    if ([profile rangeOfCharacterFromSet:forbidden].location != NSNotFound ||
        [profile rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound) {
        return LRSetConfigurationError(error,
                                       [NSString stringWithFormat:@"%@ has an unsafe Chrome profile directory.", location]);
    }
    return YES;
}

static BOOL LRValidateHostPattern(NSString *pattern, NSString *location, NSError **error) {
    NSString *host = [pattern lowercaseString];
    if ([host hasPrefix:@"*."]) {
        host = [host substringFromIndex:2];
    }
    if (host.length == 0 || host.length > 253 || [host containsString:@"*"] ||
        [host hasPrefix:@"."] || [host hasSuffix:@"."]) {
        return LRSetConfigurationError(error,
                                       [NSString stringWithFormat:@"%@ contains invalid host pattern '%@'.", location, pattern]);
    }
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyz0123456789.-"];
    if ([host rangeOfCharacterFromSet:allowed.invertedSet].location != NSNotFound) {
        return LRSetConfigurationError(error,
                                       [NSString stringWithFormat:@"%@ contains invalid host pattern '%@'.", location, pattern]);
    }
    for (NSString *label in [host componentsSeparatedByString:@"."]) {
        if (label.length == 0 || [label hasPrefix:@"-"] || [label hasSuffix:@"-"]) {
            return LRSetConfigurationError(error,
                                           [NSString stringWithFormat:@"%@ contains invalid host pattern '%@'.", location, pattern]);
        }
    }
    return YES;
}

@implementation LRRouterConfiguration

+ (instancetype)configurationFromData:(NSData *)data error:(NSError **)error {
    if (data.length > LRMaximumConfigBytes) {
        LRSetConfigurationError(error, @"The config file is larger than 1 MB.");
        return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (object == nil) {
        return nil;
    }
    if (![object isKindOfClass:NSDictionary.class]) {
        LRSetConfigurationError(error, @"The config root must be a JSON object.");
        return nil;
    }
    NSDictionary *root = object;
    if (![root[@"default"] isKindOfClass:NSDictionary.class] ||
        ![root[@"rules"] isKindOfClass:NSArray.class]) {
        LRSetConfigurationError(error, @"The config needs a 'default' object and a 'rules' array.");
        return nil;
    }
    LRBrowserTarget *defaultTarget = LRTargetFromDictionary(root[@"default"], error);
    if (defaultTarget == nil) {
        return nil;
    }

    NSMutableArray<LRRoutingRule *> *rules = [NSMutableArray array];
    NSUInteger index = 0;
    for (id value in root[@"rules"]) {
        if (![value isKindOfClass:NSDictionary.class]) {
            LRSetConfigurationError(error,
                                    [NSString stringWithFormat:@"Rule %lu must be an object.", (unsigned long)(index + 1)]);
            return nil;
        }
        NSDictionary *dictionary = value;
        NSString *name = dictionary[@"name"];
        NSArray *hosts = dictionary[@"hosts"];
        if (![name isKindOfClass:NSString.class] || ![hosts isKindOfClass:NSArray.class]) {
            LRSetConfigurationError(error,
                                    [NSString stringWithFormat:@"Rule %lu needs a name and hosts array.", (unsigned long)(index + 1)]);
            return nil;
        }
        for (id host in hosts) {
            if (![host isKindOfClass:NSString.class]) {
                LRSetConfigurationError(error,
                                        [NSString stringWithFormat:@"Rule %lu hosts must all be strings.", (unsigned long)(index + 1)]);
                return nil;
            }
        }
        LRBrowserTarget *target = LRTargetFromDictionary(dictionary, error);
        if (target == nil) {
            return nil;
        }
        [rules addObject:[LRRoutingRule ruleWithName:name hosts:hosts target:target]];
        index += 1;
    }
    LRRouterConfiguration *configuration = [[self alloc] initWithDefaultTarget:defaultTarget rules:rules];
    return [configuration validate:error] ? configuration : nil;
}

+ (instancetype)defaultConfiguration {
    return [[self alloc]
        initWithDefaultTarget:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari
                                                              profile:nil]
                         rules:@[]];
}

- (instancetype)initWithDefaultTarget:(LRBrowserTarget *)defaultTarget
                                 rules:(NSArray<LRRoutingRule *> *)rules {
    self = [super init];
    if (self) {
        _defaultTarget = defaultTarget;
        _rules = [rules copy];
    }
    return self;
}

- (BOOL)validate:(NSError **)error {
    if (!LRValidateTarget(self.defaultTarget, @"The default target", error)) {
        return NO;
    }
    NSUInteger index = 0;
    for (LRRoutingRule *rule in self.rules) {
        NSString *location = [NSString stringWithFormat:@"Rule %lu", (unsigned long)(index + 1)];
        NSString *name = [rule.name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length == 0 || name.length > 120) {
            return LRSetConfigurationError(error,
                                           [NSString stringWithFormat:@"%@ needs a name of 1–120 characters.", location]);
        }
        if (rule.hosts.count == 0 || rule.hosts.count > 100) {
            return LRSetConfigurationError(error,
                                           [NSString stringWithFormat:@"%@ needs between 1 and 100 host patterns.", location]);
        }
        for (NSString *pattern in rule.hosts) {
            if (!LRValidateHostPattern(pattern, location, error)) {
                return NO;
            }
        }
        if (!LRValidateTarget(rule.target, location, error)) {
            return NO;
        }
        index += 1;
    }
    return YES;
}

- (NSData *)JSONDataWithError:(NSError **)error {
    if (![self validate:error]) {
        return nil;
    }
    NSMutableArray<NSDictionary *> *rules = [NSMutableArray array];
    for (LRRoutingRule *rule in self.rules) {
        NSMutableDictionary *dictionary = [LRDictionaryFromTarget(rule.target) mutableCopy];
        dictionary[@"name"] = rule.name;
        dictionary[@"hosts"] = rule.hosts;
        [rules addObject:dictionary];
    }
    NSDictionary *root = @{
        @"default": LRDictionaryFromTarget(self.defaultTarget),
        @"rules": rules,
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:root
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                     error:error];
    if (data == nil) {
        return nil;
    }
    NSMutableData *terminated = [data mutableCopy];
    [terminated appendBytes:"\n" length:1];
    return terminated;
}

@end

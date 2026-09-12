#import "LRRouting.h"

@interface LRRouteResult (Internal)
- (instancetype)initWithTarget:(LRBrowserTarget *)target ruleName:(nullable NSString *)ruleName;
@end

@interface LRRouter ()
@property(nonatomic, strong) LRRouterConfiguration *configuration;
@end

static void LRSetRoutingError(NSError **error, LRRoutingErrorCode code, NSString *message) {
    if (error != NULL) {
        *error = [NSError errorWithDomain:LRRoutingErrorDomain
                                     code:code
                                 userInfo:@{NSLocalizedDescriptionKey: message}];
    }
}

static BOOL LRHostMatchesPattern(NSString *host, NSString *pattern) {
    NSString *normalizedHost = host.lowercaseString;
    NSString *normalizedPattern = pattern.lowercaseString;
    if (![normalizedPattern hasPrefix:@"*."]) {
        return [normalizedHost isEqualToString:normalizedPattern];
    }
    NSString *baseDomain = [normalizedPattern substringFromIndex:2];
    if ([normalizedHost isEqualToString:baseDomain]) {
        return YES;
    }
    return [normalizedHost hasSuffix:[@"." stringByAppendingString:baseDomain]];
}

@implementation LRRouter

- (instancetype)initWithConfiguration:(LRRouterConfiguration *)configuration
                                 error:(NSError **)error {
    if (![configuration validate:error]) {
        return nil;
    }
    self = [super init];
    if (self) {
        _configuration = configuration;
    }
    return self;
}

- (LRRouteResult *)routeForURL:(NSURL *)URL error:(NSError **)error {
    NSString *scheme = URL.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) {
        LRSetRoutingError(error,
                          LRRoutingErrorUnsupportedScheme,
                          [NSString stringWithFormat:@"LinkRouter only opens HTTP and HTTPS URLs, not '%@'.",
                                                     scheme.length > 0 ? scheme : @"unknown"]);
        return nil;
    }
    NSString *host = URL.host;
    if (host.length == 0) {
        LRSetRoutingError(error, LRRoutingErrorMissingHost, @"The web URL has no host.");
        return nil;
    }
    for (LRRoutingRule *rule in self.configuration.rules) {
        for (NSString *pattern in rule.hosts) {
            if (LRHostMatchesPattern(host, pattern)) {
                return [[LRRouteResult alloc] initWithTarget:rule.target ruleName:rule.name];
            }
        }
    }
    return [[LRRouteResult alloc] initWithTarget:self.configuration.defaultTarget ruleName:nil];
}

@end

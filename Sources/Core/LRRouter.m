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
    if ([scheme isEqualToString:@"file"]) {
        // A file URL may carry an authority (file://host/path). Only the local
        // machine is a file LinkRouter can hand to a browser.
        NSString *fileHost = URL.host.lowercaseString;
        if (fileHost.length > 0 && ![fileHost isEqualToString:@"localhost"]) {
            LRSetRoutingError(error,
                              LRRoutingErrorRemoteFileHost,
                              [NSString stringWithFormat:@"LinkRouter opens local files only, not files on '%@'.",
                                                         URL.host]);
            return nil;
        }
        if (URL.path.length == 0) {
            LRSetRoutingError(error, LRRoutingErrorMissingPath, @"The file URL has no path.");
            return nil;
        }
        // Host rules match web hosts; a local file is addressed by path, so no
        // rule can claim one and it always takes the fallback.
        return [[LRRouteResult alloc] initWithTarget:self.configuration.defaultTarget ruleName:nil];
    }
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) {
        LRSetRoutingError(error,
                          LRRoutingErrorUnsupportedScheme,
                          [NSString stringWithFormat:@"LinkRouter only opens web links and local files, not '%@' URLs.",
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

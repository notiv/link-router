#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const LRRoutingErrorDomain;

typedef NS_ERROR_ENUM(LRRoutingErrorDomain, LRRoutingErrorCode) {
    LRRoutingErrorInvalidConfiguration = 1,
    LRRoutingErrorUnsupportedScheme = 2,
    LRRoutingErrorMissingHost = 3,
};

typedef NS_ENUM(NSUInteger, LRBrowserApplication) {
    LRBrowserApplicationSafari,
    LRBrowserApplicationChrome,
};

typedef NS_ENUM(NSUInteger, LRLaunchMode) {
    LRLaunchModeWorkspace,
    LRLaunchModeExecutable,
};

@interface LRBrowserTarget : NSObject <NSCopying>

@property(nonatomic, readonly) LRBrowserApplication application;
@property(nonatomic, copy, readonly, nullable) NSString *profile;
@property(nonatomic, readonly) BOOL privateBrowsing;
@property(nonatomic, copy, readonly) NSString *displayName;

+ (instancetype)targetWithApplication:(LRBrowserApplication)application
                               profile:(nullable NSString *)profile;
+ (instancetype)targetWithApplication:(LRBrowserApplication)application
                               profile:(nullable NSString *)profile
                       privateBrowsing:(BOOL)privateBrowsing;

@end

@interface LRRoutingRule : NSObject

@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSArray<NSString *> *hosts;
@property(nonatomic, strong) LRBrowserTarget *target;

+ (instancetype)ruleWithName:(NSString *)name
                       hosts:(NSArray<NSString *> *)hosts
                      target:(LRBrowserTarget *)target;

@end

@interface LRRouterConfiguration : NSObject

@property(nonatomic, strong) LRBrowserTarget *defaultTarget;
@property(nonatomic, copy) NSArray<LRRoutingRule *> *rules;

+ (nullable instancetype)configurationFromData:(NSData *)data error:(NSError **)error;
+ (instancetype)defaultConfiguration;
- (instancetype)initWithDefaultTarget:(LRBrowserTarget *)defaultTarget
                                 rules:(NSArray<LRRoutingRule *> *)rules;
- (BOOL)validate:(NSError **)error;
- (nullable NSData *)JSONDataWithError:(NSError **)error;

@end

@interface LRRouteResult : NSObject

@property(nonatomic, strong, readonly) LRBrowserTarget *target;
@property(nonatomic, copy, readonly, nullable) NSString *ruleName;

@end

@interface LRRouter : NSObject

- (nullable instancetype)initWithConfiguration:(LRRouterConfiguration *)configuration
                                         error:(NSError **)error;
- (nullable LRRouteResult *)routeForURL:(NSURL *)URL error:(NSError **)error;

@end

@interface LRLaunchPlan : NSObject

@property(nonatomic, readonly) LRLaunchMode mode;
@property(nonatomic, copy, readonly) NSString *bundleIdentifier;
@property(nonatomic, copy, readonly) NSArray<NSString *> *arguments;

+ (nullable instancetype)planForURL:(NSURL *)URL
                             target:(LRBrowserTarget *)target
                              error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

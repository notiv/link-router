#import "LRRouting.h"

NSErrorDomain const LRRoutingErrorDomain = @"com.linkrouter.routing";

@interface LRBrowserTarget ()
@property(nonatomic, readwrite) LRBrowserApplication application;
@property(nonatomic, copy, readwrite, nullable) NSString *profile;
@property(nonatomic, readwrite) BOOL privateBrowsing;
@end

@implementation LRBrowserTarget

+ (instancetype)targetWithApplication:(LRBrowserApplication)application
                               profile:(NSString *)profile {
    return [self targetWithApplication:application profile:profile privateBrowsing:NO];
}

+ (instancetype)targetWithApplication:(LRBrowserApplication)application
                               profile:(NSString *)profile
                       privateBrowsing:(BOOL)privateBrowsing {
    LRBrowserTarget *target = [[self alloc] init];
    target.application = application;
    NSString *trimmed = [profile stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    target.profile = trimmed.length > 0 ? trimmed : nil;
    target.privateBrowsing = privateBrowsing;
    return target;
}

- (NSString *)displayName {
    return self.application == LRBrowserApplicationSafari ? @"Safari" : @"Google Chrome";
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end

@implementation LRRoutingRule

+ (instancetype)ruleWithName:(NSString *)name
                       hosts:(NSArray<NSString *> *)hosts
                      target:(LRBrowserTarget *)target {
    LRRoutingRule *rule = [[self alloc] init];
    rule.name = name;
    rule.hosts = hosts;
    rule.target = target;
    return rule;
}

@end

@implementation LRRouteResult

- (instancetype)initWithTarget:(LRBrowserTarget *)target ruleName:(NSString *)ruleName {
    self = [super init];
    if (self) {
        _target = target;
        _ruleName = [ruleName copy];
    }
    return self;
}
@end

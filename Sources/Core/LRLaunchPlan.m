#import "LRRouting.h"

@interface LRLaunchPlan ()
@property(nonatomic, readwrite) LRLaunchMode mode;
@property(nonatomic, copy, readwrite) NSString *bundleIdentifier;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *arguments;
@end

@implementation LRLaunchPlan

+ (instancetype)planForURL:(NSURL *)URL
                     target:(LRBrowserTarget *)target
                      error:(NSError **)error {
    LRRouterConfiguration *configuration = [[LRRouterConfiguration alloc]
        initWithDefaultTarget:target
                         rules:@[]];
    if (![configuration validate:error]) {
        return nil;
    }
    LRRouter *URLValidator = [[LRRouter alloc]
        initWithConfiguration:[LRRouterConfiguration defaultConfiguration]
                         error:error];
    if ([URLValidator routeForURL:URL error:error] == nil) {
        return nil;
    }

    LRLaunchPlan *plan = [[self alloc] init];
    if (target.application == LRBrowserApplicationSafari) {
        plan.mode = LRLaunchModeWorkspace;
        plan.bundleIdentifier = @"com.apple.Safari";
        plan.arguments = @[];
        return plan;
    }

    plan.bundleIdentifier = @"com.google.Chrome";
    if (target.profile.length == 0 && !target.privateBrowsing) {
        plan.mode = LRLaunchModeWorkspace;
        plan.arguments = @[];
    } else {
        plan.mode = LRLaunchModeExecutable;
        NSMutableArray<NSString *> *arguments = [NSMutableArray array];
        if (target.profile.length > 0) {
            [arguments addObject:[@"--profile-directory=" stringByAppendingString:target.profile]];
        }
        if (target.privateBrowsing) {
            [arguments addObject:@"--incognito"];
        }
        [arguments addObject:URL.absoluteString];
        plan.arguments = arguments;
    }
    return plan;
}

@end

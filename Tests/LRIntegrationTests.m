#import <Foundation/Foundation.h>

#import "LRRouting.h"
#import "LRTestSupport.h"

static void TestConfigurationToChromeLaunchPlan(void) {
    NSError *error = nil;
    NSData *sampleData = [NSData dataWithContentsOfFile:@"Examples/config.json"
                                                options:0
                                                  error:&error];
    LRAssert(sampleData != nil, "the checked-in sample config should be readable");
    if (sampleData == nil) {
        return;
    }
    LRRouterConfiguration *configuration =
        [LRRouterConfiguration configurationFromData:sampleData error:&error];
    LRAssert(configuration != nil, "the checked-in sample config should decode");
    if (configuration == nil) {
        return;
    }
    LRRouter *router = [[LRRouter alloc] initWithConfiguration:configuration error:&error];
    NSURL *URL = [NSURL URLWithString:@"https://docs.example.com/guide?q=profiles"];
    LRRouteResult *route = [router routeForURL:URL error:&error];
    LRLaunchPlan *plan = [LRLaunchPlan planForURL:URL target:route.target error:&error];

    LRAssert(error == nil, "valid config-to-launch flow should not return an error");
    LRAssert([route.ruleName isEqualToString:@"Work"], "the matching rule should be retained");
    LRAssert(plan.mode == LRLaunchModeExecutable, "profile routing should use Chrome's executable");
    NSArray<NSString *> *expectedArguments = @[
        @"--profile-directory=Profile 1", @"https://docs.example.com/guide?q=profiles"
    ];
    LRAssert([plan.arguments isEqualToArray:expectedArguments],
             "the launch plan should preserve the profile and URL as separate arguments");
}

int main(void) {
    @autoreleasepool {
        TestConfigurationToChromeLaunchPlan();
        return LRFinishTests();
    }
}

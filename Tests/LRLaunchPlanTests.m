#import <Foundation/Foundation.h>

#import "LRRouting.h"
#import "LRTestSupport.h"

static void TestSafariAndChromePlans(void) {
    NSError *error = nil;
    NSURL *URL = [NSURL URLWithString:@"https://example.com/path?q=one%20two"];
    LRLaunchPlan *safari =
        [LRLaunchPlan planForURL:URL
                         target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari
                                                               profile:nil]
                          error:&error];
    LRAssert(safari.mode == LRLaunchModeWorkspace, "Safari should launch through NSWorkspace");
    LRAssert([safari.bundleIdentifier isEqualToString:@"com.apple.Safari"],
             "Safari bundle identifier should be explicit");

    LRLaunchPlan *chrome =
        [LRLaunchPlan planForURL:URL
                         target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome
                                                               profile:@"Profile 1"]
                          error:&error];
    LRAssert(chrome.mode == LRLaunchModeExecutable,
             "profile-specific Chrome should launch its executable");
    LRAssert([chrome.bundleIdentifier isEqualToString:@"com.google.Chrome"],
             "Chrome bundle identifier should be explicit");
    NSArray<NSString *> *expectedArguments = @[
        @"--profile-directory=Profile 1", @"https://example.com/path?q=one%20two"
    ];
    LRAssert([chrome.arguments isEqualToArray:expectedArguments],
             "Chrome arguments should remain separate and preserve the URL");
}

static void TestPrivateChromePlanSupportsProfiles(void) {
    NSError *error = nil;
    NSURL *URL = [NSURL URLWithString:@"https://example.com/private-profile"];
    LRBrowserTarget *target =
        [LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome
                                       profile:@"Profile 2"
                               privateBrowsing:YES];
    LRLaunchPlan *plan = [LRLaunchPlan planForURL:URL target:target error:&error];

    LRAssert(plan != nil && error == nil, "private Chrome should accept a web URL");
    LRAssert(plan.mode == LRLaunchModeExecutable,
             "private Chrome should launch its executable even with a selected profile");
    NSArray<NSString *> *expectedArguments = @[
        @"--profile-directory=Profile 2", @"--incognito", URL.absoluteString
    ];
    LRAssert([plan.arguments isEqualToArray:expectedArguments],
             "Chrome should receive profile and incognito switches before the URL");
}

static void TestLaunchPlanRejectsLocalFiles(void) {
    NSError *error = nil;
    LRLaunchPlan *plan = [LRLaunchPlan
        planForURL:[NSURL fileURLWithPath:@"/tmp/Local Page.html"]
            target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari profile:nil]
             error:&error];

    LRAssert(plan == nil, "a launch plan should reject local file URLs");
    LRAssert(error.code == LRRoutingErrorUnsupportedScheme,
             "a local file launch should report an unsupported scheme");
}

static void TestPrivateChromePlanDoesNotRequireAProfile(void) {
    NSURL *URL = [NSURL URLWithString:@"https://example.com/private"];
    LRBrowserTarget *target =
        [LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome
                                       profile:nil
                               privateBrowsing:YES];
    LRLaunchPlan *plan = [LRLaunchPlan planForURL:URL target:target error:nil];

    LRAssert(plan.mode == LRLaunchModeExecutable,
             "private Chrome should use an executable launch without a profile");
    NSArray<NSString *> *expectedArguments = @[@"--incognito", URL.absoluteString];
    LRAssert([plan.arguments isEqualToArray:expectedArguments],
             "private Chrome should pass only the incognito switch before the URL");
}

int main(void) {
    @autoreleasepool {
        TestSafariAndChromePlans();
        TestPrivateChromePlanSupportsProfiles();
        TestLaunchPlanRejectsLocalFiles();
        TestPrivateChromePlanDoesNotRequireAProfile();
        return LRFinishTests();
    }
}

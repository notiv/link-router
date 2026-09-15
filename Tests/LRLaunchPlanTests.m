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

static void TestLaunchPlanOpensLocalFiles(void) {
    NSError *error = nil;
    NSURL *fileURL = [NSURL fileURLWithPath:@"/tmp/Local Page.html"];
    LRLaunchPlan *safari = [LRLaunchPlan
        planForURL:fileURL
            target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari profile:nil]
             error:&error];

    LRAssert(safari != nil && error == nil, "a launch plan should accept local file URLs");
    LRAssert(safari.mode == LRLaunchModeWorkspace, "a local file should open through NSWorkspace");

    LRLaunchPlan *chrome = [LRLaunchPlan
        planForURL:fileURL
            target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome
                                                  profile:@"Profile 1"]
             error:&error];
    NSArray<NSString *> *expectedArguments =
        @[@"--profile-directory=Profile 1", fileURL.absoluteString];
    LRAssert([chrome.arguments isEqualToArray:expectedArguments],
             "a local file should reach Chrome as a single percent-encoded argument");
}

static void TestBundleIdentifiersAreExplicit(void) {
    // Reused when handing the public.html content type back to a real browser.
    LRAssert([[LRLaunchPlan bundleIdentifierForTarget:
                   [LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari profile:nil]]
                 isEqualToString:@"com.apple.Safari"],
             "Safari should resolve to its explicit bundle identifier");
    LRAssert([[LRLaunchPlan bundleIdentifierForTarget:
                   [LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome
                                                  profile:@"Profile 1"]]
                 isEqualToString:@"com.google.Chrome"],
             "Chrome should resolve to its explicit bundle identifier regardless of profile");
}

static void TestLaunchPlanRejectsPathlessFileURLs(void) {
    NSError *error = nil;
    LRLaunchPlan *plan = [LRLaunchPlan
        planForURL:[NSURL URLWithString:@"file://"]
            target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari profile:nil]
             error:&error];

    LRAssert(plan == nil, "a launch plan should reject a file URL with no path");
    LRAssert([error.domain isEqualToString:LRRoutingErrorDomain],
             "a rejected launch should report the routing error domain");
    LRAssert(error.code == LRRoutingErrorMissingPath,
             "a pathless file launch should report a missing path");
}

static void TestLaunchPlanRejectsUnsupportedSchemes(void) {
    NSError *error = nil;
    LRLaunchPlan *plan = [LRLaunchPlan
        planForURL:[NSURL URLWithString:@"ftp://example.com/file"]
            target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari profile:nil]
             error:&error];

    LRAssert(plan == nil, "a launch plan should reject unsupported schemes");
    LRAssert(error.code == LRRoutingErrorUnsupportedScheme,
             "an unsupported launch should report an unsupported scheme");
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
        TestLaunchPlanOpensLocalFiles();
        TestBundleIdentifiersAreExplicit();
        TestLaunchPlanRejectsPathlessFileURLs();
        TestLaunchPlanRejectsUnsupportedSchemes();
        TestPrivateChromePlanDoesNotRequireAProfile();
        return LRFinishTests();
    }
}

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

int main(void) {
    @autoreleasepool {
        TestSafariAndChromePlans();
        return LRFinishTests();
    }
}

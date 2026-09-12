#import <Foundation/Foundation.h>

#import "LRRouting.h"
#import "LRTestSupport.h"

static LRRouter *TestRouter(void) {
    LRRoutingRule *specific = [LRRoutingRule
        ruleWithName:@"Specific"
               hosts:@[@"DOCS.example.com"]
              target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome
                                                     profile:@"Profile 2"]];
    LRRoutingRule *general = [LRRoutingRule
        ruleWithName:@"General"
               hosts:@[@"*.example.com"]
              target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome
                                                     profile:@"Default"]];
    LRRouterConfiguration *configuration = [[LRRouterConfiguration alloc]
        initWithDefaultTarget:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari
                                                              profile:nil]
                         rules:@[specific, general]];
    NSError *error = nil;
    LRRouter *router = [[LRRouter alloc] initWithConfiguration:configuration error:&error];
    LRAssert(router != nil && error == nil, "valid router should initialize");
    return router;
}

static void TestExactWildcardPrecedenceAndFallback(void) {
    LRRouter *router = TestRouter();
    NSError *error = nil;
    LRRouteResult *exact = [router routeForURL:[NSURL URLWithString:@"https://docs.example.com/a"]
                                         error:&error];
    LRAssert([exact.ruleName isEqualToString:@"Specific"], "first exact rule should win");
    LRAssert([exact.target.profile isEqualToString:@"Profile 2"], "specific profile should win");

    LRRouteResult *base = [router routeForURL:[NSURL URLWithString:@"https://example.com"]
                                        error:&error];
    LRAssert([base.ruleName isEqualToString:@"General"], "wildcard should match base domain");

    LRRouteResult *subdomain = [router routeForURL:[NSURL URLWithString:@"https://api.example.com"]
                                             error:&error];
    LRAssert([subdomain.ruleName isEqualToString:@"General"], "wildcard should match subdomain");

    LRRouteResult *lookalike = [router routeForURL:[NSURL URLWithString:@"https://notexample.com"]
                                             error:&error];
    LRAssert(lookalike.ruleName == nil, "wildcard should not match a lookalike domain");
    LRAssert(lookalike.target.application == LRBrowserApplicationSafari,
             "unmatched URL should use fallback");
}

static void TestRejectsNonWebURLs(void) {
    NSError *error = nil;
    LRRouteResult *result = [TestRouter() routeForURL:[NSURL fileURLWithPath:@"/tmp/private"]
                                                error:&error];
    LRAssert(result == nil, "file URL should be rejected");
    LRAssert(error.code == LRRoutingErrorUnsupportedScheme, "file URL should report its scheme");
}

int main(void) {
    @autoreleasepool {
        TestExactWildcardPrecedenceAndFallback();
        TestRejectsNonWebURLs();
        return LRFinishTests();
    }
}

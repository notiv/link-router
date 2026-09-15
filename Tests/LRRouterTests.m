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

static void TestRoutesFileURLsToTheFallback(void) {
    NSError *error = nil;
    LRRouteResult *result = [TestRouter() routeForURL:[NSURL fileURLWithPath:@"/tmp/page.html"]
                                                error:&error];
    LRAssert(result != nil && error == nil, "a local file URL should route");
    LRAssert(result.ruleName == nil, "a local file URL has no host, so no rule can claim it");
    LRAssert(result.target.application == LRBrowserApplicationSafari,
             "a local file URL should open in the fallback browser");
}

static void TestHostRulesNeverClaimFileURLs(void) {
    // A file URL whose path spells out a rule's host must still take the fallback.
    // Assert non-nil first: Safari is enum 0 and messaging nil returns 0, so the
    // checks below would otherwise pass for a rejected route.
    NSError *error = nil;
    LRRouteResult *result = [TestRouter()
        routeForURL:[NSURL fileURLWithPath:@"/tmp/docs.example.com/page.html"]
              error:&error];
    LRAssert(result != nil && error == nil, "a host-like file path should still route");
    LRAssert(result.ruleName == nil, "a path that looks like a host should not match a host rule");
    LRAssert(result.target.application == LRBrowserApplicationSafari,
             "a path that looks like a host should still use the fallback");
}

static void TestRejectsRemoteFileAuthorities(void) {
    // file://host/path really does parse a host, so a rule's domain can appear
    // in the authority of a file URL. Those are not local files.
    NSError *error = nil;
    LRRouteResult *result = [TestRouter()
        routeForURL:[NSURL URLWithString:@"file://docs.example.com/tmp/page.html"]
              error:&error];
    LRAssert(result == nil, "a file URL on a remote authority should be rejected");
    LRAssert(error.code == LRRoutingErrorRemoteFileHost,
             "a remote file authority should report a remote host");
}

static void TestAcceptsLocalhostFileAuthority(void) {
    NSError *error = nil;
    LRRouteResult *result = [TestRouter()
        routeForURL:[NSURL URLWithString:@"file://localhost/tmp/page.html"] error:&error];
    LRAssert(result != nil && error == nil, "file://localhost names the local machine");
    LRAssert(result.target.application == LRBrowserApplicationSafari,
             "a localhost file URL should use the fallback");
}

static void TestFileURLsFollowTheConfiguredFallback(void) {
    // Guards against a hardcoded Safari: the fallback must come from the config.
    LRRouterConfiguration *configuration = [[LRRouterConfiguration alloc]
        initWithDefaultTarget:[LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome
                                                             profile:@"Profile 1"]
                        rules:@[]];
    LRRouter *router = [[LRRouter alloc] initWithConfiguration:configuration error:nil];
    NSError *error = nil;
    LRRouteResult *result = [router routeForURL:[NSURL fileURLWithPath:@"/tmp/page.html"]
                                          error:&error];
    LRAssert(result != nil && error == nil, "a local file should route under a Chrome fallback");
    LRAssert(result.target.application == LRBrowserApplicationChrome,
             "a local file should follow the configured fallback, not a hardcoded Safari");
    LRAssert([result.target.profile isEqualToString:@"Profile 1"],
             "a local file should keep the fallback's Chrome profile");
}

static void TestRejectsPathlessFileURLs(void) {
    NSError *error = nil;
    LRRouteResult *result = [TestRouter() routeForURL:[NSURL URLWithString:@"file://"] error:&error];
    LRAssert(result == nil, "a file URL without a path should be rejected");
    LRAssert(error.code == LRRoutingErrorMissingPath,
             "a file URL without a path should report a missing path");
}

static void TestRejectsUnsupportedSchemes(void) {
    NSError *error = nil;
    LRRouteResult *result = [TestRouter() routeForURL:[NSURL URLWithString:@"ftp://example.com/file"]
                                                error:&error];
    LRAssert(result == nil, "an FTP URL should be rejected");
    LRAssert(error.code == LRRoutingErrorUnsupportedScheme,
             "an unsupported URL should report its scheme");
}

int main(void) {
    @autoreleasepool {
        TestExactWildcardPrecedenceAndFallback();
        TestRoutesFileURLsToTheFallback();
        TestHostRulesNeverClaimFileURLs();
        TestRejectsRemoteFileAuthorities();
        TestAcceptsLocalhostFileAuthority();
        TestFileURLsFollowTheConfiguredFallback();
        TestRejectsPathlessFileURLs();
        TestRejectsUnsupportedSchemes();
        return LRFinishTests();
    }
}

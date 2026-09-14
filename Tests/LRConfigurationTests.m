#import <Foundation/Foundation.h>

#import "LRRouting.h"
#import "LRTestSupport.h"

static LRRouterConfiguration *ReferenceConfiguration(void) {
    NSString *JSON = @"{\"default\":{\"app\":\"Safari\"},"
                     "\"rules\":[{\"name\":\"Work\","
                     "\"hosts\":[\"*.example.com\"],"
                     "\"app\":\"Google Chrome\",\"profile\":\"Profile 1\","
                     "\"private\":true}]}";
    NSError *error = nil;
    LRRouterConfiguration *configuration =
        [LRRouterConfiguration configurationFromData:[JSON dataUsingEncoding:NSUTF8StringEncoding]
                                                error:&error];
    LRAssert(configuration != nil, "reference configuration should decode");
    LRAssert(error == nil, "valid configuration should not return an error");
    return configuration;
}

static void TestConfigurationDecoding(void) {
    LRRouterConfiguration *configuration = ReferenceConfiguration();
    LRAssert(configuration.defaultTarget.application == LRBrowserApplicationSafari,
             "default target should be Safari");
    LRAssert(configuration.rules.count == 1, "one rule should decode");
    LRRoutingRule *rule = configuration.rules.firstObject;
    LRAssert([rule.name isEqualToString:@"Work"], "rule name should decode");
    LRAssert([rule.hosts isEqualToArray:@[@"*.example.com"]], "hosts should decode");
    LRAssert(rule.target.application == LRBrowserApplicationChrome,
             "rule target should be Chrome");
    LRAssert([rule.target.profile isEqualToString:@"Profile 1"], "profile should decode");
    LRAssert(rule.target.privateBrowsing, "private browsing should decode");
    LRAssert(!configuration.defaultTarget.privateBrowsing,
             "missing private setting should remain backward-compatible and default to false");
}

static void TestValidation(void) {
    NSError *error = nil;
    LRRoutingRule *unsafeRule = [LRRoutingRule
        ruleWithName:@"Bad"
               hosts:@[@"foo.*.example.com"]
              target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome
                                                     profile:@"Default"]];
    LRRouterConfiguration *unsafePattern = [[LRRouterConfiguration alloc]
        initWithDefaultTarget:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari
                                                              profile:nil]
                         rules:@[unsafeRule]];
    LRAssert(![unsafePattern validate:&error], "mid-host wildcard should be rejected");
    LRAssert(error.code == LRRoutingErrorInvalidConfiguration,
             "invalid pattern should return a configuration error");

    error = nil;
    LRRouterConfiguration *unsafeProfile = [[LRRouterConfiguration alloc]
        initWithDefaultTarget:[LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome
                                                              profile:@"../../Other"]
                         rules:@[]];
    LRAssert(![unsafeProfile validate:&error], "path-like Chrome profile should be rejected");

    error = nil;
    LRBrowserTarget *privateSafari =
        [LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari
                                       profile:nil
                               privateBrowsing:YES];
    LRRouterConfiguration *unsupportedPrivateMode = [[LRRouterConfiguration alloc]
        initWithDefaultTarget:privateSafari
                         rules:@[]];
    LRAssert(![unsupportedPrivateMode validate:&error],
             "Safari private browsing should be rejected because it has no supported launch API");
}

static void TestRoundTrip(void) {
    LRRouterConfiguration *configuration = ReferenceConfiguration();
    NSError *error = nil;
    NSData *data = [configuration JSONDataWithError:&error];
    LRRouterConfiguration *decoded =
        [LRRouterConfiguration configurationFromData:data error:&error];
    LRAssert(decoded != nil && error == nil, "encoded configuration should decode");
    LRAssert([decoded.rules.firstObject.name isEqualToString:@"Work"],
             "round trip should preserve rule order and values");
    LRAssert(decoded.rules.firstObject.target.privateBrowsing,
             "round trip should preserve private browsing");
}

static void TestPrivateBrowsingMustBeBoolean(void) {
    NSString *JSON = @"{\"default\":{\"app\":\"Google Chrome\",\"private\":1},\"rules\":[]}";
    NSError *error = nil;
    LRRouterConfiguration *configuration = [LRRouterConfiguration
        configurationFromData:[JSON dataUsingEncoding:NSUTF8StringEncoding]
                         error:&error];

    LRAssert(configuration == nil, "a numeric private value should be rejected");
    LRAssert(error.code == LRRoutingErrorInvalidConfiguration,
             "an invalid private value should return a configuration error");
}

static void TestEncodedConfigurationSizeLimit(void) {
    NSString *label63 = [@"a" stringByPaddingToLength:63 withString:@"a" startingAtIndex:0];
    NSString *label61 = [@"b" stringByPaddingToLength:61 withString:@"b" startingAtIndex:0];
    NSString *longHost = [@[label63, label63, label63, label61] componentsJoinedByString:@"."];
    NSMutableArray<LRRoutingRule *> *rules = [NSMutableArray array];
    for (NSUInteger ruleIndex = 0; ruleIndex < 50; ruleIndex += 1) {
        NSMutableArray<NSString *> *hosts = [NSMutableArray array];
        for (NSUInteger hostIndex = 0; hostIndex < 100; hostIndex += 1) {
            [hosts addObject:longHost];
        }
        [rules addObject:[LRRoutingRule
            ruleWithName:[NSString stringWithFormat:@"Rule %lu", (unsigned long)ruleIndex]
                   hosts:hosts
                  target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari
                                                         profile:nil]]];
    }
    LRRouterConfiguration *configuration = [[LRRouterConfiguration alloc]
        initWithDefaultTarget:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari
                                                              profile:nil]
                         rules:rules];
    NSError *error = nil;
    LRAssert([configuration JSONDataWithError:&error] == nil,
             "the writer should reject a config larger than the reader accepts");
    LRAssert(error.code == LRRoutingErrorInvalidConfiguration,
             "an oversized encoded config should return a configuration error");
    LRAssert([error.localizedDescription containsString:@"larger than 1 MB"],
             "the oversized config error should explain the shared size limit");
}

int main(void) {
    @autoreleasepool {
        TestConfigurationDecoding();
        TestValidation();
        TestRoundTrip();
        TestPrivateBrowsingMustBeBoolean();
        TestEncodedConfigurationSizeLimit();
        return LRFinishTests();
    }
}

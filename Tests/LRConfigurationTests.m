#import <Foundation/Foundation.h>

#import "LRRouting.h"
#import "LRTestSupport.h"

static LRRouterConfiguration *ReferenceConfiguration(void) {
    NSString *JSON = @"{\"default\":{\"app\":\"Safari\"},"
                     "\"rules\":[{\"name\":\"Work\","
                     "\"hosts\":[\"*.example.com\"],"
                     "\"app\":\"Google Chrome\",\"profile\":\"Profile 1\"}]}";
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
}

int main(void) {
    @autoreleasepool {
        TestConfigurationDecoding();
        TestValidation();
        TestRoundTrip();
        return LRFinishTests();
    }
}

#import <Foundation/Foundation.h>

#import "LRRuleDraft.h"
#import "LRTestSupport.h"

static void TestDraftConvertsEditableTextToRule(void) {
    LRRuleDraft *draft = LRRuleDraft.newDraft;
    draft.name = @"  Work  ";
    draft.hostsText = @" *.Example.com, console.cloud.google.com\n\napi.example.org ";
    draft.application = LRBrowserApplicationChrome;
    draft.profile = @" Profile 1 ";
    draft.privateBrowsing = YES;

    LRRoutingRule *rule = draft.routingRule;
    LRAssert([rule.name isEqualToString:@"Work"], "draft should trim the rule name");
    NSArray<NSString *> *expected = @[
        @"*.example.com", @"console.cloud.google.com", @"api.example.org"
    ];
    LRAssert([rule.hosts isEqualToArray:expected],
             "draft should split, trim, lowercase, and remove empty host patterns");
    LRAssert(rule.target.application == LRBrowserApplicationChrome,
             "draft should preserve browser selection");
    LRAssert([rule.target.profile isEqualToString:@"Profile 1"],
             "browser target should trim the Chrome profile");
    LRAssert(rule.target.privateBrowsing, "draft should preserve private browsing");
}

static void TestDraftRoundTrip(void) {
    LRRoutingRule *rule = [LRRoutingRule
        ruleWithName:@"Personal"
               hosts:@[@"example.net", @"*.example.org"]
              target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari profile:nil]];
    LRRuleDraft *draft = [LRRuleDraft draftFromRule:rule];
    LRRoutingRule *roundTrip = draft.routingRule;

    LRAssert([draft.hostsText isEqualToString:@"example.net, *.example.org"],
             "existing hosts should be presented as editable comma-separated text");
    LRAssert([roundTrip.hosts isEqualToArray:rule.hosts],
             "unchanged draft should preserve its host patterns");
    LRAssert(roundTrip.target.application == LRBrowserApplicationSafari,
             "unchanged draft should preserve Safari");
    LRAssert(!roundTrip.target.privateBrowsing,
             "a Safari draft should not enable unsupported private browsing");
}

int main(void) {
    @autoreleasepool {
        TestDraftConvertsEditableTextToRule();
        TestDraftRoundTrip();
        return LRFinishTests();
    }
}

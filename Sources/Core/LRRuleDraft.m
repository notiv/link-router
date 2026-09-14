#import "LRRuleDraft.h"

@implementation LRRuleDraft

+ (instancetype)draftFromRule:(LRRoutingRule *)rule {
    LRRuleDraft *draft = [[self alloc] init];
    draft.name = rule.name;
    draft.hostsText = [rule.hosts componentsJoinedByString:@", "];
    draft.application = rule.target.application;
    draft.profile = rule.target.profile;
    draft.privateBrowsing = rule.target.privateBrowsing;
    return draft;
}

+ (instancetype)newDraft {
    LRRuleDraft *draft = [[self alloc] init];
    draft.name = @"New Rule";
    draft.hostsText = @"example.com";
    draft.application = LRBrowserApplicationSafari;
    draft.profile = nil;
    draft.privateBrowsing = NO;
    return draft;
}

- (LRRoutingRule *)routingRule {
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@",\n"];
    NSArray<NSString *> *components = [self.hostsText componentsSeparatedByCharactersInSet:separators];
    NSMutableArray<NSString *> *hosts = [NSMutableArray array];
    for (NSString *component in components) {
        NSString *host = [[component stringByTrimmingCharactersInSet:
            NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
        if (host.length > 0) {
            [hosts addObject:host];
        }
    }
    NSString *name = [self.name stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    LRBrowserTarget *target = [LRBrowserTarget targetWithApplication:self.application
                                                             profile:self.application == LRBrowserApplicationChrome
                                                                         ? self.profile
                                                                         : nil
                                                     privateBrowsing:self.application == LRBrowserApplicationChrome &&
                                                                         self.privateBrowsing];
    return [LRRoutingRule ruleWithName:name hosts:hosts target:target];
}

@end

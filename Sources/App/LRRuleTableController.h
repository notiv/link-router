#import <AppKit/AppKit.h>

@class LRRoutingRule;

NS_ASSUME_NONNULL_BEGIN

@interface LRRuleTableController : NSViewController

- (void)setRoutingRules:(NSArray<LRRoutingRule *> *)rules;
- (NSArray<LRRoutingRule *> *)routingRules;

@end

NS_ASSUME_NONNULL_END

#import <AppKit/AppKit.h>

@class LRRoutingRule;
@class LRBrowserTarget;

NS_ASSUME_NONNULL_BEGIN

@interface LRRuleTableController : NSViewController

@property(nonatomic, copy, nullable) void (^changeHandler)(void);

- (void)setRoutingRules:(NSArray<LRRoutingRule *> *)rules;
- (NSArray<LRRoutingRule *> *)routingRules;
- (NSUInteger)ruleCount;
- (void)setDefaultTarget:(LRBrowserTarget *)target;
- (LRBrowserTarget *)defaultTarget;

@end

NS_ASSUME_NONNULL_END

#import <Foundation/Foundation.h>

#import "LRRouting.h"

NS_ASSUME_NONNULL_BEGIN

@interface LRRuleDraft : NSObject

@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *hostsText;
@property(nonatomic) LRBrowserApplication application;
@property(nonatomic, copy, nullable) NSString *profile;

+ (instancetype)draftFromRule:(LRRoutingRule *)rule;
+ (instancetype)newDraft;
- (LRRoutingRule *)routingRule;

@end

NS_ASSUME_NONNULL_END

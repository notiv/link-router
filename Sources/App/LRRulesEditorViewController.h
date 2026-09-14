#import <AppKit/AppKit.h>

@class LRRouterConfiguration;

NS_ASSUME_NONNULL_BEGIN

typedef void (^LRRulesEditorChangeHandler)(void);

@interface LRRulesEditorViewController : NSSplitViewController

- (instancetype)initWithConfiguration:(LRRouterConfiguration *)configuration
                  configurationChanged:(LRRulesEditorChangeHandler)configurationChanged;
- (void)setConfiguration:(LRRouterConfiguration *)configuration;
- (LRRouterConfiguration *)currentConfiguration;

@end

NS_ASSUME_NONNULL_END

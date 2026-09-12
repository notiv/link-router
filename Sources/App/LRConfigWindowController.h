#import <AppKit/AppKit.h>

@class LRConfigStore;
@class LRRouterConfiguration;

NS_ASSUME_NONNULL_BEGIN

typedef void (^LRConfigurationSavedHandler)(LRRouterConfiguration *configuration);

@interface LRConfigWindowController : NSWindowController

- (instancetype)initWithConfigStore:(LRConfigStore *)configStore
               configurationSaved:(LRConfigurationSavedHandler)configurationSaved;
- (void)showEditor;

@end

NS_ASSUME_NONNULL_END

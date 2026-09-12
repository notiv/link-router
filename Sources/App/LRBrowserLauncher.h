#import <Foundation/Foundation.h>

@class LRBrowserTarget;

NS_ASSUME_NONNULL_BEGIN

typedef void (^LRBrowserLaunchCompletion)(NSError *_Nullable error);

@protocol LRBrowserLaunching <NSObject>
- (void)openURL:(NSURL *)URL
         target:(LRBrowserTarget *)target
     completion:(LRBrowserLaunchCompletion)completion;
@end

@interface LRBrowserLauncher : NSObject <LRBrowserLaunching>
@end

NS_ASSUME_NONNULL_END

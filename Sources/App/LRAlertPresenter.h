#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LRAlertPresenting <NSObject>
- (void)presentFailureWithTitle:(NSString *)title message:(NSString *)message;
@end

@interface LRAlertPresenter : NSObject <LRAlertPresenting>
@end

NS_ASSUME_NONNULL_END

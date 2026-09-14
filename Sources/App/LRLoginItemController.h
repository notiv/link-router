#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LRLoginItemState) {
    LRLoginItemStateDisabled,
    LRLoginItemStateEnabled,
    LRLoginItemStateRequiresApproval,
};

@protocol LRLoginItemControlling <NSObject>
@property(nonatomic, readonly) LRLoginItemState state;
- (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error;
- (void)openSystemSettings;
@end

@interface LRLoginItemController : NSObject <LRLoginItemControlling>
@end

NS_ASSUME_NONNULL_END

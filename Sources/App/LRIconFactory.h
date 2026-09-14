#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LRIconFactory : NSObject
+ (NSImage *)menuBarIcon;
+ (NSImage *)applicationIconWithSize:(CGFloat)size;
@end

NS_ASSUME_NONNULL_END

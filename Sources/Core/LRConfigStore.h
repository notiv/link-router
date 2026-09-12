#import <Foundation/Foundation.h>

@class LRRouterConfiguration;

NS_ASSUME_NONNULL_BEGIN

@interface LRConfigStore : NSObject

@property(nonatomic, copy, readonly) NSURL *configURL;

+ (NSURL *)defaultConfigURL;
- (instancetype)initWithConfigURL:(NSURL *)configURL;
- (BOOL)ensureDefaultConfigExists:(NSError **)error;
- (nullable LRRouterConfiguration *)loadConfiguration:(NSError **)error;
- (BOOL)saveConfiguration:(LRRouterConfiguration *)configuration error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

#import "LRConfigStore.h"

#import "LRRouting.h"

@interface LRConfigStore ()
@property(nonatomic, copy, readwrite) NSURL *configURL;
@end

@implementation LRConfigStore

+ (NSURL *)defaultConfigURL {
    NSURL *applicationSupport = [NSFileManager.defaultManager
        URLsForDirectory:NSApplicationSupportDirectory
               inDomains:NSUserDomainMask].firstObject;
    return [[applicationSupport URLByAppendingPathComponent:@"LinkRouter" isDirectory:YES]
        URLByAppendingPathComponent:@"config.json" isDirectory:NO];
}

- (instancetype)initWithConfigURL:(NSURL *)configURL {
    self = [super init];
    if (self) {
        _configURL = [configURL copy];
    }
    return self;
}

- (BOOL)ensureDefaultConfigExists:(NSError **)error {
    if ([NSFileManager.defaultManager fileExistsAtPath:self.configURL.path]) {
        return YES;
    }
    if (![self ensureParentDirectory:error]) {
        return NO;
    }
    NSData *data = [[LRRouterConfiguration defaultConfiguration] JSONDataWithError:error];
    if (data == nil) {
        return NO;
    }
    if (![data writeToURL:self.configURL
                  options:NSDataWritingWithoutOverwriting
                    error:error]) {
        return [NSFileManager.defaultManager fileExistsAtPath:self.configURL.path];
    }
    return [self restrictConfigPermissions:error];
}

- (LRRouterConfiguration *)loadConfiguration:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfURL:self.configURL options:NSDataReadingMappedIfSafe error:error];
    if (data == nil) {
        return nil;
    }
    return [LRRouterConfiguration configurationFromData:data error:error];
}

- (BOOL)saveConfiguration:(LRRouterConfiguration *)configuration error:(NSError **)error {
    NSData *data = [configuration JSONDataWithError:error];
    if (data == nil || ![self ensureParentDirectory:error]) {
        return NO;
    }
    if ([NSFileManager.defaultManager fileExistsAtPath:self.configURL.path]) {
        NSError *existingError = nil;
        if ([self loadConfiguration:&existingError] == nil) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:LRRoutingErrorDomain
                                             code:LRRoutingErrorInvalidConfiguration
                                         userInfo:@{
                                             NSLocalizedDescriptionKey:
                                                 @"Refusing to replace the malformed config file. Open the JSON file to repair it first.",
                                             NSUnderlyingErrorKey: existingError,
                                         }];
            }
            return NO;
        }
    }
    if (![data writeToURL:self.configURL options:NSDataWritingAtomic error:error]) {
        return NO;
    }
    return [self restrictConfigPermissions:error];
}

- (BOOL)ensureParentDirectory:(NSError **)error {
    NSURL *directory = [self.configURL URLByDeletingLastPathComponent];
    if (![NSFileManager.defaultManager createDirectoryAtURL:directory
                                withIntermediateDirectories:YES
                                                 attributes:@{NSFilePosixPermissions: @0700}
                                                      error:error]) {
        return NO;
    }
    return [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions: @0700}
                                          ofItemAtPath:directory.path
                                                 error:error];
}

- (BOOL)restrictConfigPermissions:(NSError **)error {
    return [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions: @0600}
                                          ofItemAtPath:self.configURL.path
                                                 error:error];
}

@end

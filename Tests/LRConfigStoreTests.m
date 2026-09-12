#import <Foundation/Foundation.h>

#import "LRConfigStore.h"
#import "LRRouting.h"
#import "LRTestSupport.h"

static NSURL *TemporaryDirectory(void) {
    NSString *name = [@"LinkRouterTests-" stringByAppendingString:NSUUID.UUID.UUIDString];
    return [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
        URLByAppendingPathComponent:name
                         isDirectory:YES];
}

static void TestCreateSaveAndReload(void) {
    NSURL *directory = TemporaryDirectory();
    NSURL *configURL = [directory URLByAppendingPathComponent:@"config.json"];
    LRConfigStore *store = [[LRConfigStore alloc] initWithConfigURL:configURL];
    NSError *error = nil;

    LRAssert([store ensureDefaultConfigExists:&error], "first launch should create a default config");
    LRRouterConfiguration *initial = [store loadConfiguration:&error];
    LRAssert(initial != nil && error == nil, "created default config should load");
    LRAssert(initial.defaultTarget.application == LRBrowserApplicationSafari,
             "created config should safely default to Safari");

    LRRoutingRule *rule = [LRRoutingRule
        ruleWithName:@"Work"
               hosts:@[@"*.example.com"]
              target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome
                                                     profile:@"Profile 1"]];
    LRRouterConfiguration *edited = [[LRRouterConfiguration alloc]
        initWithDefaultTarget:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari
                                                              profile:nil]
                         rules:@[rule]];
    LRAssert([store saveConfiguration:edited error:&error], "valid edits should save atomically");
    LRRouterConfiguration *reloaded = [store loadConfiguration:&error];
    LRAssert([reloaded.rules.firstObject.name isEqualToString:@"Work"],
             "saved edits should reload from disk");

    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:configURL.path
                                                                                error:&error];
    LRAssert([attributes[NSFilePosixPermissions] unsignedShortValue] == 0600,
             "config file permissions should be user-only");
    [NSFileManager.defaultManager removeItemAtURL:directory error:nil];
}

static void TestDoesNotOverwriteInvalidExistingConfig(void) {
    NSURL *directory = TemporaryDirectory();
    NSURL *configURL = [directory URLByAppendingPathComponent:@"config.json"];
    NSError *error = nil;
    [NSFileManager.defaultManager createDirectoryAtURL:directory
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:&error];
    NSData *invalid = [@"{ definitely not JSON" dataUsingEncoding:NSUTF8StringEncoding];
    [invalid writeToURL:configURL options:NSDataWritingAtomic error:&error];
    LRConfigStore *store = [[LRConfigStore alloc] initWithConfigURL:configURL];

    LRAssert([store ensureDefaultConfigExists:&error], "existing config should be left in place");
    LRAssert([store loadConfiguration:&error] == nil, "invalid existing config should fail visibly");
    NSData *unchanged = [NSData dataWithContentsOfURL:configURL options:0 error:nil];
    LRAssert([unchanged isEqualToData:invalid], "invalid existing config must not be overwritten");
    [NSFileManager.defaultManager removeItemAtURL:directory error:nil];
}

int main(void) {
    @autoreleasepool {
        TestCreateSaveAndReload();
        TestDoesNotOverwriteInvalidExistingConfig();
        return LRFinishTests();
    }
}

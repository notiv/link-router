#import <AppKit/AppKit.h>

#import "LRAppDelegate.h"
#import "LRConfigStore.h"
#import "LRConfigWindowController.h"
#import "LRRouting.h"
#import "LRRuleTableController.h"
#import "LRTestSupport.h"

@interface LRAppDelegate (Testing)
- (void)buildStatusMenu;
@end

@interface LRConfigWindowController (Testing)
- (void)reload:(id)sender;
- (void)save:(id)sender;
@end

static void TestStatusMenuActionsHaveExplicitTargets(void) {
    (void)NSApplication.sharedApplication;
    LRAppDelegate *delegate = [[LRAppDelegate alloc] init];
    [delegate buildStatusMenu];
    NSStatusItem *statusItem = [delegate valueForKey:@"statusItem"];

    NSUInteger actionCount = 0;
    for (NSMenuItem *item in statusItem.menu.itemArray) {
        if (item.action == nil) {
            continue;
        }
        actionCount += 1;
        LRAssert(item.target == delegate, "every status-menu command should target the app delegate");
    }
    LRAssert(actionCount == 5, "the status menu should expose five commands");
    [NSStatusBar.systemStatusBar removeStatusItem:statusItem];
}

static void TestEditorSaveReloadFlow(void) {
    NSURL *directory = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
        URLByAppendingPathComponent:[@"LinkRouterEditorTests-"
                                        stringByAppendingString:NSUUID.UUID.UUIDString]
                         isDirectory:YES];
    LRConfigStore *store = [[LRConfigStore alloc]
        initWithConfigURL:[directory URLByAppendingPathComponent:@"config.json"]];
    NSError *error = nil;
    LRAssert([store ensureDefaultConfigExists:&error], "the editor test config should be created");

    __block LRRouterConfiguration *savedConfiguration = nil;
    LRConfigWindowController *controller = [[LRConfigWindowController alloc]
        initWithConfigStore:store
         configurationSaved:^(LRRouterConfiguration *configuration) {
             savedConfiguration = configuration;
         }];
    [controller reload:nil];
    NSPopUpButton *fallbackPicker = [controller valueForKey:@"defaultBrowserPicker"];
    NSTextField *fallbackProfile = [controller valueForKey:@"defaultProfileField"];
    LRRuleTableController *ruleTable = [controller valueForKey:@"ruleTableController"];
    [fallbackPicker selectItemAtIndex:LRBrowserApplicationChrome];
    fallbackProfile.stringValue = @"Profile 2";
    LRRoutingRule *rule = [LRRoutingRule
        ruleWithName:@"Work"
               hosts:@[@"*.example.com"]
              target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari profile:nil]];
    [ruleTable setRoutingRules:@[rule]];
    [controller save:nil];

    LRRouterConfiguration *reloaded = [store loadConfiguration:&error];
    LRAssert(savedConfiguration != nil, "a successful editor save should update live app state");
    LRAssert(reloaded.defaultTarget.application == LRBrowserApplicationChrome,
             "the editor should save its selected fallback browser");
    LRAssert([reloaded.defaultTarget.profile isEqualToString:@"Profile 2"],
             "the editor should save the fallback Chrome profile");
    LRAssert([reloaded.rules.firstObject.name isEqualToString:@"Work"],
             "the editor should save and reload ordered routing rules");
    [NSFileManager.defaultManager removeItemAtURL:directory error:nil];
}

int main(void) {
    @autoreleasepool {
        TestStatusMenuActionsHaveExplicitTargets();
        TestEditorSaveReloadFlow();
        return LRFinishTests();
    }
}

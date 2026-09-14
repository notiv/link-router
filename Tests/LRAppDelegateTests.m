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
- (void)defaultBrowserChanged:(id)sender;
- (void)reload:(id)sender;
- (void)save:(id)sender;
@end

@interface LRRuleTableController (Testing)
- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row;
- (void)privateChanged:(NSButton *)sender;
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
    NSButton *fallbackPrivate = [controller valueForKey:@"defaultPrivateButton"];
    LRRuleTableController *ruleTable = [controller valueForKey:@"ruleTableController"];
    LRAssert(!fallbackPrivate.enabled,
             "the editor should disable private browsing for a Safari fallback");
    [fallbackPicker selectItemAtIndex:LRBrowserApplicationChrome];
    [controller defaultBrowserChanged:nil];
    LRAssert(fallbackPrivate.enabled,
             "the editor should offer private browsing when Chrome is selected");
    fallbackProfile.stringValue = @"Profile 2";
    fallbackPrivate.state = NSControlStateValueOn;
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
    LRAssert(reloaded.defaultTarget.privateBrowsing,
             "the editor should save the fallback private-browsing option");
    LRAssert([reloaded.rules.firstObject.name isEqualToString:@"Work"],
             "the editor should save and reload ordered routing rules");
    [NSFileManager.defaultManager removeItemAtURL:directory error:nil];
}

static void TestRuleTablePrivateControlUpdatesChromeTarget(void) {
    LRRuleTableController *controller = [[LRRuleTableController alloc] init];
    (void)controller.view;
    LRRoutingRule *rule = [LRRoutingRule
        ruleWithName:@"Work"
               hosts:@[@"example.com"]
              target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome profile:nil]];
    [controller setRoutingRules:@[rule]];

    NSTableView *tableView = [controller valueForKey:@"tableView"];
    NSTableColumn *privateColumn = nil;
    for (NSTableColumn *column in tableView.tableColumns) {
        if ([column.identifier isEqualToString:@"private"]) {
            privateColumn = column;
            break;
        }
    }
    NSButton *privateButton = (NSButton *)[controller tableView:tableView
                                            viewForTableColumn:privateColumn
                                                           row:0];
    LRAssert(privateButton != nil && privateButton.enabled,
             "a Chrome rule should expose an enabled private control");
    privateButton.state = NSControlStateValueOn;
    [controller privateChanged:privateButton];

    LRAssert(controller.routingRules.firstObject.target.privateBrowsing,
             "the private control should update the Chrome target");
}

int main(void) {
    @autoreleasepool {
        TestStatusMenuActionsHaveExplicitTargets();
        TestEditorSaveReloadFlow();
        TestRuleTablePrivateControlUpdatesChromeTarget();
        return LRFinishTests();
    }
}

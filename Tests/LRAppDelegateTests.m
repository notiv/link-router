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
- (void)domainModeChanged:(NSSegmentedControl *)sender;
- (void)privateChanged:(NSButton *)sender;
- (void)selectLocalFiles:(id)sender;
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
    LRRuleTableController *ruleTable = [controller valueForKey:@"ruleTableController"];
    [ruleTable setDefaultTarget:[LRBrowserTarget
        targetWithApplication:LRBrowserApplicationChrome
                       profile:@"Profile 2"
               privateBrowsing:YES]];
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

    NSButton *privateButton = [controller valueForKey:@"privateButton"];
    LRAssert(privateButton != nil && privateButton.enabled,
             "a Chrome rule should expose an enabled private control");
    privateButton.state = NSControlStateValueOn;
    [controller privateChanged:privateButton];

    LRAssert(controller.routingRules.firstObject.target.privateBrowsing,
             "the private control should update the Chrome target");
}

static void TestRulesEditorPresentsWildcardHostsAsDomainModes(void) {
    LRRuleTableController *controller = [[LRRuleTableController alloc] init];
    (void)controller.view;
    LRRoutingRule *rule = [LRRoutingRule
        ruleWithName:@"Work"
               hosts:@[@"*.example.com"]
              target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome profile:nil]];
    [controller setRoutingRules:@[rule]];

    NSArray<NSTextField *> *domainFields = [controller valueForKey:@"domainFields"];
    NSArray<NSSegmentedControl *> *modeControls = [controller valueForKey:@"domainModeControls"];
    LRAssert([domainFields.firstObject.stringValue isEqualToString:@"example.com"],
             "the domain field should omit the wildcard prefix");
    LRAssert(modeControls.firstObject.selectedSegment == 1,
             "a wildcard host should select the subdomains matching mode");

    modeControls.firstObject.selectedSegment = 0;
    [controller domainModeChanged:modeControls.firstObject];
    LRAssert([controller.routingRules.firstObject.hosts.firstObject isEqualToString:@"example.com"],
             "switching to exact matching should remove the wildcard prefix");
}

static void TestRulesEditorUsesAReferenceStyleSidebar(void) {
    LRRuleTableController *controller = [[LRRuleTableController alloc] init];
    (void)controller.view;
    NSTableView *tableView = [controller valueForKey:@"tableView"];

    LRAssert(tableView.headerView == nil,
             "the redesigned rules editor should use a headerless sidebar list");
    LRAssert(tableView.tableColumns.count == 1,
             "the sidebar should present each route as one scannable item");
    NSButton *fallbackButton = [controller valueForKey:@"fallbackButton"];
    NSButton *localFilesButton = [controller valueForKey:@"localFilesButton"];
    LRAssert([fallbackButton.title containsString:@"Unmatched links"],
             "the sidebar should expose fallback routing as Unmatched links");
    LRAssert([localFilesButton.title containsString:@"Local files"],
             "the sidebar should expose local-file routing explicitly");
}

static void TestLocalFilesExplainThatTheyFollowTheFallback(void) {
    LRRuleTableController *controller = [[LRRuleTableController alloc] init];
    (void)controller.view;
    [controller selectLocalFiles:nil];
    NSTextField *detailDescription = [controller valueForKey:@"detailDescriptionLabel"];

    LRAssert([detailDescription.stringValue containsString:@"Unmatched links"],
             "the local-files detail should explain the inherited fallback behavior");
}

int main(void) {
    @autoreleasepool {
        TestRulesEditorUsesAReferenceStyleSidebar();
        TestLocalFilesExplainThatTheyFollowTheFallback();
        TestEditorSaveReloadFlow();
        TestRuleTablePrivateControlUpdatesChromeTarget();
        TestRulesEditorPresentsWildcardHostsAsDomainModes();
        TestStatusMenuActionsHaveExplicitTargets();
        return LRFinishTests();
    }
}

#import <AppKit/AppKit.h>
#import "LRAppDelegate.h"
#import "LRConfigStore.h"
#import "LRConfigWindowController.h"
#import "LRLoginItemController.h"
#import "LRRouting.h"
#import "LRRulesEditorViewController.h"
#import "LRTestSupport.h"

@interface LRAppDelegate (Testing)
- (NSMenu *)buildMenu;
- (void)menuNeedsUpdate:(NSMenu *)menu;
- (void)toggleStartAtLogin:(id)sender;
@end

@interface LRConfigWindowController (Testing)
- (void)saveConfiguration:(LRRouterConfiguration *)configuration;
@end

@interface LRRulesEditorViewController (Testing)
- (void)domainModeChanged:(NSSegmentedControl *)sender;
- (void)moveRuleAtIndex:(NSUInteger)sourceIndex toChildIndex:(NSUInteger)childIndex;
- (void)selectItem:(id)item;
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldShowOutlineCellForItem:(id)item;
@end

@interface NSButton (LRHoverTesting)
- (void)setExpanded:(BOOL)expanded;
@end

@interface LRRecordingLoginItemController : NSObject <LRLoginItemControlling>
@property(nonatomic) LRLoginItemState state;
@property(nonatomic) BOOL requestedEnabled;
@property(nonatomic) NSUInteger settingsOpenCount;
@property(nonatomic) BOOL shouldFail;
@end

@implementation LRRecordingLoginItemController

- (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error {
    self.requestedEnabled = enabled;
    if (self.shouldFail) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"LRLoginItemTests"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Registration failed"}];
        }
        return NO;
    }
    self.state = enabled ? LRLoginItemStateEnabled : LRLoginItemStateDisabled;
    return YES;
}

- (void)openSystemSettings {
    self.settingsOpenCount += 1;
}

@end

static NSView *FindDescendantOfClass(NSView *view, Class viewClass) {
    if ([view isKindOfClass:viewClass]) { return view; }
    for (NSView *subview in view.subviews) {
        NSView *match = FindDescendantOfClass(subview, viewClass);
        if (match != nil) { return match; }
    }
    return nil;
}

static NSButton *FindButtonWithAccessibilityLabel(NSView *view, NSString *label) {
    if ([view isKindOfClass:NSButton.class] &&
        [[view accessibilityLabel] isEqualToString:label]) {
        return (NSButton *)view;
    }
    for (NSView *subview in view.subviews) {
        NSButton *match = FindButtonWithAccessibilityLabel(subview, label);
        if (match != nil) { return match; }
    }
    return nil;
}

static NSTextField *FindLabelWithText(NSView *view, NSString *text) {
    if ([view isKindOfClass:NSTextField.class] &&
        [((NSTextField *)view).stringValue isEqualToString:text]) {
        return (NSTextField *)view;
    }
    for (NSView *subview in view.subviews) {
        NSTextField *match = FindLabelWithText(subview, text);
        if (match != nil) { return match; }
    }
    return nil;
}

static void TestEditorUsesNativeLiquidGlassControls(void) {
    NSURL *configURL = [NSURL fileURLWithPath:[NSTemporaryDirectory()
        stringByAppendingPathComponent:@"LinkRouter-Native-Surface.json"]];
    LRConfigStore *store = [[LRConfigStore alloc] initWithConfigURL:configURL];
    LRConfigWindowController *controller = [[LRConfigWindowController alloc]
        initWithConfigStore:store configurationSaved:^(LRRouterConfiguration *configuration) {
            (void)configuration;
        }];

    NSView *contentView = controller.window.contentView;
    NSVisualEffectView *sidebarMaterial = (NSVisualEffectView *)FindDescendantOfClass(
        contentView, NSVisualEffectView.class);
    LRAssert(FindDescendantOfClass(contentView, NSOutlineView.class) != nil,
             "the editor should navigate rules with a native source-list outline view");
    LRAssert(FindDescendantOfClass(contentView, NSSegmentedControl.class) != nil,
             "the editor should use native browser selection controls");
    LRAssert(![controller.window standardWindowButton:NSWindowCloseButton].hidden,
             "the editor should use the native macOS window controls");
    LRAssert(sidebarMaterial.material == NSVisualEffectMaterialSidebar &&
                 sidebarMaterial.blendingMode == NSVisualEffectBlendingModeWithinWindow,
             "the sidebar should use an adaptive Finder-style semantic material");
    controller.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    NSString *appearanceName = [sidebarMaterial.effectiveAppearance
        bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
    LRAssert([appearanceName isEqualToString:NSAppearanceNameDarkAqua],
             "the native editor should follow the user's dark appearance");
    if (@available(macOS 26.0, *)) {
        Class glassClass = NSClassFromString(@"NSGlassEffectView");
        LRAssert(glassClass != Nil && FindDescendantOfClass(contentView, glassClass) != nil,
                 "the action surface should use the system Liquid Glass effect");
    } else {
        LRAssert(FindDescendantOfClass(contentView, NSVisualEffectView.class) != nil,
                 "older macOS releases should receive a native material fallback");
    }
}

static void TestNativeSettingsSaveValidatedConfiguration(void) {
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
    LRBrowserTarget *fallback = [LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome
                                                               profile:@"Profile 2"
                                                       privateBrowsing:YES];
    LRRoutingRule *rule = [LRRoutingRule
        ruleWithName:@"Work"
               hosts:@[@"*.example.com"]
              target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari profile:nil]];
    LRRouterConfiguration *document = [[LRRouterConfiguration alloc]
        initWithDefaultTarget:fallback
                         rules:@[rule]];
    [controller saveConfiguration:document];

    LRRouterConfiguration *reloaded = [store loadConfiguration:&error];
    LRAssert(savedConfiguration != nil, "saving from the native editor should update live app state");
    LRAssert(reloaded.defaultTarget.application == LRBrowserApplicationChrome,
             "the native editor should save its fallback browser");
    LRAssert([reloaded.defaultTarget.profile isEqualToString:@"Profile 2"],
             "the native editor should save the Chrome profile");
    LRAssert(reloaded.defaultTarget.privateBrowsing,
             "the native editor should save private browsing");
    LRAssert([reloaded.rules.firstObject.hosts.firstObject isEqualToString:@"*.example.com"],
             "the native editor should preserve subdomain matching");
    [NSFileManager.defaultManager removeItemAtURL:directory error:nil];
}

static void TestSidebarUsesInlineRuleManagement(void) {
    LRRoutingRule *rule = [LRRoutingRule
        ruleWithName:@"Work"
               hosts:@[@"example.com"]
              target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari profile:nil]];
    LRRouterConfiguration *configuration = [[LRRouterConfiguration alloc]
        initWithDefaultTarget:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari
                                                              profile:nil]
                         rules:@[rule]];
    LRRulesEditorViewController *editor = [[LRRulesEditorViewController alloc]
        initWithConfiguration:configuration configurationChanged:^{}];
    editor.view.frame = NSMakeRect(0.0, 0.0, 820.0, 520.0);
    [editor.view layoutSubtreeIfNeeded];
    NSOutlineView *rules = [editor valueForKey:@"sidebarOutlineView"];
    [rules rowViewAtRow:1 makeIfNecessary:YES];

    LRAssert(FindButtonWithAccessibilityLabel(editor.view, @"Move selected rule up") == nil,
             "rule ordering should use drag and drop instead of a permanent up button");
    LRAssert(FindButtonWithAccessibilityLabel(editor.view, @"Move selected rule down") == nil,
             "rule ordering should use drag and drop instead of a permanent down button");
    LRAssert(FindButtonWithAccessibilityLabel(editor.view, @"Remove selected rule") == nil,
             "rule removal should appear inline on hover instead of in a permanent toolbar");
    NSTableCellView *groupCell = [rules viewAtColumn:0 row:0 makeIfNecessary:YES];
    NSTableCellView *ruleCell = [rules viewAtColumn:0 row:1 makeIfNecessary:YES];
    [groupCell layoutSubtreeIfNeeded];
    [ruleCell layoutSubtreeIfNeeded];
    NSButton *addButton = FindButtonWithAccessibilityLabel(groupCell, @"Add rule");
    NSButton *deleteButton = FindButtonWithAccessibilityLabel(ruleCell, @"Delete rule");
    LRAssert(addButton != nil,
             "the Rules heading should expose a compact inline add button");
    LRAssert(deleteButton != nil, "rule rows should own an inline Delete affordance");
    if (deleteButton != nil) {
        LRAssert(!deleteButton.hidden,
                 "the selected rule should clearly expose its remove control");
        NSPoint deleteCenter = [deleteButton convertPoint:
            NSMakePoint(NSMidX(deleteButton.bounds), NSMidY(deleteButton.bounds))
                                                  toView:ruleCell];
        LRAssert([ruleCell hitTest:deleteCenter] == deleteButton,
                 "the inline Delete affordance should receive clicks in the native cell");
        LRAssert(deleteButton.target == editor &&
                     deleteButton.action == NSSelectorFromString(@"removeRuleFromSidebar:"),
                 "the inline Delete affordance should be wired to rule removal");
        [deleteButton setExpanded:YES];
        LRAssert([deleteButton.attributedTitle.string isEqualToString:@"Delete"],
                 "hovering the selected rule's minus should reveal Delete");
        LRAssert(deleteButton.bordered &&
                     deleteButton.bezelStyle == NSBezelStyleAccessoryBarAction,
                 "Delete should be a compact native button rather than bare text");
        [deleteButton setExpanded:NO];
    }
    if (addButton != nil && deleteButton != nil) {
        NSPoint addCenter = [addButton convertPoint:
            NSMakePoint(NSMidX(addButton.bounds), NSMidY(addButton.bounds))
                                             toView:rules];
        NSPoint deleteCenter = [deleteButton convertPoint:
            NSMakePoint(NSMidX(deleteButton.bounds), NSMidY(deleteButton.bounds))
                                                   toView:rules];
        LRAssert(ABS(addCenter.x - deleteCenter.x) < 0.5,
                 "the selected rule's minus should align exactly beneath the Rules plus");
    }

    LRAssert([rules.registeredDraggedTypes containsObject:@"com.linkrouter.rule-row"],
             "rule rows should register for native drag-and-drop reordering");
    NSOutlineView *otherRoutes = [editor valueForKey:@"specialRoutesOutlineView"];
    LRAssert(otherRoutes.numberOfRows == 1,
             "the sidebar should expose only Unmatched links below the rules");
    NSTableCellView *fallbackCell = [otherRoutes viewAtColumn:0 row:0 makeIfNecessary:YES];
    NSTextField *otherRoutesHeading = FindLabelWithText(editor.view, @"Everything Else");
    [fallbackCell layoutSubtreeIfNeeded];
    NSRect headingFrame = [otherRoutesHeading convertRect:otherRoutesHeading.bounds
                                                  toView:editor.view];
    NSRect fallbackFrame = [fallbackCell.textField convertRect:fallbackCell.textField.bounds
                                                        toView:editor.view];
    CGFloat fallbackGap = ABS(NSMidY(headingFrame) - NSMidY(fallbackFrame)) -
                          (NSHeight(headingFrame) + NSHeight(fallbackFrame)) / 2.0;
    LRAssert(fallbackGap <= 3.0,
             "Unmatched links should sit directly beneath Everything Else");
    LRAssert(rules.indentationPerLevel == 0.0 && otherRoutes.indentationPerLevel == 0.0,
             "rule names and special routes should share one consistent text inset");
    LRAssert(![editor outlineView:rules shouldShowOutlineCellForItem:@"Rules"],
             "the fixed Rules group should not show a disclosure arrow on hover");

    NSStackView *detailStack = [editor valueForKey:@"detailStack"];
    CGFloat ruleTitleX = [detailStack convertPoint:NSZeroPoint toView:editor.view].x;
    [editor selectItem:@"Unmatched links"];
    [editor.view layoutSubtreeIfNeeded];
    LRAssert(deleteButton == nil || deleteButton.hidden,
             "rule removal should hide when its rule is no longer selected");
    CGFloat fallbackTitleX = [detailStack convertPoint:NSZeroPoint toView:editor.view].x;
    LRAssert(ABS(ruleTitleX - fallbackTitleX) < 0.5,
             "large detail titles should remain on one stable alignment guide");

    LRRoutingRule *secondRule = [LRRoutingRule
        ruleWithName:@"Personal"
               hosts:@[@"personal.example.com"]
              target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari profile:nil]];
    LRRouterConfiguration *twoRules = [[LRRouterConfiguration alloc]
        initWithDefaultTarget:configuration.defaultTarget
                         rules:@[rule, secondRule]];
    [editor setConfiguration:twoRules];
    [editor moveRuleAtIndex:0 toChildIndex:2];
    LRAssert([editor.currentConfiguration.rules.firstObject.name isEqualToString:@"Personal"],
             "dropping a rule after another rule should persist the reordered rule list");
}

static void TestFallbackBrowserControlUsesOneRow(void) {
    LRRulesEditorViewController *editor = [[LRRulesEditorViewController alloc]
        initWithConfiguration:LRRouterConfiguration.defaultConfiguration
         configurationChanged:^{}];
    [editor selectItem:@"Unmatched links"];

    NSTextField *openIn = FindLabelWithText(editor.view, @"Open in");
    NSSegmentedControl *browser = (NSSegmentedControl *)FindDescendantOfClass(
        editor.view, NSSegmentedControl.class);
    LRAssert(openIn != nil && browser != nil && openIn.superview == browser.superview,
             "Unmatched links should place Open in and the browser picker on one row");
}

static void TestSubdomainModeDisplaysTheWildcardPrefix(void) {
    LRRoutingRule *rule = [LRRoutingRule
        ruleWithName:@"Work"
               hosts:@[@"example.com"]
              target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari profile:nil]];
    LRRouterConfiguration *configuration = [[LRRouterConfiguration alloc]
        initWithDefaultTarget:[LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari
                                                              profile:nil]
                         rules:@[rule]];
    LRRulesEditorViewController *editor = [[LRRulesEditorViewController alloc]
        initWithConfiguration:configuration configurationChanged:^{}];
    NSSegmentedControl *mode = [NSSegmentedControl
        segmentedControlWithLabels:@[@"Exact", @"Subdomains"]
                      trackingMode:NSSegmentSwitchTrackingSelectOne
                            target:nil
                            action:nil];
    mode.tag = 0;
    mode.selectedSegment = 1;

    [editor domainModeChanged:mode];
    LRAssert([editor.currentConfiguration.rules.firstObject.hosts.firstObject
                 isEqualToString:@"*.example.com"],
             "subdomain mode should add the visible wildcard prefix to the domain pattern");

    mode.selectedSegment = 0;
    [editor domainModeChanged:mode];
    LRAssert([editor.currentConfiguration.rules.firstObject.hosts.firstObject
                 isEqualToString:@"example.com"],
             "exact mode should remove the wildcard prefix from the domain pattern");
}

static void TestStatusMenuActionsHaveExplicitTargets(void) {
    LRAppDelegate *delegate = [[LRAppDelegate alloc] init];
    NSMenu *menu = [delegate buildMenu];

    NSUInteger actionCount = 0;
    for (NSMenuItem *item in menu.itemArray) {
        if (item.action == nil) { continue; }
        actionCount += 1;
        LRAssert(item.target == delegate, "every status-menu command should target the app delegate");
    }
    LRAssert(actionCount == 4, "the status menu should expose four focused commands");
    LRAssert([menu itemWithTitle:@"Reload Config"] == nil,
             "reloading should live in the settings window instead of the status menu");
    LRAssert([menu itemWithTitle:@"Open Config File…"] == nil,
             "opening JSON should live in the settings window instead of the status menu");
}

static NSMenuItem *StartAtLoginMenuItem(NSMenu *menu) {
    for (NSMenuItem *item in menu.itemArray) {
        if (item.action == @selector(toggleStartAtLogin:)) { return item; }
    }
    return nil;
}

static void TestStartAtLoginMenuReflectsAndChangesSystemState(void) {
    LRAppDelegate *delegate = [[LRAppDelegate alloc] init];
    LRRecordingLoginItemController *controller = [[LRRecordingLoginItemController alloc] init];
    controller.state = LRLoginItemStateDisabled;
    [delegate setValue:controller forKey:@"loginItemController"];

    NSMenuItem *item = StartAtLoginMenuItem([delegate buildMenu]);
    LRAssert(item != nil, "the status menu should expose Start at Login");
    LRAssert(item.state == NSControlStateValueOff,
             "a disabled login item should have an unchecked menu option");

    [delegate toggleStartAtLogin:item];
    LRAssert(controller.requestedEnabled, "clicking the unchecked option should enable login launch");
    LRAssert(item.state == NSControlStateValueOn,
             "enabling login launch should check the menu option");

    [delegate toggleStartAtLogin:item];
    LRAssert(!controller.requestedEnabled, "clicking the checked option should disable login launch");
    LRAssert(item.state == NSControlStateValueOff,
             "disabling login launch should uncheck the menu option");

    controller.state = LRLoginItemStateEnabled;
    [delegate menuNeedsUpdate:item.menu];
    LRAssert(item.state == NSControlStateValueOn,
             "opening the menu should refresh login-item state changed in System Settings");
}

static void TestStartAtLoginApprovalOpensSystemSettings(void) {
    LRAppDelegate *delegate = [[LRAppDelegate alloc] init];
    LRRecordingLoginItemController *controller = [[LRRecordingLoginItemController alloc] init];
    controller.state = LRLoginItemStateRequiresApproval;
    [delegate setValue:controller forKey:@"loginItemController"];

    NSMenuItem *item = StartAtLoginMenuItem([delegate buildMenu]);
    LRAssert(item.state == NSControlStateValueMixed,
             "a login item awaiting approval should have a mixed menu state");

    [delegate toggleStartAtLogin:item];
    LRAssert(controller.settingsOpenCount == 1,
             "clicking an approval-required login item should open System Settings");
}

static void TestStartAtLoginFailureIsVisible(void) {
    LRAppDelegate *delegate = [[LRAppDelegate alloc] init];
    LRRecordingLoginItemController *controller = [[LRRecordingLoginItemController alloc] init];
    controller.shouldFail = YES;
    [delegate setValue:controller forKey:@"loginItemController"];

    NSMenu *menu = [delegate buildMenu];
    [delegate toggleStartAtLogin:StartAtLoginMenuItem(menu)];

    LRAssert([menu.itemArray.firstObject.title containsString:@"Registration failed"],
             "a login-item registration failure should be visible in the menu status");
}

int main(void) {
    @autoreleasepool {
        TestEditorUsesNativeLiquidGlassControls();
        TestNativeSettingsSaveValidatedConfiguration();
        TestSidebarUsesInlineRuleManagement();
        TestFallbackBrowserControlUsesOneRow();
        TestSubdomainModeDisplaysTheWildcardPrefix();
        TestStatusMenuActionsHaveExplicitTargets();
        TestStartAtLoginMenuReflectsAndChangesSystemState();
        TestStartAtLoginApprovalOpensSystemSettings();
        TestStartAtLoginFailureIsVisible();
        return LRFinishTests();
    }
}

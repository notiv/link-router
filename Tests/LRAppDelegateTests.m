#import <AppKit/AppKit.h>
#import "LRAlertPresenter.h"
#import "LRAppDelegate.h"
#import "LRBrowserLauncher.h"
#import "LRConfigStore.h"
#import "LRConfigWindowController.h"
#import "LRLoginItemController.h"
#import "LRRouting.h"
#import "LRRulesEditorViewController.h"
#import "LRTestSupport.h"

@interface LRAppDelegate (Testing)
- (void)routeURL:(NSURL *)URL;
// Redeclared so the unaudited signature accepts a nil application in tests.
- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)URLs;
- (NSMenu *)buildMenu;
- (void)menuNeedsUpdate:(NSMenu *)menu;
- (void)toggleStartAtLogin:(id)sender;
@end

@interface LRConfigWindowController (Testing)
- (void)saveConfiguration:(LRRouterConfiguration *)configuration;
@end

@interface LRRulesEditorViewController (Testing)
- (void)addRule:(id)sender;
- (void)domainModeChanged:(NSSegmentedControl *)sender;
- (void)moveRuleAtIndex:(NSUInteger)sourceIndex toChildIndex:(NSUInteger)childIndex;
- (void)removeRule:(id)sender;
- (void)selectItem:(id)item;
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldShowOutlineCellForItem:(id)item;
@end

@interface NSButton (LRHoverTesting)
- (void)setExpanded:(BOOL)expanded;
@end

@interface LRRecordingAlertPresenter : NSObject <LRAlertPresenting>
@property(nonatomic, copy, nullable) NSString *presentedTitle;
@property(nonatomic, copy, nullable) NSString *presentedMessage;
@property(nonatomic) NSUInteger presentCount;
@end

@implementation LRRecordingAlertPresenter

- (void)presentFailureWithTitle:(NSString *)title message:(NSString *)message {
    self.presentedTitle = title;
    self.presentedMessage = message;
    self.presentCount += 1;
}

@end

@interface LRRecordingBrowserLauncher : NSObject <LRBrowserLaunching>
@property(nonatomic, strong, nullable) NSURL *openedURL;
@property(nonatomic, strong, nullable) LRBrowserTarget *openedTarget;
@property(nonatomic) NSUInteger openCount;
// Set to make every launch fail; deferCompletion holds the callbacks so a test
// can model NSWorkspace answering after application:openURLs: has returned.
@property(nonatomic, strong, nullable) NSError *launchError;
@property(nonatomic) BOOL deferCompletion;
@property(nonatomic, strong) NSMutableArray<LRBrowserLaunchCompletion> *deferredCompletions;
- (void)flushDeferredCompletions;
@end

@implementation LRRecordingBrowserLauncher

- (instancetype)init {
    self = [super init];
    if (self) {
        _deferredCompletions = [NSMutableArray array];
    }
    return self;
}

- (void)openURL:(NSURL *)URL
         target:(LRBrowserTarget *)target
     completion:(LRBrowserLaunchCompletion)completion {
    self.openedURL = URL;
    self.openedTarget = target;
    self.openCount += 1;
    NSError *result = self.launchError;
    if (self.deferCompletion) {
        [self.deferredCompletions addObject:^(NSError *unused) {
            (void)unused;
            completion(result);
        }];
        return;
    }
    completion(result);
}

- (void)flushDeferredCompletions {
    NSArray<LRBrowserLaunchCompletion> *pending = [self.deferredCompletions copy];
    [self.deferredCompletions removeAllObjects];
    for (LRBrowserLaunchCompletion completion in pending) {
        completion(nil);
    }
}

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
    [contentView layoutSubtreeIfNeeded];
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
    NSOutlineView *otherRoutes = [controller valueForKeyPath:
        @"rulesEditor.specialRoutesOutlineView"];
    NSTableCellView *fallbackCell = [otherRoutes viewAtColumn:0 row:0 makeIfNecessary:YES];
    NSTextField *statusLabel = [controller valueForKey:@"statusLabel"];
    [fallbackCell layoutSubtreeIfNeeded];
    NSRect fallbackFrame = [fallbackCell.textField convertRect:fallbackCell.textField.bounds
                                                        toView:contentView];
    NSRect statusFrame = [statusLabel convertRect:statusLabel.bounds toView:contentView];
    LRAssert(ABS(NSMidY(fallbackFrame) - NSMidY(statusFrame)) < 0.5,
             "Unmatched links and the action-bar status should align vertically");
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
        NSButton *collapsedButton = [deleteButton valueForKey:@"collapsedButton"];
        NSButton *expandedButton = [deleteButton valueForKey:@"expandedButton"];
        LRAssert(!deleteButton.hidden,
                 "the selected rule should clearly expose its remove control");
        LRAssert(deleteButton.title.length == 0 && !deleteButton.bordered,
                 "the click target itself should not draw over the animated visuals");
        [rules layoutSubtreeIfNeeded];
        NSView *hitContainer = rules.superview;
        NSPoint minusCenter = [collapsedButton convertPoint:
            NSMakePoint(NSMidX(collapsedButton.bounds), NSMidY(collapsedButton.bounds))
                                                     toView:hitContainer];
        LRAssert([rules hitTest:minusCenter] == deleteButton,
                 "clicking the collapsed minus should reach the delete control without waiting");
        NSPoint deleteCenter = [deleteButton convertPoint:
            NSMakePoint(NSMidX(deleteButton.bounds), NSMidY(deleteButton.bounds))
                                                  toView:hitContainer];
        LRAssert([rules hitTest:deleteCenter] == deleteButton,
                 "the whole slot should stay one click target while Delete animates");
        NSPoint besideSlot = [deleteButton convertPoint:
            NSMakePoint(NSMinX(deleteButton.bounds) - 8.0, NSMidY(deleteButton.bounds))
                                                 toView:hitContainer];
        LRAssert([rules hitTest:besideSlot] != deleteButton,
                 "clicking the rule name beside the slot must not trigger deletion");
        LRAssert(deleteButton.target == editor &&
                     deleteButton.action == NSSelectorFromString(@"removeRuleFromSidebar:"),
                 "the inline Delete affordance should be wired to rule removal");
        NSEvent *hoverEvent = (NSEvent *)(id)NSNull.null;
        [deleteButton mouseEntered:hoverEvent];
        LRAssert(!collapsedButton.hidden && expandedButton.hidden,
                 "Delete should wait briefly before expanding on hover");
        [deleteButton mouseExited:hoverEvent];
        [ruleCell layoutSubtreeIfNeeded];
        CGFloat collapsedDeleteWidth = NSWidth(deleteButton.frame);
        NSPoint collapsedTrailing = [collapsedButton convertPoint:
            NSMakePoint(NSMaxX(collapsedButton.bounds), NSMidY(collapsedButton.bounds))
                                                toView:rules];
        [deleteButton setExpanded:YES];
        LRAssert([expandedButton.title isEqualToString:@"Delete"] &&
                     !expandedButton.hidden,
                 "hovering the selected rule's minus should reveal Delete");
        LRAssert(expandedButton.bordered &&
                     expandedButton.bezelStyle == NSBezelStyleAccessoryBarAction,
                 "Delete should be a compact native button rather than bare text");
        LRAssert(expandedButton.controlSize == NSControlSizeSmall &&
                     expandedButton.alignment == NSTextAlignmentCenter,
                 "Delete should use AppKit's centered small-button text metrics");
        LRAssert(expandedButton.hasDestructiveAction,
                 "the Delete button should expose its destructive role to AppKit");
        LRAssert(expandedButton.bezelColor == nil,
                 "the expanded Delete button should let AppKit choose its native surface color");
        [ruleCell layoutSubtreeIfNeeded];
        LRAssert(ABS(collapsedDeleteWidth - NSWidth(deleteButton.frame)) < 0.5,
                 "the Delete reveal should remain inside one fixed final frame");
        LRAssert(NSMaxX(deleteButton.frame) <= NSWidth(ruleCell.bounds) - 14.0,
                 "the expanded Delete button should leave air before the selection edge");
        NSPoint addTrailing = [addButton convertPoint:
            NSMakePoint(NSMaxX(addButton.bounds), NSMidY(addButton.bounds))
                                             toView:rules];
        NSPoint deleteTrailing = [deleteButton convertPoint:
            NSMakePoint(NSMaxX(deleteButton.bounds), NSMidY(deleteButton.bounds))
                                                toView:rules];
        LRAssert(ABS(addTrailing.x - deleteTrailing.x) < 0.5,
                 "the expanded Delete button should share the Rules plus trailing guide");
        LRAssert(ABS(collapsedTrailing.x - deleteTrailing.x) < 0.5,
                 "the Delete transition should grow left from its final trailing edge");
        [deleteButton setExpanded:NO];
        [ruleCell layoutSubtreeIfNeeded];
    }
    if (addButton != nil && deleteButton != nil) {
        NSButton *collapsedButton = [deleteButton valueForKey:@"collapsedButton"];
        NSPoint addCenter = [addButton convertPoint:
            NSMakePoint(NSMidX(addButton.bounds), NSMidY(addButton.bounds))
                                             toView:rules];
        NSPoint deleteCenter = [collapsedButton convertPoint:
            NSMakePoint(NSMidX(collapsedButton.bounds), NSMidY(collapsedButton.bounds))
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

static NSTextField *FindTextFieldWithAccessibilityLabel(NSView *root, NSString *label) {
    if ([root isKindOfClass:NSTextField.class] && [[root accessibilityLabel] isEqualToString:label]) {
        return (NSTextField *)root;
    }
    for (NSView *subview in root.subviews) {
        NSTextField *match = FindTextFieldWithAccessibilityLabel(subview, label);
        if (match != nil) { return match; }
    }
    return nil;
}

static CGFloat CapTopFromTopOfView(NSTextField *field, NSView *root) {
    NSRect frame = [field convertRect:field.bounds toView:root];
    CGFloat frameTop = NSHeight(root.bounds) - NSMaxY(frame);
    return frameTop + field.firstBaselineOffsetFromTop - field.font.capHeight;
}

static void TestDetailTitleStartsLevelWithRulesHeader(void) {
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
    NSTableCellView *groupCell = [rules viewAtColumn:0 row:0 makeIfNecessary:YES];
    [editor.view layoutSubtreeIfNeeded];
    NSTextField *title = FindTextFieldWithAccessibilityLabel(editor.view, @"Rule name");
    LRAssert(groupCell.textField != nil && title != nil,
             "the Rules header and the rule title should both be present");
    if (groupCell.textField == nil || title == nil) { return; }
    CGFloat delta = CapTopFromTopOfView(title, editor.view)
        - CapTopFromTopOfView(groupCell.textField, editor.view);
    LRAssert(ABS(delta) < 1.0,
             "the rule title's letters should start level with the Rules header in the sidebar");
}

static void TestUntouchedNewRuleDeletesWithoutConfirmation(void) {
    LRRulesEditorViewController *editor = [[LRRulesEditorViewController alloc]
        initWithConfiguration:LRRouterConfiguration.defaultConfiguration
         configurationChanged:^{}];
    NSUInteger originalRuleCount = editor.currentConfiguration.rules.count;

    [editor addRule:nil];
    LRAssert(editor.currentConfiguration.rules.count == originalRuleCount + 1,
             "the Rules plus should append and select a new rule");

    [editor removeRule:nil];
    LRAssert(editor.currentConfiguration.rules.count == originalRuleCount,
             "an untouched new rule should delete immediately without confirmation");

    [editor addRule:nil];
    NSSegmentedControl *mode = [NSSegmentedControl
        segmentedControlWithLabels:@[@"Exact", @"Subdomains"]
                      trackingMode:NSSegmentSwitchTrackingSelectOne
                            target:nil
                            action:nil];
    mode.tag = 0;
    mode.selectedSegment = 1;
    [editor domainModeChanged:mode];
    [editor removeRule:nil];
    LRAssert(editor.currentConfiguration.rules.count == originalRuleCount + 1,
             "editing a new rule should restore the normal removal confirmation");
}

static void TestCollapsedMinusClicksRemoveRepeatedNewRules(void) {
    LRRulesEditorViewController *editor = [[LRRulesEditorViewController alloc]
        initWithConfiguration:LRRouterConfiguration.defaultConfiguration
         configurationChanged:^{}];
    editor.view.frame = NSMakeRect(0.0, 0.0, 820.0, 520.0);
    NSOutlineView *rules = [editor valueForKey:@"sidebarOutlineView"];
    for (NSUInteger index = 0; index < 10; index += 1) {
        [editor addRule:nil];
    }

    for (NSUInteger remaining = 10; remaining > 0; remaining -= 1) {
        [editor.view layoutSubtreeIfNeeded];
        NSInteger row = rules.selectedRow;
        NSTableCellView *ruleCell = [rules viewAtColumn:0 row:row makeIfNecessary:YES];
        [rules layoutSubtreeIfNeeded];
        NSButton *deleteButton = FindButtonWithAccessibilityLabel(ruleCell, @"Delete rule");
        NSButton *collapsedButton = [deleteButton valueForKey:@"collapsedButton"];
        NSPoint minusCenter = [collapsedButton convertPoint:
            NSMakePoint(NSMidX(collapsedButton.bounds), NSMidY(collapsedButton.bounds))
                                                     toView:rules.superview];
        NSView *hitView = [rules hitTest:minusCenter];
        LRAssert(hitView == deleteButton,
                 "the collapsed minus should be clickable before Delete expands");
        if (hitView == deleteButton) { [deleteButton performClick:nil]; }
        LRAssert(editor.currentConfiguration.rules.count == remaining - 1,
                 "every click on the minus should remove exactly one untouched new rule");
    }
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

static void TestLocalFilesOpenInTheFallbackBrowser(void) {
    LRAppDelegate *delegate = [[LRAppDelegate alloc] init];
    LRRecordingBrowserLauncher *launcher = [[LRRecordingBrowserLauncher alloc] init];
    LRRecordingAlertPresenter *presenter = [[LRRecordingAlertPresenter alloc] init];
    [delegate setValue:launcher forKey:@"browserLauncher"];
    [delegate setValue:presenter forKey:@"alertPresenter"];

    NSMenu *menu = [delegate buildMenu];
    NSURL *fileURL = [NSURL fileURLWithPath:@"/tmp/explainer.html"];
    [delegate routeURL:fileURL];

    LRAssert([launcher.openedURL isEqual:fileURL],
             "double-clicking a local file should reach the browser launcher");
    LRAssert(launcher.openedTarget.application == LRBrowserApplicationSafari,
             "a local file should open in the fallback browser");
    LRAssert(presenter.presentCount == 0, "opening a local file should not raise an alert");
    LRAssert([menu.itemArray.firstObject.title containsString:@"Fallback"],
             "the status menu should report the fallback route");
}

static void TestUnroutableURLsRaiseAVisibleAlert(void) {
    LRAppDelegate *delegate = [[LRAppDelegate alloc] init];
    LRRecordingBrowserLauncher *launcher = [[LRRecordingBrowserLauncher alloc] init];
    LRRecordingAlertPresenter *presenter = [[LRRecordingAlertPresenter alloc] init];
    [delegate setValue:launcher forKey:@"browserLauncher"];
    [delegate setValue:presenter forKey:@"alertPresenter"];

    NSMenu *menu = [delegate buildMenu];
    [delegate routeURL:[NSURL URLWithString:@"ftp://example.com/file"]];

    LRAssert(launcher.openedURL == nil, "an unroutable URL should never reach the launcher");
    LRAssert(presenter.presentCount == 1,
             "an agent app must surface a rejection instead of dying silently");
    LRAssert([presenter.presentedMessage containsString:@"ftp"],
             "the alert should name the scheme that was rejected");
    LRAssert([menu.itemArray.firstObject.title containsString:@"Rejected URL"],
             "the status menu should still record the rejection");
}

static void TestLaunchFailureRaisesAVisibleAlert(void) {
    LRAppDelegate *delegate = [[LRAppDelegate alloc] init];
    LRRecordingBrowserLauncher *launcher = [[LRRecordingBrowserLauncher alloc] init];
    LRRecordingAlertPresenter *presenter = [[LRRecordingAlertPresenter alloc] init];
    launcher.launchError = [NSError errorWithDomain:@"LRLaunchTests"
                                               code:1
                                           userInfo:@{NSLocalizedDescriptionKey: @"Safari is not installed."}];
    [delegate setValue:launcher forKey:@"browserLauncher"];
    [delegate setValue:presenter forKey:@"alertPresenter"];

    NSMenu *menu = [delegate buildMenu];
    [delegate routeURL:[NSURL fileURLWithPath:@"/tmp/explainer.html"]];

    LRAssert(presenter.presentCount == 1, "a failed launch should raise exactly one alert");
    LRAssert([presenter.presentedMessage containsString:@"Safari is not installed."],
             "the alert should carry the launch error");
    LRAssert([menu.itemArray.firstObject.title containsString:@"Open failed"],
             "the status menu should record the launch failure");
}

static void TestDeferredLaunchFailureRaisesAVisibleAlert(void) {
    LRAppDelegate *delegate = [[LRAppDelegate alloc] init];
    LRRecordingBrowserLauncher *launcher = [[LRRecordingBrowserLauncher alloc] init];
    LRRecordingAlertPresenter *presenter = [[LRRecordingAlertPresenter alloc] init];
    launcher.deferCompletion = YES;
    launcher.launchError = [NSError errorWithDomain:@"LRLaunchTests"
                                               code:1
                                           userInfo:@{NSLocalizedDescriptionKey: @"Chrome is not installed."}];
    [delegate setValue:launcher forKey:@"browserLauncher"];
    [delegate setValue:presenter forKey:@"alertPresenter"];

    [delegate application:nil openURLs:@[[NSURL URLWithString:@"https://example.com"]]];
    LRAssert(presenter.presentCount == 0, "an outstanding launch should not alert yet");

    [launcher flushDeferredCompletions];
    LRAssert(presenter.presentCount == 1,
             "a launch failing after the batch returns should still alert");
    LRAssert([presenter.presentedMessage containsString:@"Chrome is not installed."],
             "the deferred alert should carry the launch error");
}

static void TestABadURLDoesNotBlockTheRestOfTheBatch(void) {
    LRAppDelegate *delegate = [[LRAppDelegate alloc] init];
    LRRecordingBrowserLauncher *launcher = [[LRRecordingBrowserLauncher alloc] init];
    LRRecordingAlertPresenter *presenter = [[LRRecordingAlertPresenter alloc] init];
    [delegate setValue:launcher forKey:@"browserLauncher"];
    [delegate setValue:presenter forKey:@"alertPresenter"];

    NSURL *good = [NSURL URLWithString:@"https://example.com"];
    [delegate application:nil
                 openURLs:@[[NSURL URLWithString:@"ftp://example.com/file"], good]];

    LRAssert([launcher.openedURL isEqual:good],
             "a rejected URL must not stop the next URL in the batch from opening");
    LRAssert(presenter.presentCount == 1,
             "a batch should raise its alert once, after every URL is dispatched");
}

static void TestBatchFailuresCoalesceIntoOneAlert(void) {
    LRAppDelegate *delegate = [[LRAppDelegate alloc] init];
    LRRecordingBrowserLauncher *launcher = [[LRRecordingBrowserLauncher alloc] init];
    LRRecordingAlertPresenter *presenter = [[LRRecordingAlertPresenter alloc] init];
    [delegate setValue:launcher forKey:@"browserLauncher"];
    [delegate setValue:presenter forKey:@"alertPresenter"];

    [delegate application:nil
                 openURLs:@[[NSURL URLWithString:@"ftp://example.com/one"],
                            [NSURL URLWithString:@"mailto:someone@example.com"]]];

    LRAssert(presenter.presentCount == 1, "two failures in one batch should raise one alert");
    LRAssert([presenter.presentedMessage containsString:@"ftp"] &&
                 [presenter.presentedMessage containsString:@"mailto"],
             "the coalesced alert should name every failure in the batch");
    LRAssert([presenter.presentedTitle containsString:@"2 links"],
             "the coalesced alert should count the failures");
}

int main(void) {
    @autoreleasepool {
        TestEditorUsesNativeLiquidGlassControls();
        TestNativeSettingsSaveValidatedConfiguration();
        TestSidebarUsesInlineRuleManagement();
        TestFallbackBrowserControlUsesOneRow();
        TestDetailTitleStartsLevelWithRulesHeader();
        TestUntouchedNewRuleDeletesWithoutConfirmation();
        TestCollapsedMinusClicksRemoveRepeatedNewRules();
        TestSubdomainModeDisplaysTheWildcardPrefix();
        TestStatusMenuActionsHaveExplicitTargets();
        TestStartAtLoginMenuReflectsAndChangesSystemState();
        TestStartAtLoginApprovalOpensSystemSettings();
        TestStartAtLoginFailureIsVisible();
        TestLocalFilesOpenInTheFallbackBrowser();
        TestUnroutableURLsRaiseAVisibleAlert();
        TestLaunchFailureRaisesAVisibleAlert();
        TestDeferredLaunchFailureRaisesAVisibleAlert();
        TestABadURLDoesNotBlockTheRestOfTheBatch();
        TestBatchFailuresCoalesceIntoOneAlert();
        return LRFinishTests();
    }
}

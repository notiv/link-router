#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

#import "LRAppDelegate.h"
#import "LRConfigStore.h"
#import "LRConfigWindowController.h"
#import "LRLoginItemController.h"
#import "LRRouting.h"
#import "LRTestSupport.h"

@interface LRAppDelegate (Testing)
- (NSMenu *)buildMenu;
- (void)menuNeedsUpdate:(NSMenu *)menu;
- (void)toggleStartAtLogin:(id)sender;
@end

@interface LRConfigWindowController (Testing)
- (void)saveConfigurationDictionary:(NSDictionary *)dictionary;
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

static void TestSettingsHTMLContainsTheReferenceComposition(void) {
    NSString *HTML = [NSString stringWithContentsOfFile:@"Resources/Settings.html"
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    LRAssert([HTML containsString:@"class=\"sidebar\""],
             "the settings UI should provide the reference-style sidebar");
    LRAssert([HTML containsString:@"Unmatched links"],
             "the settings UI should make unmatched links a first-class item");
    LRAssert([HTML containsString:@"Local files"],
             "the settings UI should explain local-file routing");
    LRAssert([HTML containsString:@"Subdomains too"],
             "the settings UI should expose the reference domain-mode control");
    LRAssert([HTML containsString:@"Private window"],
             "the settings UI should expose private Chrome windows");
    LRAssert([HTML containsString:@"-webkit-appearance: none"],
             "custom HTML controls should not inherit gray browser button chrome");
    LRAssert([HTML containsString:@"class=\"traffic-lights\""],
             "the title bar should use reference-aligned window controls");
    LRAssert([HTML containsString:@"--control-height: 32px"],
             "editor controls should share a readable 32-pixel height");
    LRAssert([HTML containsString:@"overflow: auto; padding: 12px 8px 4px;"],
             "the first sidebar rule should sit twelve pixels below the title bar");
    LRAssert([HTML containsString:@".text-input:focus-visible { outline: 0; }"],
             "text fields should rely on the shell focus ring instead of drawing a second outline");
    LRAssert([HTML containsString:@"pendingRuleRemoval"],
             "rule removal should require an explicit pending confirmation state");
    LRAssert([HTML containsString:@"confirm-remove"],
             "rule removal should expose a separate confirmation action");
    LRAssert([HTML containsString:@"Remove?"],
             "the destructive confirmation should be clearly labeled");
}

static void TestEditorUsesTheHTMLSettingsSurface(void) {
    NSURL *configURL = [NSURL fileURLWithPath:[NSTemporaryDirectory()
        stringByAppendingPathComponent:@"LinkRouter-Web-Surface.json"]];
    LRConfigStore *store = [[LRConfigStore alloc] initWithConfigURL:configURL];
    LRConfigWindowController *controller = [[LRConfigWindowController alloc]
        initWithConfigStore:store configurationSaved:^(LRRouterConfiguration *configuration) {
            (void)configuration;
        }];
    WKWebView *webView = [controller valueForKey:@"webView"];

    LRAssert([webView isKindOfClass:WKWebView.class],
             "the editor should render the reference design as HTML and CSS");
    LRAssert((controller.window.styleMask & NSWindowStyleMaskFullSizeContentView) != 0,
             "the HTML settings surface should extend through the reference-style title bar");
    LRAssert([controller.window standardWindowButton:NSWindowCloseButton].hidden,
             "native traffic lights should be hidden behind the reference-aligned HTML controls");
    LRAssert([controller valueForKey:@"titlebarDragView"] != nil,
             "the HTML title bar should have a native window-drag region");
    LRAssert([[webView accessibilityLabel] isEqualToString:@"LinkRouter settings"],
             "the settings surface should have a useful accessibility label");
}

static void TestHTMLSettingsSaveValidatedConfiguration(void) {
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
    NSDictionary *document = @{
        @"default": @{
            @"app": @"Google Chrome",
            @"profile": @"Profile 2",
            @"private": @YES,
        },
        @"rules": @[
            @{
                @"name": @"Work",
                @"hosts": @[@"*.example.com"],
                @"app": @"Safari",
            },
        ],
    };
    [controller saveConfigurationDictionary:document];

    LRRouterConfiguration *reloaded = [store loadConfiguration:&error];
    LRAssert(savedConfiguration != nil, "saving from HTML should update live app state");
    LRAssert(reloaded.defaultTarget.application == LRBrowserApplicationChrome,
             "the HTML editor should save its fallback browser");
    LRAssert([reloaded.defaultTarget.profile isEqualToString:@"Profile 2"],
             "the HTML editor should save the Chrome profile");
    LRAssert(reloaded.defaultTarget.privateBrowsing,
             "the HTML editor should save private browsing");
    LRAssert([reloaded.rules.firstObject.hosts.firstObject isEqualToString:@"*.example.com"],
             "the HTML editor should preserve subdomain matching");
    [NSFileManager.defaultManager removeItemAtURL:directory error:nil];
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
    LRAssert(actionCount == 6, "the status menu should expose six commands");
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
        TestSettingsHTMLContainsTheReferenceComposition();
        TestEditorUsesTheHTMLSettingsSurface();
        TestHTMLSettingsSaveValidatedConfiguration();
        TestStatusMenuActionsHaveExplicitTargets();
        TestStartAtLoginMenuReflectsAndChangesSystemState();
        TestStartAtLoginApprovalOpensSystemSettings();
        TestStartAtLoginFailureIsVisible();
        return LRFinishTests();
    }
}

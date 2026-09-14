#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

#import "LRAppDelegate.h"
#import "LRConfigStore.h"
#import "LRConfigWindowController.h"
#import "LRRouting.h"
#import "LRTestSupport.h"

@interface LRAppDelegate (Testing)
- (NSMenu *)buildMenu;
@end

@interface LRConfigWindowController (Testing)
- (void)saveConfigurationDictionary:(NSDictionary *)dictionary;
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
    LRAssert(actionCount == 5, "the status menu should expose five commands");
}

int main(void) {
    @autoreleasepool {
        TestSettingsHTMLContainsTheReferenceComposition();
        TestEditorUsesTheHTMLSettingsSurface();
        TestHTMLSettingsSaveValidatedConfiguration();
        TestStatusMenuActionsHaveExplicitTargets();
        return LRFinishTests();
    }
}

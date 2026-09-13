#import "LRAppDelegate.h"

#import "LRBrowserLauncher.h"
#import "LRConfigStore.h"
#import "LRConfigWindowController.h"
#import "LRRouting.h"

@interface LRAppDelegate ()
@property(nonatomic, strong) LRConfigStore *configStore;
@property(nonatomic, strong) LRRouterConfiguration *configuration;
@property(nonatomic, strong) LRRouter *router;
@property(nonatomic, strong) id<LRBrowserLaunching> browserLauncher;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *statusMenuItem;
@property(nonatomic, strong) LRConfigWindowController *configWindowController;
@end

@implementation LRAppDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        _configStore = [[LRConfigStore alloc] initWithConfigURL:LRConfigStore.defaultConfigURL];
        _browserLauncher = [[LRBrowserLauncher alloc] init];
        _configuration = LRRouterConfiguration.defaultConfiguration;
        _router = [[LRRouter alloc] initWithConfiguration:_configuration error:nil];
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [self buildStatusMenu];
    [self loadConfiguration];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
    (void)sender;
    return YES;
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)sender {
    (void)sender;
    [self openRuleEditor:nil];
    return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender
                    hasVisibleWindows:(BOOL)hasVisibleWindows {
    (void)sender;
    (void)hasVisibleWindows;
    [self openRuleEditor:nil];
    return NO;
}

- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)URLs {
    (void)application;
    for (NSURL *URL in URLs) {
        [self routeURL:URL];
    }
}

- (void)buildStatusMenu {
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
    NSStatusBarButton *button = self.statusItem.button;
    button.image = [NSImage imageWithSystemSymbolName:@"arrow.triangle.branch"
                            accessibilityDescription:@"LinkRouter"];
    button.toolTip = @"LinkRouter";

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"LinkRouter"];
    self.statusMenuItem = [[NSMenuItem alloc] initWithTitle:@"Loading configuration…"
                                                    action:nil
                                             keyEquivalent:@""];
    self.statusMenuItem.enabled = NO;
    [menu addItem:self.statusMenuItem];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *defaultBrowserItem = [menu addItemWithTitle:@"Set as Default Browser…"
                                                     action:@selector(setAsDefaultBrowser:)
                                              keyEquivalent:@""];
    defaultBrowserItem.target = self;
    NSMenuItem *configureItem = [menu addItemWithTitle:@"Configure Rules…"
                                                action:@selector(openRuleEditor:)
                                         keyEquivalent:@","];
    configureItem.target = self;
    NSMenuItem *openConfigItem = [menu addItemWithTitle:@"Open Config File…"
                                                 action:@selector(openConfigFile:)
                                          keyEquivalent:@""];
    openConfigItem.target = self;
    NSMenuItem *reloadItem = [menu addItemWithTitle:@"Reload Config"
                                             action:@selector(reloadConfig:)
                                      keyEquivalent:@"r"];
    reloadItem.target = self;
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quitItem = [menu addItemWithTitle:@"Quit LinkRouter"
                                           action:@selector(quit:)
                                    keyEquivalent:@"q"];
    quitItem.target = self;
    self.statusItem.menu = menu;
}

- (void)loadConfiguration {
    NSError *error = nil;
    if (![self.configStore ensureDefaultConfigExists:&error]) {
        [self setStatus:[@"Config error: " stringByAppendingString:error.localizedDescription]];
        return;
    }
    LRRouterConfiguration *configuration = [self.configStore loadConfiguration:&error];
    LRRouter *router = configuration == nil ? nil : [[LRRouter alloc] initWithConfiguration:configuration
                                                                                error:&error];
    if (router == nil) {
        self.configuration = LRRouterConfiguration.defaultConfiguration;
        self.router = [[LRRouter alloc] initWithConfiguration:self.configuration error:nil];
        [self setStatus:[@"Invalid config; using Safari: "
                            stringByAppendingString:error.localizedDescription]];
        return;
    }
    self.configuration = configuration;
    self.router = router;
    NSString *summary = [NSString stringWithFormat:@"Ready — %lu rule%@",
                                                    (unsigned long)configuration.rules.count,
                                                    configuration.rules.count == 1 ? @"" : @"s"];
    [self setStatus:summary];
}

- (void)routeURL:(NSURL *)URL {
    NSError *error = nil;
    LRRouteResult *route = [self.router routeForURL:URL error:&error];
    if (route == nil) {
        [self setStatus:[@"Rejected URL: " stringByAppendingString:error.localizedDescription]];
        return;
    }
    NSString *source = route.ruleName ?: @"Fallback";
    [self.browserLauncher openURL:URL
                           target:route.target
                       completion:^(NSError *launchError) {
                           if (launchError != nil) {
                               [self setStatus:[@"Open failed: "
                                                   stringByAppendingString:launchError.localizedDescription]];
                               return;
                           }
                           [self setStatus:[NSString stringWithFormat:@"%@ → %@", source,
                                                                       route.target.displayName]];
                       }];
}

- (void)setAsDefaultBrowser:(id)sender {
    (void)sender;
    NSURL *applicationURL = NSBundle.mainBundle.bundleURL;
    if (![applicationURL.pathExtension.lowercaseString isEqualToString:@"app"]) {
        [self setStatus:@"Launch the packaged LinkRouter.app before setting the default."];
        return;
    }
    [self setStatus:@"Requesting default-browser access…"];
    [NSWorkspace.sharedWorkspace setDefaultApplicationAtURL:applicationURL
                                      toOpenURLsWithScheme:@"http"
                                               completionHandler:^(NSError *HTTPError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (HTTPError != nil) {
                [self setStatus:[@"Default-browser error: "
                                    stringByAppendingString:HTTPError.localizedDescription]];
                return;
            }
            [NSWorkspace.sharedWorkspace setDefaultApplicationAtURL:applicationURL
                                              toOpenURLsWithScheme:@"https"
                                                       completionHandler:^(NSError *HTTPSError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (HTTPSError != nil) {
                        [self setStatus:[@"Default-browser error: "
                                            stringByAppendingString:HTTPSError.localizedDescription]];
                    } else {
                        [self setStatus:@"LinkRouter is the default web browser."];
                    }
                });
            }];
        });
    }];
}

- (void)openConfigFile:(id)sender {
    (void)sender;
    NSError *error = nil;
    if (![self.configStore ensureDefaultConfigExists:&error]) {
        [self setStatus:[@"Config error: " stringByAppendingString:error.localizedDescription]];
        return;
    }
    if (![NSWorkspace.sharedWorkspace openURL:self.configStore.configURL]) {
        [self setStatus:@"Could not open the config file."];
    }
}

- (void)openRuleEditor:(id)sender {
    (void)sender;
    if (self.configWindowController == nil) {
        __weak typeof(self) weakSelf = self;
        self.configWindowController = [[LRConfigWindowController alloc]
            initWithConfigStore:self.configStore
             configurationSaved:^(LRRouterConfiguration *configuration) {
                 NSError *error = nil;
                 LRRouter *router = [[LRRouter alloc] initWithConfiguration:configuration error:&error];
                 if (router == nil) {
                     [weakSelf setStatus:[@"Config error: "
                                             stringByAppendingString:error.localizedDescription]];
                     return;
                 }
                 weakSelf.configuration = configuration;
                 weakSelf.router = router;
                 [weakSelf setStatus:[NSString stringWithFormat:@"Saved — %lu rule%@",
                                                                 (unsigned long)configuration.rules.count,
                                                                 configuration.rules.count == 1 ? @"" : @"s"]];
             }];
    }
    [self.configWindowController showEditor];
}

- (void)reloadConfig:(id)sender {
    (void)sender;
    [self loadConfiguration];
}

- (void)quit:(id)sender {
    (void)sender;
    [NSApplication.sharedApplication terminate:nil];
}

- (void)setStatus:(NSString *)status {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setStatus:status];
        });
        return;
    }
    self.statusMenuItem.title = status;
    self.statusItem.button.toolTip = [@"LinkRouter — " stringByAppendingString:status];
}

@end

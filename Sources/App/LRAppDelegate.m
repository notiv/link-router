#import "LRAppDelegate.h"

#import "LRAlertPresenter.h"
#import "LRBrowserLauncher.h"
#import "LRConfigStore.h"
#import "LRConfigWindowController.h"
#import "LRIconFactory.h"
#import "LRLoginItemController.h"
#import "LRRouting.h"

#import <CoreServices/CoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface LRAppDelegate () <NSMenuDelegate>
@property(nonatomic, strong) LRConfigStore *configStore;
@property(nonatomic, strong) LRRouterConfiguration *configuration;
@property(nonatomic, strong) LRRouter *router;
@property(nonatomic, strong) id<LRBrowserLaunching> browserLauncher;
@property(nonatomic, strong) id<LRAlertPresenting> alertPresenter;
@property(nonatomic, strong) NSMutableArray<NSString *> *pendingFailures;
@property(nonatomic) NSUInteger outstandingRoutes;
@property(nonatomic) BOOL deliveringBatch;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *statusMenuItem;
@property(nonatomic, strong) NSMenuItem *startAtLoginMenuItem;
@property(nonatomic, strong) id<LRLoginItemControlling> loginItemController;
@property(nonatomic, strong) LRConfigWindowController *configWindowController;
- (NSMenu *)buildMenu;
- (void)requestDefaultApplicationAtURL:(NSURL *)applicationURL
                         forURLSchemes:(NSArray<NSString *> *)schemes
                                 index:(NSUInteger)index
                            completion:(void (^)(NSError *error))completion;
@end

@implementation LRAppDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        _configStore = [[LRConfigStore alloc] initWithConfigURL:LRConfigStore.defaultConfigURL];
        _browserLauncher = [[LRBrowserLauncher alloc] init];
        _alertPresenter = [[LRAlertPresenter alloc] init];
        _pendingFailures = [NSMutableArray array];
        _loginItemController = [[LRLoginItemController alloc] init];
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
    return [self shouldOpenRuleEditorForAppleEvent:
        NSAppleEventManager.sharedAppleEventManager.currentAppleEvent];
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)sender {
    (void)sender;
    if (![self shouldOpenRuleEditorForAppleEvent:
            NSAppleEventManager.sharedAppleEventManager.currentAppleEvent]) {
        return YES;
    }
    [self openRuleEditor:nil];
    return YES;
}

- (BOOL)shouldOpenRuleEditorForAppleEvent:(NSAppleEventDescriptor *)event {
    if (event.eventID != kAEOpenApplication) { return YES; }
    AEKeyword launchReason = [[event paramDescriptorForKeyword:keyAEPropData] enumCodeValue];
    return launchReason != keyAELaunchedAsLogInItem &&
           launchReason != keyAELaunchedAsServiceItem;
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
    // Hold failures until every URL in the batch has been dispatched, so one bad
    // link never blocks the rest behind a modal alert.
    self.deliveringBatch = YES;
    for (NSURL *URL in URLs) {
        [self routeURL:URL];
    }
    self.deliveringBatch = NO;
    [self presentPendingFailuresIfIdle];
}

- (void)buildStatusMenu {
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
    NSStatusBarButton *button = self.statusItem.button;
    button.image = [LRIconFactory menuBarIcon];
    button.toolTip = @"LinkRouter";
    self.statusItem.menu = [self buildMenu];
}

- (NSMenu *)buildMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"LinkRouter"];
    menu.delegate = self;
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
    self.startAtLoginMenuItem = [menu addItemWithTitle:@"Start at Login"
                                               action:@selector(toggleStartAtLogin:)
                                        keyEquivalent:@""];
    self.startAtLoginMenuItem.target = self;
    [self updateStartAtLoginMenuItem];
    NSMenuItem *configureItem = [menu addItemWithTitle:@"Configure Rules…"
                                                action:@selector(openRuleEditor:)
                                         keyEquivalent:@","];
    configureItem.target = self;
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quitItem = [menu addItemWithTitle:@"Quit LinkRouter"
                                           action:@selector(quit:)
                                    keyEquivalent:@"q"];
    quitItem.target = self;
    return menu;
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    (void)menu;
    [self updateStartAtLoginMenuItem];
}

- (void)updateStartAtLoginMenuItem {
    LRLoginItemState state = self.loginItemController.state;
    self.startAtLoginMenuItem.title = @"Start at Login";
    self.startAtLoginMenuItem.state = NSControlStateValueOff;
    if (state == LRLoginItemStateEnabled) {
        self.startAtLoginMenuItem.state = NSControlStateValueOn;
    } else if (state == LRLoginItemStateRequiresApproval) {
        self.startAtLoginMenuItem.title = @"Start at Login (Approval Required)…";
        self.startAtLoginMenuItem.state = NSControlStateValueMixed;
    }
}

- (void)toggleStartAtLogin:(id)sender {
    (void)sender;
    LRLoginItemState state = self.loginItemController.state;
    if (state == LRLoginItemStateRequiresApproval) {
        [self.loginItemController openSystemSettings];
        [self setStatus:@"Approve LinkRouter in System Settings → Login Items."];
        [self updateStartAtLoginMenuItem];
        return;
    }

    BOOL enable = state != LRLoginItemStateEnabled;
    NSError *error = nil;
    if (![self.loginItemController setEnabled:enable error:&error]) {
        [self setStatus:[@"Login-item error: "
                            stringByAppendingString:error.localizedDescription ?: @"Unknown error"]];
        [self updateStartAtLoginMenuItem];
        return;
    }

    [self updateStartAtLoginMenuItem];
    if (self.loginItemController.state == LRLoginItemStateRequiresApproval) {
        [self.loginItemController openSystemSettings];
        [self setStatus:@"Approve LinkRouter in System Settings → Login Items."];
    } else {
        [self setStatus:enable ? @"LinkRouter will start at login."
                               : @"LinkRouter will not start at login."];
    }
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

- (void)recordFailure:(NSString *)summary message:(NSString *)message {
    [self setStatus:[summary stringByAppendingString:message]];
    [self.pendingFailures addObject:message];
}

- (void)presentPendingFailuresIfIdle {
    if (self.deliveringBatch || self.outstandingRoutes > 0 || self.pendingFailures.count == 0) {
        return;
    }
    NSArray<NSString *> *failures = [self.pendingFailures copy];
    [self.pendingFailures removeAllObjects];
    NSString *title = failures.count == 1
        ? @"LinkRouter could not open this link"
        : [NSString stringWithFormat:@"LinkRouter could not open %lu links",
                                     (unsigned long)failures.count];
    [self.alertPresenter presentFailureWithTitle:title
                                         message:[failures componentsJoinedByString:@"\n"]];
}

- (void)routeURL:(NSURL *)URL {
    NSError *error = nil;
    LRRouteResult *route = [self.router routeForURL:URL error:&error];
    if (route == nil) {
        [self recordFailure:@"Rejected URL: " message:error.localizedDescription];
        [self presentPendingFailuresIfIdle];
        return;
    }
    NSString *source = route.ruleName ?: @"Fallback";
    self.outstandingRoutes += 1;
    [self.browserLauncher openURL:URL
                           target:route.target
                       completion:^(NSError *launchError) {
                           self.outstandingRoutes -= 1;
                           if (launchError != nil) {
                               [self recordFailure:@"Open failed: "
                                           message:launchError.localizedDescription];
                           } else {
                               [self setStatus:[NSString stringWithFormat:@"%@ → %@", source,
                                                                           route.target.displayName]];
                           }
                           [self presentPendingFailuresIfIdle];
                       }];
}

- (void)requestDefaultApplicationAtURL:(NSURL *)applicationURL
                         forURLSchemes:(NSArray<NSString *> *)schemes
                                 index:(NSUInteger)index
                            completion:(void (^)(NSError *error))completion {
    if (index >= schemes.count) {
        completion(nil);
        return;
    }
    [NSWorkspace.sharedWorkspace setDefaultApplicationAtURL:applicationURL
                                      toOpenURLsWithScheme:schemes[index]
                                               completionHandler:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error != nil) {
                completion(error);
                return;
            }
            [self requestDefaultApplicationAtURL:applicationURL
                                   forURLSchemes:schemes
                                           index:index + 1
                                      completion:completion];
        });
    }];
}

// Becoming the default browser makes macOS hand LinkRouter the public.html
// content type as well, so Finder would send it every double-clicked .html file.
// LinkRouter routes links, not documents: give HTML straight back to the browser
// unmatched links go to, so the OS stops routing documents through an agent app.
- (void)handHTMLDocumentsToTarget:(LRBrowserTarget *)target
                  contentTypeIndex:(NSUInteger)index
                        completion:(void (^)(NSError *error))completion {
    NSArray<NSString *> *identifiers = @[@"public.html", @"public.xhtml"];
    if (index >= identifiers.count) {
        completion(nil);
        return;
    }
    UTType *contentType = [UTType typeWithIdentifier:identifiers[index]];
    NSURL *browserURL = [NSWorkspace.sharedWorkspace
        URLForApplicationWithBundleIdentifier:[LRLaunchPlan bundleIdentifierForTarget:target]];
    if (contentType == nil || browserURL == nil) {
        [self handHTMLDocumentsToTarget:target
                       contentTypeIndex:index + 1
                             completion:completion];
        return;
    }
    [NSWorkspace.sharedWorkspace setDefaultApplicationAtURL:browserURL
                                          toOpenContentType:contentType
                                          completionHandler:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error != nil) {
                completion(error);
                return;
            }
            [self handHTMLDocumentsToTarget:target
                           contentTypeIndex:index + 1
                                 completion:completion];
        });
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
    LRBrowserTarget *fallback = self.configuration.defaultTarget;
    [self requestDefaultApplicationAtURL:applicationURL
                           forURLSchemes:@[@"http", @"https"]
                                   index:0
                              completion:^(NSError *schemeError) {
        if (schemeError != nil) {
            [self setStatus:[@"Default-handler error: "
                                stringByAppendingString:schemeError.localizedDescription]];
            return;
        }
        [self handHTMLDocumentsToTarget:fallback
                       contentTypeIndex:0
                             completion:^(NSError *documentError) {
            if (documentError != nil) {
                [self setStatus:[@"HTML files still open in LinkRouter: "
                                    stringByAppendingString:documentError.localizedDescription]];
                return;
            }
            [self setStatus:[NSString stringWithFormat:@"LinkRouter handles web links; HTML files open in %@.",
                                                       fallback.displayName]];
        }];
    }];
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

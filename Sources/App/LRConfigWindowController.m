#import "LRConfigWindowController.h"

#import <WebKit/WebKit.h>

#import "LRConfigStore.h"
#import "LRRouting.h"

static NSString *const LRSettingsMessageHandler = @"linkRouter";

@interface LRTitlebarDragView : NSView
@end

@implementation LRTitlebarDragView

- (void)mouseDown:(NSEvent *)event {
    [self.window performWindowDragWithEvent:event];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    (void)event;
    return YES;
}

@end

@interface LRWeakScriptMessageHandler : NSObject <WKScriptMessageHandler>
@property(nonatomic, weak) id<WKScriptMessageHandler> target;
- (instancetype)initWithTarget:(id<WKScriptMessageHandler>)target;
@end

@implementation LRWeakScriptMessageHandler

- (instancetype)initWithTarget:(id<WKScriptMessageHandler>)target {
    self = [super init];
    if (self) { _target = target; }
    return self;
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    [self.target userContentController:userContentController didReceiveScriptMessage:message];
}

@end

@interface LRConfigWindowController () <WKNavigationDelegate, WKScriptMessageHandler>
@property(nonatomic, strong) LRConfigStore *configStore;
@property(nonatomic, copy) LRConfigurationSavedHandler configurationSaved;
@property(nonatomic, strong) WKWebView *webView;
@property(nonatomic, strong) LRWeakScriptMessageHandler *weakMessageHandler;
@property(nonatomic, strong) LRRouterConfiguration *pendingConfiguration;
@property(nonatomic, strong) NSURL *settingsURL;
@property(nonatomic, strong) LRTitlebarDragView *titlebarDragView;
@property(nonatomic, copy) NSString *pendingStatusMessage;
@property(nonatomic) BOOL pendingStatusIsError;
@property(nonatomic) BOOL webViewReady;
@end

@implementation LRConfigWindowController

- (instancetype)initWithConfigStore:(LRConfigStore *)configStore
               configurationSaved:(LRConfigurationSavedHandler)configurationSaved {
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 800, 520)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                            NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable |
                            NSWindowStyleMaskFullSizeContentView
                    backing:NSBackingStoreBuffered
                      defer:NO];
    window.title = @"LinkRouter";
    window.titleVisibility = NSWindowTitleHidden;
    window.titlebarAppearsTransparent = YES;
    window.movableByWindowBackground = YES;
    window.minSize = NSMakeSize(720, 470);
    window.releasedWhenClosed = NO;
    [window standardWindowButton:NSWindowCloseButton].hidden = YES;
    [window standardWindowButton:NSWindowMiniaturizeButton].hidden = YES;
    [window standardWindowButton:NSWindowZoomButton].hidden = YES;

    self = [super initWithWindow:window];
    if (self) {
        _configStore = configStore;
        _configurationSaved = [configurationSaved copy];
        [self buildContent];
    }
    return self;
}

- (void)dealloc {
    self.webView.navigationDelegate = nil;
    [self.webView.configuration.userContentController
        removeScriptMessageHandlerForName:LRSettingsMessageHandler];
}

- (void)buildContent {
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
    self.weakMessageHandler = [[LRWeakScriptMessageHandler alloc] initWithTarget:self];
    [configuration.userContentController addScriptMessageHandler:self.weakMessageHandler
                                                            name:LRSettingsMessageHandler];

    self.webView = [[WKWebView alloc] initWithFrame:NSZeroRect configuration:configuration];
    self.webView.navigationDelegate = self;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.webView setAccessibilityLabel:@"LinkRouter settings"];
    [self.window.contentView addSubview:self.webView];
    self.titlebarDragView = [[LRTitlebarDragView alloc] initWithFrame:NSZeroRect];
    self.titlebarDragView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.titlebarDragView setAccessibilityElement:NO];
    [self.window.contentView addSubview:self.titlebarDragView];
    [NSLayoutConstraint activateConstraints:@[
        [self.webView.topAnchor constraintEqualToAnchor:self.window.contentView.topAnchor],
        [self.webView.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:self.window.contentView.bottomAnchor],
        [self.titlebarDragView.topAnchor constraintEqualToAnchor:self.window.contentView.topAnchor],
        [self.titlebarDragView.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor constant:72],
        [self.titlebarDragView.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor],
        [self.titlebarDragView.heightAnchor constraintEqualToConstant:38],
    ]];

    self.settingsURL = [NSBundle.mainBundle URLForResource:@"Settings"
                                             withExtension:@"html"];
    if (self.settingsURL == nil) {
        NSString *developmentPath = [NSFileManager.defaultManager.currentDirectoryPath
            stringByAppendingPathComponent:@"Resources/Settings.html"];
        self.settingsURL = [NSURL fileURLWithPath:developmentPath];
    }
    if ([NSFileManager.defaultManager fileExistsAtPath:self.settingsURL.path]) {
        [self.webView loadFileURL:self.settingsURL
          allowingReadAccessToURL:self.settingsURL.URLByDeletingLastPathComponent];
    } else {
        [self.webView loadHTMLString:@"<p>LinkRouter settings could not be loaded.</p>" baseURL:nil];
    }
}

- (void)showEditor {
    [self reload:nil];
    [self.window center];
    [self showWindow:nil];
    [NSApplication.sharedApplication activateIgnoringOtherApps:YES];
}

- (void)reload:(id)sender {
    (void)sender;
    NSError *error = nil;
    LRRouterConfiguration *configuration = [self.configStore loadConfiguration:&error];
    if (configuration == nil) {
        [self showWebStatus:[@"Error: " stringByAppendingString:error.localizedDescription ?: @"Unknown error"]
                       error:YES];
        return;
    }
    self.pendingConfiguration = configuration;
    [self sendPendingConfigurationIfReady];
}

- (void)openJSON:(id)sender {
    (void)sender;
    if (![NSWorkspace.sharedWorkspace openURL:self.configStore.configURL]) {
        [self showWebStatus:@"Error: The config file could not be opened." error:YES];
    }
}

- (void)saveConfigurationDictionary:(NSDictionary *)dictionary {
    if (![NSJSONSerialization isValidJSONObject:dictionary]) {
        [self showWebStatus:@"Error: The settings contain invalid values." error:YES];
        return;
    }
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
    LRRouterConfiguration *configuration = data == nil
        ? nil
        : [LRRouterConfiguration configurationFromData:data error:&error];
    if (configuration == nil || ![self.configStore saveConfiguration:configuration error:&error]) {
        [self showWebStatus:[@"Error: " stringByAppendingString:error.localizedDescription ?: @"Unknown error"]
                       error:YES];
        return;
    }
    self.pendingConfiguration = configuration;
    [self showWebStatus:@"Saved" error:NO];
    self.configurationSaved(configuration);
}

- (void)sendPendingConfigurationIfReady {
    if (!self.webViewReady || self.pendingConfiguration == nil) { return; }
    NSError *error = nil;
    NSData *data = [self.pendingConfiguration JSONDataWithError:&error];
    if (data == nil) {
        [self showWebStatus:[@"Error: " stringByAppendingString:error.localizedDescription ?: @"Unknown error"]
                       error:YES];
        return;
    }
    NSString *base64 = [data base64EncodedStringWithOptions:0];
    [self.webView callAsyncJavaScript:@"window.LinkRouter.setConfigurationFromBase64(configuration)"
                            arguments:@{ @"configuration": base64 }
                              inFrame:nil
                       inContentWorld:WKContentWorld.pageWorld
                    completionHandler:^(id result, NSError *evaluationError) {
                        (void)result;
                        if (evaluationError != nil) {
                            [self showWebStatus:@"Error: The settings interface could not be updated."
                                           error:YES];
                        }
                    }];
}

- (void)showWebStatus:(NSString *)message error:(BOOL)isError {
    if (!self.webViewReady) {
        self.pendingStatusMessage = message;
        self.pendingStatusIsError = isError;
        return;
    }
    [self.webView callAsyncJavaScript:@"window.LinkRouter.setStatus(message, isError)"
                            arguments:@{ @"message": message ?: @"", @"isError": @(isError) }
                              inFrame:nil
                       inContentWorld:WKContentWorld.pageWorld
                    completionHandler:nil];
    self.pendingStatusMessage = nil;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    (void)webView;
    (void)navigation;
    self.webViewReady = YES;
    [self sendPendingConfigurationIfReady];
    [self sendPendingStatusIfReady];
}

- (void)sendPendingStatusIfReady {
    if (self.webViewReady && self.pendingStatusMessage != nil) {
        [self showWebStatus:self.pendingStatusMessage error:self.pendingStatusIsError];
    }
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                   decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    (void)webView;
    NSURL *URL = navigationAction.request.URL;
    BOOL isSettingsFile = [URL.scheme.lowercaseString isEqualToString:@"file"] &&
                          [URL.path isEqualToString:self.settingsURL.path];
    BOOL isEmptyDocument = [URL.scheme.lowercaseString isEqualToString:@"about"];
    decisionHandler(isSettingsFile || isEmptyDocument
                        ? WKNavigationActionPolicyAllow
                        : WKNavigationActionPolicyCancel);
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    (void)userContentController;
    if (![message.name isEqualToString:LRSettingsMessageHandler] ||
        ![message.body isKindOfClass:NSDictionary.class]) {
        return;
    }
    NSDictionary *body = message.body;
    NSString *action = [body[@"action"] isKindOfClass:NSString.class] ? body[@"action"] : @"";
    if ([action isEqualToString:@"ready"]) {
        self.webViewReady = YES;
        [self sendPendingConfigurationIfReady];
        [self sendPendingStatusIfReady];
    } else if ([action isEqualToString:@"save"] &&
               [body[@"configuration"] isKindOfClass:NSDictionary.class]) {
        [self saveConfigurationDictionary:body[@"configuration"]];
    } else if ([action isEqualToString:@"reload"]) {
        [self reload:nil];
    } else if ([action isEqualToString:@"openJSON"]) {
        [self openJSON:nil];
    } else if ([action isEqualToString:@"window-close"]) {
        [self.window performClose:nil];
    } else if ([action isEqualToString:@"window-minimize"]) {
        [self.window miniaturize:nil];
    } else if ([action isEqualToString:@"window-zoom"]) {
        [self.window zoom:nil];
    }
}

@end

#import "LRConfigWindowController.h"

#import "LRConfigStore.h"
#import "LRRouting.h"
#import "LRRulesEditorViewController.h"

@interface LRConfigWindowController ()
@property(nonatomic, strong) LRConfigStore *configStore;
@property(nonatomic, copy) LRConfigurationSavedHandler configurationSaved;
@property(nonatomic, strong) LRRulesEditorViewController *rulesEditor;
@property(nonatomic, strong) NSView *actionBarContainer;
@property(nonatomic, strong) NSTextField *statusLabel;
@end

@implementation LRConfigWindowController

- (instancetype)initWithConfigStore:(LRConfigStore *)configStore
               configurationSaved:(LRConfigurationSavedHandler)configurationSaved {
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 820, 520)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                            NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable |
                            NSWindowStyleMaskFullSizeContentView
                    backing:NSBackingStoreBuffered
                      defer:NO];
    window.title = @"LinkRouter";
    window.titlebarAppearsTransparent = YES;
    window.minSize = NSMakeSize(740, 480);
    window.releasedWhenClosed = NO;
    window.toolbarStyle = NSWindowToolbarStyleUnified;

    self = [super initWithWindow:window];
    if (self) {
        _configStore = configStore;
        _configurationSaved = [configurationSaved copy];
        [self buildContent];
    }
    return self;
}

- (void)buildContent {
    __weak typeof(self) weakSelf = self;
    self.rulesEditor = [[LRRulesEditorViewController alloc]
        initWithConfiguration:LRRouterConfiguration.defaultConfiguration
         configurationChanged:^{
             [weakSelf showStatus:@"Edited" error:NO];
         }];

    NSViewController *rootController = [[NSViewController alloc] init];
    NSView *root = [[NSView alloc] initWithFrame:NSZeroRect];
    rootController.view = root;
    [rootController addChildViewController:self.rulesEditor];
    self.rulesEditor.view.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:self.rulesEditor.view];

    NSView *actionContent = [self buildActionContent];
    self.actionBarContainer = [self materialContainerForContent:actionContent];
    self.actionBarContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:self.actionBarContainer];

    [NSLayoutConstraint activateConstraints:@[
        [self.rulesEditor.view.topAnchor constraintEqualToAnchor:root.topAnchor],
        [self.rulesEditor.view.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [self.rulesEditor.view.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [self.rulesEditor.view.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [self.actionBarContainer.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-20.0],
        [self.actionBarContainer.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-16.0],
        [self.actionBarContainer.leadingAnchor constraintGreaterThanOrEqualToAnchor:root.leadingAnchor
                                                                    constant:260.0],
    ]];
    self.window.contentViewController = rootController;
}

- (NSView *)buildActionContent {
    self.statusLabel = [NSTextField labelWithString:@"Loading…"];
    self.statusLabel.textColor = NSColor.secondaryLabelColor;
    self.statusLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.statusLabel setAccessibilityLabel:@"Settings status"];
    [self.statusLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                               forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSButton *openJSON = [NSButton buttonWithTitle:@"Open JSON"
                                            target:self
                                            action:@selector(openJSON:)];
    openJSON.toolTip = @"Open the configuration file";
    openJSON.keyEquivalent = @"o";
    openJSON.keyEquivalentModifierMask = NSEventModifierFlagCommand;

    NSButton *reload = [NSButton buttonWithTitle:@"Reload"
                                          target:self
                                          action:@selector(reload:)];
    reload.toolTip = @"Discard edits and reload the saved configuration";
    reload.keyEquivalent = @"r";
    reload.keyEquivalentModifierMask = NSEventModifierFlagCommand;

    NSButton *save = [NSButton buttonWithTitle:@"Save"
                                        target:self
                                        action:@selector(save:)];
    save.keyEquivalent = @"\r";
    save.toolTip = @"Save routing rules";

    NSStackView *actions = [NSStackView stackViewWithViews:@[
        self.statusLabel,
        openJSON,
        reload,
        save,
    ]];
    actions.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    actions.alignment = NSLayoutAttributeCenterY;
    actions.spacing = 8.0;
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    [actions setCustomSpacing:14.0 afterView:self.statusLabel];
    [self.statusLabel.widthAnchor constraintGreaterThanOrEqualToConstant:80.0].active = YES;

    NSView *content = [[NSView alloc] initWithFrame:NSZeroRect];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:actions];
    [NSLayoutConstraint activateConstraints:@[
        [actions.topAnchor constraintEqualToAnchor:content.topAnchor constant:6.0],
        [actions.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:12.0],
        [actions.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-12.0],
        [actions.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-6.0],
    ]];
    return content;
}

- (NSView *)materialContainerForContent:(NSView *)content {
    NSView *container = nil;
    if (@available(macOS 26.0, *)) {
        NSGlassEffectView *glass = [[NSGlassEffectView alloc] initWithFrame:NSZeroRect];
        glass.style = NSGlassEffectViewStyleRegular;
        glass.cornerRadius = 20.0;
        glass.contentView = content;
        container = glass;
    } else {
        NSVisualEffectView *material = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
        material.material = NSVisualEffectMaterialPopover;
        material.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        material.state = NSVisualEffectStateFollowsWindowActiveState;
        material.wantsLayer = YES;
        material.layer.cornerRadius = 12.0;
        [material addSubview:content];
        container = material;
    }
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:container.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
    [container setAccessibilityElement:NO];
    return container;
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
        [self showStatus:error.localizedDescription ?: @"The saved configuration could not be loaded."
                    error:YES];
        return;
    }
    [self.rulesEditor setConfiguration:configuration];
    [self showStatus:@"Loaded" error:NO];
}

- (void)openJSON:(id)sender {
    (void)sender;
    NSError *error = nil;
    if (![self.configStore ensureDefaultConfigExists:&error]) {
        [self showStatus:error.localizedDescription ?: @"The configuration file could not be created."
                    error:YES];
        return;
    }
    if (![NSWorkspace.sharedWorkspace openURL:self.configStore.configURL]) {
        [self showStatus:@"The configuration file could not be opened." error:YES];
    }
}

- (void)save:(id)sender {
    (void)sender;
    [self saveConfiguration:self.rulesEditor.currentConfiguration];
}

- (void)saveConfiguration:(LRRouterConfiguration *)configuration {
    NSError *error = nil;
    if (![self.configStore saveConfiguration:configuration error:&error]) {
        [self showStatus:error.localizedDescription ?: @"The configuration could not be saved."
                    error:YES];
        NSBeep();
        return;
    }
    [self showStatus:@"Saved" error:NO];
    if (self.configurationSaved != nil) { self.configurationSaved(configuration); }
}

- (void)showStatus:(NSString *)message error:(BOOL)isError {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showStatus:message error:isError];
        });
        return;
    }
    self.statusLabel.stringValue = message;
    self.statusLabel.textColor = isError ? NSColor.systemRedColor : NSColor.secondaryLabelColor;
    self.statusLabel.toolTip = message;
    [self.statusLabel setAccessibilityValue:message];
}

@end

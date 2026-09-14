#import "LRConfigWindowController.h"

#import "LRConfigStore.h"
#import "LRRouting.h"
#import "LRRuleTableController.h"

@interface LRConfigWindowController ()
@property(nonatomic, strong) LRConfigStore *configStore;
@property(nonatomic, copy) LRConfigurationSavedHandler configurationSaved;
@property(nonatomic, strong) LRRuleTableController *ruleTableController;
@property(nonatomic, strong) NSTextField *orderLabel;
@property(nonatomic, strong) NSTextField *statusLabel;
@end

@implementation LRConfigWindowController

- (instancetype)initWithConfigStore:(LRConfigStore *)configStore
               configurationSaved:(LRConfigurationSavedHandler)configurationSaved {
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 800, 520)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                            NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    window.title = @"LinkRouter";
    window.minSize = NSMakeSize(720, 470);
    window.releasedWhenClosed = NO;
    self = [super initWithWindow:window];
    if (self) {
        _configStore = configStore;
        _configurationSaved = [configurationSaved copy];
        [self buildContent];
    }
    return self;
}

- (void)buildContent {
    self.ruleTableController = [[LRRuleTableController alloc] init];
    NSView *rulesView = self.ruleTableController.view;
    __weak typeof(self) weakSelf = self;
    self.ruleTableController.changeHandler = ^{
        [weakSelf configurationEdited];
    };

    self.orderLabel = [NSTextField labelWithString:@"0 rules · first match from the top wins"];
    self.orderLabel.font = [NSFont systemFontOfSize:11.5];
    self.orderLabel.textColor = NSColor.secondaryLabelColor;
    self.statusLabel = [NSTextField labelWithString:@""];
    self.statusLabel.font = [NSFont systemFontOfSize:11.5];
    self.statusLabel.textColor = NSColor.tertiaryLabelColor;
    NSButton *openJSON = [NSButton buttonWithTitle:@"Open JSON"
                                           target:self
                                           action:@selector(openJSON:)];
    NSButton *reload = [NSButton buttonWithTitle:@"Reload"
                                         target:self
                                         action:@selector(reload:)];
    NSButton *save = [NSButton buttonWithTitle:@"Save"
                                       target:self
                                       action:@selector(save:)];
    save.keyEquivalent = @"\r";
    save.bezelStyle = NSBezelStyleRounded;
    for (NSButton *button in @[openJSON, reload, save]) {
        button.controlSize = NSControlSizeSmall;
    }
    NSStackView *footer = [NSStackView stackViewWithViews:@[
        self.orderLabel, self.statusLabel, openJSON, reload, save
    ]];
    footer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    footer.alignment = NSLayoutAttributeCenterY;
    footer.spacing = 8;
    footer.edgeInsets = NSEdgeInsetsMake(6, 14, 6, 14);
    [self.orderLabel setContentHuggingPriority:NSLayoutPriorityDefaultLow
                                forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self.statusLabel setContentHuggingPriority:NSLayoutPriorityDefaultHigh
                                 forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSBox *footerDivider = [[NSBox alloc] initWithFrame:NSZeroRect];
    footerDivider.boxType = NSBoxSeparator;
    for (NSView *view in @[rulesView, footerDivider, footer]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [self.window.contentView addSubview:view];
    }
    [NSLayoutConstraint activateConstraints:@[
        [rulesView.topAnchor constraintEqualToAnchor:self.window.contentView.topAnchor],
        [rulesView.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor],
        [rulesView.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor],
        [rulesView.bottomAnchor constraintEqualToAnchor:footerDivider.topAnchor],
        [footerDivider.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor],
        [footerDivider.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor],
        [footer.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor],
        [footer.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor],
        [footer.topAnchor constraintEqualToAnchor:footerDivider.bottomAnchor],
        [footer.bottomAnchor constraintEqualToAnchor:self.window.contentView.bottomAnchor],
        [footer.heightAnchor constraintEqualToConstant:38],
    ]];
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
        [self showError:error.localizedDescription];
        return;
    }
    [self.ruleTableController setDefaultTarget:configuration.defaultTarget];
    [self.ruleTableController setRoutingRules:configuration.rules];
    [self updateOrderLabel:configuration.rules.count];
    [self showStatus:@"Loaded"];
}

- (void)save:(id)sender {
    (void)sender;
    LRRouterConfiguration *configuration = [[LRRouterConfiguration alloc]
        initWithDefaultTarget:self.ruleTableController.defaultTarget
                         rules:self.ruleTableController.routingRules];
    NSError *error = nil;
    if (![self.configStore saveConfiguration:configuration error:&error]) {
        [self showError:error.localizedDescription];
        return;
    }
    [self updateOrderLabel:configuration.rules.count];
    [self showStatus:@"Saved"];
    self.configurationSaved(configuration);
}

- (void)openJSON:(id)sender {
    (void)sender;
    if (![NSWorkspace.sharedWorkspace openURL:self.configStore.configURL]) {
        [self showError:@"The config file could not be opened."];
    }
}

- (void)configurationEdited {
    [self updateOrderLabel:self.ruleTableController.ruleCount];
    [self showStatus:@"Edited"];
}

- (void)updateOrderLabel:(NSUInteger)ruleCount {
    self.orderLabel.stringValue = [NSString stringWithFormat:@"%lu rule%@ · first match from the top wins",
                                                             (unsigned long)ruleCount,
                                                             ruleCount == 1 ? @"" : @"s"];
}

- (void)updateStatusLabel:(NSString *)message color:(NSColor *)color {
    self.statusLabel.textColor = color;
    self.statusLabel.stringValue = message;
    NSAccessibilityPostNotification(self.statusLabel, NSAccessibilityValueChangedNotification);
}

- (void)showError:(NSString *)message {
    [self updateStatusLabel:[@"Error: " stringByAppendingString:message ?: @"Unknown error"]
                      color:NSColor.systemRedColor];
}

- (void)showStatus:(NSString *)message {
    [self updateStatusLabel:message color:NSColor.secondaryLabelColor];
}

@end

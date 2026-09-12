#import "LRConfigWindowController.h"

#import "LRConfigStore.h"
#import "LRRouting.h"
#import "LRRuleTableController.h"

@interface LRConfigWindowController ()
@property(nonatomic, strong) LRConfigStore *configStore;
@property(nonatomic, copy) LRConfigurationSavedHandler configurationSaved;
@property(nonatomic, strong) NSPopUpButton *defaultBrowserPicker;
@property(nonatomic, strong) NSTextField *defaultProfileField;
@property(nonatomic, strong) LRRuleTableController *ruleTableController;
@property(nonatomic, strong) NSTextField *statusLabel;
@end

@implementation LRConfigWindowController

- (instancetype)initWithConfigStore:(LRConfigStore *)configStore
               configurationSaved:(LRConfigurationSavedHandler)configurationSaved {
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 760, 510)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                            NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    window.title = @"LinkRouter Rules";
    window.minSize = NSMakeSize(680, 430);
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
    NSStackView *root = [[NSStackView alloc] initWithFrame:NSZeroRect];
    root.orientation = NSUserInterfaceLayoutOrientationVertical;
    root.alignment = NSLayoutAttributeLeading;
    root.spacing = 16;
    root.edgeInsets = NSEdgeInsetsMake(20, 20, 20, 20);

    NSTextField *title = [NSTextField labelWithString:@"Link routing"];
    title.font = [NSFont preferredFontForTextStyle:NSFontTextStyleTitle1 options:@{}];
    NSTextField *subtitle = [NSTextField wrappingLabelWithString:
        @"Choose a fallback, then add rules for the sites that belong in a specific browser or Chrome profile."];
    subtitle.textColor = NSColor.secondaryLabelColor;

    NSTextField *defaultLabel = [NSTextField labelWithString:@"Fallback browser"];
    defaultLabel.font = [NSFont systemFontOfSize:NSFont.systemFontSize weight:NSFontWeightSemibold];
    self.defaultBrowserPicker = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.defaultBrowserPicker addItemsWithTitles:@[@"Safari", @"Google Chrome"]];
    self.defaultBrowserPicker.target = self;
    self.defaultBrowserPicker.action = @selector(defaultBrowserChanged:);
    [self.defaultBrowserPicker setAccessibilityLabel:@"Fallback browser"];
    self.defaultProfileField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    self.defaultProfileField.placeholderString = @"Chrome profile: Default or Profile 1";
    [self.defaultProfileField setAccessibilityLabel:@"Fallback Chrome profile"];
    [self.defaultProfileField.widthAnchor constraintGreaterThanOrEqualToConstant:230].active = YES;
    NSStackView *fallback = [NSStackView stackViewWithViews:@[
        defaultLabel, self.defaultBrowserPicker, self.defaultProfileField
    ]];
    fallback.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    fallback.alignment = NSLayoutAttributeCenterY;
    fallback.spacing = 12;

    self.ruleTableController = [[LRRuleTableController alloc] init];
    NSView *rulesView = self.ruleTableController.view;

    self.statusLabel = [NSTextField wrappingLabelWithString:@""];
    self.statusLabel.textColor = NSColor.secondaryLabelColor;
    [self.statusLabel setContentHuggingPriority:NSLayoutPriorityDefaultLow
                                forOrientation:NSLayoutConstraintOrientationHorizontal];
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
    NSStackView *footer = [NSStackView stackViewWithViews:@[
        self.statusLabel, openJSON, reload, save
    ]];
    footer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    footer.alignment = NSLayoutAttributeCenterY;
    footer.spacing = 8;

    for (NSView *view in @[title, subtitle, fallback, rulesView, footer]) {
        [root addArrangedSubview:view];
        [view.widthAnchor constraintEqualToAnchor:root.widthAnchor constant:-40].active = YES;
    }
    [rulesView setContentHuggingPriority:NSLayoutPriorityDefaultLow
                          forOrientation:NSLayoutConstraintOrientationVertical];
    [rulesView setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                        forOrientation:NSLayoutConstraintOrientationVertical];
    root.translatesAutoresizingMaskIntoConstraints = NO;
    [self.window.contentView addSubview:root];
    [NSLayoutConstraint activateConstraints:@[
        [root.topAnchor constraintEqualToAnchor:self.window.contentView.topAnchor],
        [root.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor],
        [root.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor],
        [root.bottomAnchor constraintEqualToAnchor:self.window.contentView.bottomAnchor],
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
    [self.defaultBrowserPicker selectItemAtIndex:(NSInteger)configuration.defaultTarget.application];
    self.defaultProfileField.stringValue = configuration.defaultTarget.profile ?: @"";
    [self.ruleTableController setRoutingRules:configuration.rules];
    [self updateDefaultProfileAvailability];
    [self showStatus:[NSString stringWithFormat:@"Loaded %lu rule%@.",
                                               (unsigned long)configuration.rules.count,
                                               configuration.rules.count == 1 ? @"" : @"s"]];
}

- (void)save:(id)sender {
    (void)sender;
    [self.ruleTableController commitEditing];
    LRBrowserApplication application =
        (LRBrowserApplication)self.defaultBrowserPicker.indexOfSelectedItem;
    LRBrowserTarget *fallback = [LRBrowserTarget targetWithApplication:application
                                                               profile:application == LRBrowserApplicationChrome
                                                                           ? self.defaultProfileField.stringValue
                                                                           : nil];
    LRRouterConfiguration *configuration = [[LRRouterConfiguration alloc]
        initWithDefaultTarget:fallback
                         rules:self.ruleTableController.routingRules];
    NSError *error = nil;
    if (![self.configStore saveConfiguration:configuration error:&error]) {
        [self showError:error.localizedDescription];
        return;
    }
    [self showStatus:@"Saved. New links use these rules immediately."];
    self.configurationSaved(configuration);
}

- (void)openJSON:(id)sender {
    (void)sender;
    if (![NSWorkspace.sharedWorkspace openURL:self.configStore.configURL]) {
        [self showError:@"The config file could not be opened."];
    }
}

- (void)defaultBrowserChanged:(id)sender {
    (void)sender;
    [self updateDefaultProfileAvailability];
}

- (void)updateDefaultProfileAvailability {
    self.defaultProfileField.enabled =
        self.defaultBrowserPicker.indexOfSelectedItem == LRBrowserApplicationChrome;
}

- (void)showError:(NSString *)message {
    self.statusLabel.textColor = NSColor.systemRedColor;
    self.statusLabel.stringValue = [@"Error: " stringByAppendingString:message ?: @"Unknown error"];
}

- (void)showStatus:(NSString *)message {
    self.statusLabel.textColor = NSColor.secondaryLabelColor;
    self.statusLabel.stringValue = message;
}

@end

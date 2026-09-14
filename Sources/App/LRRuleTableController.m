#import "LRRuleTableController.h"

#import "LRRuleDraft.h"

static NSString *const LRRuleColumn = @"rule";
static NSString *const LRRuleNameField = @"rule-name";
static NSString *const LRDomainField = @"domain";
static NSString *const LRProfileField = @"profile";

typedef NS_ENUM(NSInteger, LRSpecialSelection) {
    LRSpecialSelectionNone = -1,
    LRSpecialSelectionFallback = 0,
    LRSpecialSelectionLocalFiles = 1,
};

@interface LRRuleTableController () <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>
@property(nonatomic, strong) NSTableView *tableView;
@property(nonatomic, strong) NSMutableArray<LRRuleDraft *> *drafts;
@property(nonatomic, strong) NSStackView *detailStack;
@property(nonatomic, strong) NSMutableArray<NSString *> *domainPatterns;
@property(nonatomic, strong) NSMutableArray<NSTextField *> *domainFields;
@property(nonatomic, strong) NSMutableArray<NSSegmentedControl *> *domainModeControls;
@property(nonatomic, strong) NSTextField *nameField;
@property(nonatomic, strong) NSTextField *profileField;
@property(nonatomic, strong) NSSegmentedControl *browserControl;
@property(nonatomic, strong) NSButton *privateButton;
@property(nonatomic, strong) NSButton *removeButton;
@property(nonatomic, strong) NSButton *moveUpButton;
@property(nonatomic, strong) NSButton *moveDownButton;
@property(nonatomic, strong) NSButton *fallbackButton;
@property(nonatomic, strong) NSButton *localFilesButton;
@property(nonatomic, strong) LRBrowserTarget *fallbackTarget;
@property(nonatomic) LRSpecialSelection specialSelection;
@property(nonatomic, strong) NSTextField *detailDescriptionLabel;
@end

@implementation LRRuleTableController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _drafts = [NSMutableArray array];
        _fallbackTarget = [LRBrowserTarget targetWithApplication:LRBrowserApplicationSafari
                                                         profile:nil];
        _specialSelection = LRSpecialSelectionFallback;
    }
    return self;
}

- (void)loadView {
    NSView *container = [[NSView alloc] initWithFrame:NSZeroRect];

    NSVisualEffectView *sidebar = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    sidebar.material = NSVisualEffectMaterialSidebar;
    sidebar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    sidebar.state = NSVisualEffectStateActive;

    NSTextField *rulesLabel = [self sectionLabelWithString:@"Rules"];
    self.tableView = [[NSTableView alloc] initWithFrame:NSZeroRect];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.headerView = nil;
    self.tableView.backgroundColor = NSColor.clearColor;
    self.tableView.rowHeight = 32;
    self.tableView.intercellSpacing = NSMakeSize(0, 1);
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.style = NSTableViewStyleSourceList;
    [self.tableView setAccessibilityLabel:@"Routing rules in priority order"];
    NSTableColumn *ruleColumn = [[NSTableColumn alloc] initWithIdentifier:LRRuleColumn];
    ruleColumn.resizingMask = NSTableColumnAutoresizingMask;
    [self.tableView addTableColumn:ruleColumn];

    NSScrollView *ruleScrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    ruleScrollView.documentView = self.tableView;
    ruleScrollView.drawsBackground = NO;
    ruleScrollView.hasVerticalScroller = YES;
    ruleScrollView.borderType = NSNoBorder;

    NSButton *addButton = [NSButton buttonWithTitle:@"+  Add rule"
                                            target:self
                                            action:@selector(addRule:)];
    addButton.bezelStyle = NSBezelStyleInline;
    addButton.alignment = NSTextAlignmentLeft;
    addButton.font = [NSFont systemFontOfSize:12.5 weight:NSFontWeightRegular];
    [addButton setAccessibilityLabel:@"Add rule"];

    self.removeButton = [self sidebarActionButton:@"−"
                                accessibilityLabel:@"Remove selected rule"
                                             action:@selector(removeRule:)];
    self.moveUpButton = [self sidebarActionButton:@"↑"
                                accessibilityLabel:@"Move selected rule up"
                                             action:@selector(moveRuleUp:)];
    self.moveDownButton = [self sidebarActionButton:@"↓"
                                  accessibilityLabel:@"Move selected rule down"
                                               action:@selector(moveRuleDown:)];
    NSStackView *actions = [NSStackView stackViewWithViews:@[
        self.removeButton, self.moveUpButton, self.moveDownButton
    ]];
    actions.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    actions.spacing = 4;

    NSView *sidebarFooter = [[NSView alloc] initWithFrame:NSZeroRect];
    for (NSView *view in @[addButton, actions]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [sidebarFooter addSubview:view];
    }
    [NSLayoutConstraint activateConstraints:@[
        [addButton.leadingAnchor constraintEqualToAnchor:sidebarFooter.leadingAnchor constant:8],
        [addButton.centerYAnchor constraintEqualToAnchor:sidebarFooter.centerYAnchor],
        [actions.trailingAnchor constraintEqualToAnchor:sidebarFooter.trailingAnchor constant:-8],
        [actions.centerYAnchor constraintEqualToAnchor:sidebarFooter.centerYAnchor],
        [addButton.trailingAnchor constraintLessThanOrEqualToAnchor:actions.leadingAnchor constant:-4],
        [sidebarFooter.heightAnchor constraintEqualToConstant:38],
    ]];

    NSView *specialSection = [[NSView alloc] initWithFrame:NSZeroRect];
    NSBox *specialDivider = [[NSBox alloc] initWithFrame:NSZeroRect];
    specialDivider.boxType = NSBoxSeparator;
    NSTextField *everythingElseLabel = [self sectionLabelWithString:@"Everything else"];
    self.fallbackButton = [self specialButtonWithTitle:@"Unmatched links"
                                                 action:@selector(selectFallback:)];
    self.localFilesButton = [self specialButtonWithTitle:@"Local files"
                                                   action:@selector(selectLocalFiles:)];
    for (NSView *view in @[
             specialDivider, everythingElseLabel, self.fallbackButton, self.localFilesButton
         ]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [specialSection addSubview:view];
    }
    [NSLayoutConstraint activateConstraints:@[
        [specialDivider.topAnchor constraintEqualToAnchor:specialSection.topAnchor],
        [specialDivider.leadingAnchor constraintEqualToAnchor:specialSection.leadingAnchor],
        [specialDivider.trailingAnchor constraintEqualToAnchor:specialSection.trailingAnchor],
        [everythingElseLabel.topAnchor constraintEqualToAnchor:specialDivider.bottomAnchor constant:8],
        [everythingElseLabel.leadingAnchor constraintEqualToAnchor:specialSection.leadingAnchor constant:16],
        [everythingElseLabel.trailingAnchor constraintEqualToAnchor:specialSection.trailingAnchor constant:-12],
        [self.fallbackButton.topAnchor constraintEqualToAnchor:everythingElseLabel.bottomAnchor constant:4],
        [self.fallbackButton.leadingAnchor constraintEqualToAnchor:specialSection.leadingAnchor constant:7],
        [self.fallbackButton.trailingAnchor constraintEqualToAnchor:specialSection.trailingAnchor constant:-7],
        [self.localFilesButton.topAnchor constraintEqualToAnchor:self.fallbackButton.bottomAnchor constant:1],
        [self.localFilesButton.leadingAnchor constraintEqualToAnchor:self.fallbackButton.leadingAnchor],
        [self.localFilesButton.trailingAnchor constraintEqualToAnchor:self.fallbackButton.trailingAnchor],
        [self.localFilesButton.bottomAnchor constraintEqualToAnchor:specialSection.bottomAnchor constant:-7],
        [self.fallbackButton.heightAnchor constraintEqualToConstant:28],
        [self.localFilesButton.heightAnchor constraintEqualToConstant:28],
    ]];

    for (NSView *view in @[rulesLabel, ruleScrollView, sidebarFooter, specialSection]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [sidebar addSubview:view];
    }
    [NSLayoutConstraint activateConstraints:@[
        [rulesLabel.topAnchor constraintEqualToAnchor:sidebar.topAnchor constant:12],
        [rulesLabel.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:16],
        [rulesLabel.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-12],
        [ruleScrollView.topAnchor constraintEqualToAnchor:rulesLabel.bottomAnchor constant:7],
        [ruleScrollView.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:6],
        [ruleScrollView.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-6],
        [ruleScrollView.bottomAnchor constraintEqualToAnchor:sidebarFooter.topAnchor],
        [sidebarFooter.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor],
        [sidebarFooter.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor],
        [sidebarFooter.bottomAnchor constraintEqualToAnchor:specialSection.topAnchor],
        [specialSection.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor],
        [specialSection.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor],
        [specialSection.bottomAnchor constraintEqualToAnchor:sidebar.bottomAnchor],
        [sidebar.widthAnchor constraintEqualToConstant:214],
    ]];

    NSView *detail = [[NSView alloc] initWithFrame:NSZeroRect];
    self.detailStack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    self.detailStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.detailStack.alignment = NSLayoutAttributeLeading;
    self.detailStack.spacing = 20;
    self.detailStack.translatesAutoresizingMaskIntoConstraints = NO;
    [detail addSubview:self.detailStack];
    [NSLayoutConstraint activateConstraints:@[
        [self.detailStack.topAnchor constraintEqualToAnchor:detail.topAnchor constant:24],
        [self.detailStack.leadingAnchor constraintEqualToAnchor:detail.leadingAnchor constant:26],
        [self.detailStack.trailingAnchor constraintEqualToAnchor:detail.trailingAnchor constant:-26],
        [self.detailStack.bottomAnchor constraintLessThanOrEqualToAnchor:detail.bottomAnchor constant:-24],
    ]];

    NSBox *divider = [[NSBox alloc] initWithFrame:NSZeroRect];
    divider.boxType = NSBoxSeparator;
    for (NSView *view in @[sidebar, divider, detail]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [container addSubview:view];
    }
    [NSLayoutConstraint activateConstraints:@[
        [sidebar.topAnchor constraintEqualToAnchor:container.topAnchor],
        [sidebar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [sidebar.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [divider.topAnchor constraintEqualToAnchor:container.topAnchor],
        [divider.leadingAnchor constraintEqualToAnchor:sidebar.trailingAnchor],
        [divider.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [divider.widthAnchor constraintEqualToConstant:1],
        [detail.topAnchor constraintEqualToAnchor:container.topAnchor],
        [detail.leadingAnchor constraintEqualToAnchor:divider.trailingAnchor],
        [detail.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [detail.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    self.view = container;
    [self updateSelectionState];
    [self updateSpecialButtons];
    [self rebuildDetail];
}

- (NSButton *)sidebarActionButton:(NSString *)title
               accessibilityLabel:(NSString *)accessibilityLabel
                            action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.bezelStyle = NSBezelStyleInline;
    button.font = [NSFont systemFontOfSize:14];
    [button setAccessibilityLabel:accessibilityLabel];
    [button.widthAnchor constraintEqualToConstant:26].active = YES;
    return button;
}

- (NSButton *)specialButtonWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.bezelStyle = NSBezelStyleInline;
    button.alignment = NSTextAlignmentLeft;
    button.font = [NSFont systemFontOfSize:12.5 weight:NSFontWeightSemibold];
    button.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [button setAccessibilityLabel:title];
    return button;
}

- (NSTextField *)sectionLabelWithString:(NSString *)string {
    NSTextField *label = [NSTextField labelWithString:string.uppercaseString];
    label.font = [NSFont systemFontOfSize:10 weight:NSFontWeightBold];
    label.textColor = NSColor.secondaryLabelColor;
    return label;
}

- (void)setRoutingRules:(NSArray<LRRoutingRule *> *)rules {
    (void)self.view;
    self.drafts = [NSMutableArray arrayWithCapacity:rules.count];
    for (LRRoutingRule *rule in rules) {
        [self.drafts addObject:[LRRuleDraft draftFromRule:rule]];
    }
    [self.tableView reloadData];
    if (self.drafts.count > 0) {
        self.specialSelection = LRSpecialSelectionNone;
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
                    byExtendingSelection:NO];
    } else {
        self.specialSelection = LRSpecialSelectionFallback;
        [self.tableView deselectAll:nil];
    }
    [self updateSelectionState];
    [self updateSpecialButtons];
    [self rebuildDetail];
}

- (void)setDefaultTarget:(LRBrowserTarget *)target {
    (void)self.view;
    self.fallbackTarget = target;
    [self updateSpecialButtons];
    if (self.specialSelection != LRSpecialSelectionNone) { [self rebuildDetail]; }
}

- (LRBrowserTarget *)defaultTarget {
    [self commitCurrentEditing];
    return self.fallbackTarget;
}

- (NSArray<LRRoutingRule *> *)routingRules {
    [self commitCurrentEditing];
    NSMutableArray<LRRoutingRule *> *rules = [NSMutableArray arrayWithCapacity:self.drafts.count];
    for (LRRuleDraft *draft in self.drafts) {
        [rules addObject:draft.routingRule];
    }
    return rules;
}

- (NSUInteger)ruleCount {
    return self.drafts.count;
}

- (void)commitCurrentEditing {
    [self.view.window makeFirstResponder:nil];
    [self commitDomainPatterns];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return self.drafts.count;
}

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row {
    (void)tableColumn;
    LRRuleDraft *draft = self.drafts[(NSUInteger)row];
    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"rule-cell" owner:self];
    NSTextField *nameLabel = nil;
    NSTextField *destinationLabel = nil;
    if (cell == nil) {
        cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = @"rule-cell";
        nameLabel = [NSTextField labelWithString:@""];
        nameLabel.identifier = @"name";
        nameLabel.font = [NSFont systemFontOfSize:12.5 weight:NSFontWeightSemibold];
        nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        destinationLabel = [NSTextField labelWithString:@""];
        destinationLabel.identifier = @"destination";
        destinationLabel.font = [NSFont systemFontOfSize:11];
        destinationLabel.textColor = NSColor.secondaryLabelColor;
        for (NSView *view in @[nameLabel, destinationLabel]) {
            view.translatesAutoresizingMaskIntoConstraints = NO;
            [cell addSubview:view];
        }
        [nameLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                            forOrientation:NSLayoutConstraintOrientationHorizontal];
        [NSLayoutConstraint activateConstraints:@[
            [nameLabel.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:8],
            [nameLabel.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [destinationLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:nameLabel.trailingAnchor constant:6],
            [destinationLabel.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-8],
            [destinationLabel.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
        ]];
    } else {
        for (NSView *view in cell.subviews) {
            if ([view.identifier isEqualToString:@"name"]) { nameLabel = (NSTextField *)view; }
            if ([view.identifier isEqualToString:@"destination"]) { destinationLabel = (NSTextField *)view; }
        }
    }
    nameLabel.stringValue = draft.name.length > 0 ? draft.name : @"Untitled rule";
    destinationLabel.stringValue = [self destinationSummaryForDraft:draft];
    [cell setAccessibilityLabel:[NSString stringWithFormat:@"%@, opens in %@",
                                                           nameLabel.stringValue,
                                                           destinationLabel.stringValue]];
    return cell;
}

- (NSString *)destinationSummaryForDraft:(LRRuleDraft *)draft {
    if (draft.application == LRBrowserApplicationSafari) { return @"Safari"; }
    return draft.privateBrowsing ? @"Chrome · private" : @"Chrome";
}

- (LRRuleDraft *)selectedDraft {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || (NSUInteger)row >= self.drafts.count) { return nil; }
    return self.drafts[(NSUInteger)row];
}

- (void)rebuildDetail {
    for (NSView *view in self.detailStack.arrangedSubviews.copy) {
        [self.detailStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    self.detailDescriptionLabel = nil;
    self.domainPatterns = nil;
    self.domainFields = nil;
    self.domainModeControls = nil;
    if (self.specialSelection == LRSpecialSelectionFallback) {
        [self rebuildFallbackDetail];
        return;
    }
    if (self.specialSelection == LRSpecialSelectionLocalFiles) {
        [self rebuildLocalFilesDetail];
        return;
    }
    LRRuleDraft *draft = self.selectedDraft;
    if (draft == nil) {
        NSTextField *emptyTitle = [NSTextField labelWithString:@"No rules yet"];
        emptyTitle.font = [NSFont systemFontOfSize:20 weight:NSFontWeightSemibold];
        NSTextField *emptyHelp = [NSTextField wrappingLabelWithString:
            @"Add a rule to send matching domains to a specific browser or Chrome profile."];
        emptyHelp.textColor = NSColor.secondaryLabelColor;
        [self.detailStack addArrangedSubview:emptyTitle];
        [self.detailStack addArrangedSubview:emptyHelp];
        [emptyHelp.widthAnchor constraintEqualToAnchor:self.detailStack.widthAnchor].active = YES;
        return;
    }

    self.nameField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    self.nameField.identifier = LRRuleNameField;
    self.nameField.delegate = self;
    self.nameField.stringValue = draft.name;
    self.nameField.placeholderString = @"Untitled rule";
    self.nameField.font = [NSFont systemFontOfSize:20 weight:NSFontWeightSemibold];
    self.nameField.bezeled = NO;
    self.nameField.drawsBackground = NO;
    [self.nameField setAccessibilityLabel:@"Rule name"];
    [self.detailStack addArrangedSubview:self.nameField];
    [self.nameField.widthAnchor constraintEqualToAnchor:self.detailStack.widthAnchor].active = YES;
    NSBox *titleSeparator = [self separator];
    [self.detailStack addArrangedSubview:titleSeparator];
    [titleSeparator.widthAnchor constraintEqualToAnchor:self.detailStack.widthAnchor].active = YES;

    NSStackView *domainsSection = [[NSStackView alloc] initWithFrame:NSZeroRect];
    domainsSection.orientation = NSUserInterfaceLayoutOrientationVertical;
    domainsSection.alignment = NSLayoutAttributeLeading;
    domainsSection.spacing = 8;
    [domainsSection addArrangedSubview:[self sectionLabelWithString:@"Domains"]];
    self.domainPatterns = [[self domainPatternsForDraft:draft] mutableCopy];
    if (self.domainPatterns.count == 0) { [self.domainPatterns addObject:@""]; }
    self.domainFields = [NSMutableArray array];
    self.domainModeControls = [NSMutableArray array];
    for (NSUInteger index = 0; index < self.domainPatterns.count; index++) {
        NSView *domainRow = [self domainRowAtIndex:index];
        [domainsSection addArrangedSubview:domainRow];
        [domainRow.widthAnchor constraintEqualToAnchor:domainsSection.widthAnchor].active = YES;
    }
    NSButton *addDomain = [NSButton buttonWithTitle:@"+ Add domain"
                                             target:self
                                             action:@selector(addDomain:)];
    addDomain.bezelStyle = NSBezelStyleInline;
    addDomain.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    addDomain.contentTintColor = NSColor.controlAccentColor;
    [domainsSection addArrangedSubview:addDomain];
    [self.detailStack addArrangedSubview:domainsSection];
    [domainsSection.widthAnchor constraintEqualToAnchor:self.detailStack.widthAnchor].active = YES;

    [self addBrowserSectionForApplication:draft.application
                                  profile:draft.profile
                          privateBrowsing:draft.privateBrowsing];
}

- (void)rebuildFallbackDetail {
    [self addDetailHeading:@"Unmatched links"
               description:@"Any http or https link whose host matches no rule above."];
    [self addBrowserSectionForApplication:self.fallbackTarget.application
                                  profile:self.fallbackTarget.profile
                          privateBrowsing:self.fallbackTarget.privateBrowsing];
}

- (void)rebuildLocalFilesDetail {
    [self addDetailHeading:@"Local files"
               description:@"file:// URLs and HTML documents opened from disk always follow Unmatched links."];
    NSStackView *section = [[NSStackView alloc] initWithFrame:NSZeroRect];
    section.orientation = NSUserInterfaceLayoutOrientationVertical;
    section.alignment = NSLayoutAttributeLeading;
    section.spacing = 9;
    [section addArrangedSubview:[self sectionLabelWithString:@"Open in"]];
    NSTextField *summary = [NSTextField labelWithString:
        [NSString stringWithFormat:@"Same as Unmatched links — %@",
                                   [self summaryForTarget:self.fallbackTarget]]];
    summary.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    [section addArrangedSubview:summary];
    NSButton *editFallback = [NSButton buttonWithTitle:@"Edit Unmatched Links"
                                                target:self
                                                action:@selector(selectFallback:)];
    editFallback.bezelStyle = NSBezelStyleInline;
    editFallback.contentTintColor = NSColor.controlAccentColor;
    [section addArrangedSubview:editFallback];
    [self.detailStack addArrangedSubview:section];
}

- (void)addDetailHeading:(NSString *)heading description:(NSString *)description {
    NSTextField *title = [NSTextField labelWithString:heading];
    title.font = [NSFont systemFontOfSize:20 weight:NSFontWeightSemibold];
    self.detailDescriptionLabel = [NSTextField wrappingLabelWithString:description];
    self.detailDescriptionLabel.font = [NSFont systemFontOfSize:12.5];
    self.detailDescriptionLabel.textColor = NSColor.secondaryLabelColor;
    [self.detailStack addArrangedSubview:title];
    [self.detailStack setCustomSpacing:4 afterView:title];
    [self.detailStack addArrangedSubview:self.detailDescriptionLabel];
    [self.detailDescriptionLabel.widthAnchor constraintEqualToAnchor:self.detailStack.widthAnchor].active = YES;
    NSBox *separator = [self separator];
    [self.detailStack addArrangedSubview:separator];
    [separator.widthAnchor constraintEqualToAnchor:self.detailStack.widthAnchor].active = YES;
}

- (void)addBrowserSectionForApplication:(LRBrowserApplication)application
                                 profile:(NSString *)profile
                         privateBrowsing:(BOOL)privateBrowsing {
    NSStackView *browserSection = [[NSStackView alloc] initWithFrame:NSZeroRect];
    browserSection.orientation = NSUserInterfaceLayoutOrientationVertical;
    browserSection.alignment = NSLayoutAttributeLeading;
    browserSection.spacing = 9;
    [browserSection addArrangedSubview:[self sectionLabelWithString:@"Open in"]];
    self.browserControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Safari", @"Google Chrome"]
                                                            trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                  target:self
                                                                  action:@selector(browserChanged:)];
    self.browserControl.selectedSegment = (NSInteger)application;
    self.browserControl.controlSize = NSControlSizeSmall;
    [self.browserControl setAccessibilityLabel:@"Destination browser"];
    [browserSection addArrangedSubview:self.browserControl];
    if (application == LRBrowserApplicationChrome) {
        NSStackView *profileRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
        profileRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        profileRow.alignment = NSLayoutAttributeCenterY;
        profileRow.spacing = 8;
        NSTextField *profileLabel = [NSTextField labelWithString:@"Profile"];
        profileLabel.textColor = NSColor.secondaryLabelColor;
        profileLabel.font = [NSFont systemFontOfSize:12];
        self.profileField = [[NSTextField alloc] initWithFrame:NSZeroRect];
        self.profileField.identifier = LRProfileField;
        self.profileField.delegate = self;
        self.profileField.stringValue = profile ?: @"";
        self.profileField.placeholderString = @"Default";
        self.profileField.font = [NSFont monospacedSystemFontOfSize:12.5 weight:NSFontWeightRegular];
        self.profileField.controlSize = NSControlSizeSmall;
        [self.profileField setAccessibilityLabel:@"Chrome profile directory"];
        [self.profileField.widthAnchor constraintEqualToConstant:180].active = YES;
        [profileRow addArrangedSubview:profileLabel];
        [profileRow addArrangedSubview:self.profileField];
        [browserSection addArrangedSubview:profileRow];
    }
    self.privateButton = [NSButton checkboxWithTitle:@"Private window"
                                              target:self
                                              action:@selector(privateChanged:)];
    self.privateButton.state = privateBrowsing ? NSControlStateValueOn : NSControlStateValueOff;
    self.privateButton.enabled = application == LRBrowserApplicationChrome;
    [self.privateButton setAccessibilityLabel:@"Open in a private Chrome window"];
    [browserSection addArrangedSubview:self.privateButton];
    if (application == LRBrowserApplicationSafari) {
        NSTextField *note = [NSTextField labelWithString:@"Private windows are not available for Safari."];
        note.font = [NSFont systemFontOfSize:11.5];
        note.textColor = NSColor.tertiaryLabelColor;
        [browserSection addArrangedSubview:note];
    }
    [self.detailStack addArrangedSubview:browserSection];
    [browserSection.widthAnchor constraintEqualToAnchor:self.detailStack.widthAnchor].active = YES;
}

- (NSBox *)separator {
    NSBox *separator = [[NSBox alloc] initWithFrame:NSZeroRect];
    separator.boxType = NSBoxSeparator;
    return separator;
}

- (NSArray<NSString *> *)domainPatternsForDraft:(LRRuleDraft *)draft {
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@",\n"];
    NSArray<NSString *> *components = [draft.hostsText componentsSeparatedByCharactersInSet:separators];
    NSMutableArray<NSString *> *patterns = [NSMutableArray array];
    for (NSString *component in components) {
        NSString *pattern = [component stringByTrimmingCharactersInSet:
            NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (pattern.length > 0) { [patterns addObject:pattern]; }
    }
    return patterns;
}

- (NSView *)domainRowAtIndex:(NSUInteger)index {
    NSString *pattern = self.domainPatterns[index];
    BOOL includesSubdomains = [pattern hasPrefix:@"*."];
    NSString *host = includesSubdomains ? [pattern substringFromIndex:2] : pattern;

    NSTextField *field = [[NSTextField alloc] initWithFrame:NSZeroRect];
    field.identifier = LRDomainField;
    field.delegate = self;
    field.tag = (NSInteger)index;
    field.stringValue = host;
    field.placeholderString = @"example.com";
    field.font = [NSFont monospacedSystemFontOfSize:12.5 weight:NSFontWeightRegular];
    field.controlSize = NSControlSizeSmall;
    [field setAccessibilityLabel:[NSString stringWithFormat:@"Domain %lu", (unsigned long)index + 1]];
    [field setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                    forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSSegmentedControl *mode = [NSSegmentedControl segmentedControlWithLabels:@[@"Exact", @"Subdomains too"]
                                                                 trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                       target:self
                                                                       action:@selector(domainModeChanged:)];
    mode.tag = (NSInteger)index;
    mode.selectedSegment = includesSubdomains ? 1 : 0;
    mode.controlSize = NSControlSizeSmall;
    [mode setAccessibilityLabel:[NSString stringWithFormat:@"Matching mode for domain %lu",
                                                          (unsigned long)index + 1]];
    [mode.widthAnchor constraintEqualToConstant:188].active = YES;

    NSButton *remove = [NSButton buttonWithTitle:@"×" target:self action:@selector(removeDomain:)];
    remove.tag = (NSInteger)index;
    remove.bezelStyle = NSBezelStyleInline;
    remove.font = [NSFont systemFontOfSize:13];
    [remove setAccessibilityLabel:[NSString stringWithFormat:@"Remove domain %lu",
                                                            (unsigned long)index + 1]];
    [remove.widthAnchor constraintEqualToConstant:22].active = YES;

    NSStackView *row = [NSStackView stackViewWithViews:@[field, mode, remove]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 10;
    [self.domainFields addObject:field];
    [self.domainModeControls addObject:mode];
    return row;
}

- (void)controlTextDidChange:(NSNotification *)notification {
    NSTextField *field = notification.object;
    if (self.specialSelection == LRSpecialSelectionFallback &&
        [field.identifier isEqualToString:LRProfileField]) {
        self.fallbackTarget = [LRBrowserTarget
            targetWithApplication:LRBrowserApplicationChrome
                           profile:field.stringValue
                   privateBrowsing:self.fallbackTarget.privateBrowsing];
        [self updateSpecialButtons];
        [self notifyChanged];
        return;
    }
    LRRuleDraft *draft = self.selectedDraft;
    if (draft == nil) { return; }
    if ([field.identifier isEqualToString:LRRuleNameField]) {
        draft.name = field.stringValue;
        [self reloadSelectedSidebarRow];
    } else if ([field.identifier isEqualToString:LRProfileField]) {
        draft.profile = field.stringValue;
    } else if ([field.identifier isEqualToString:LRDomainField]) {
        [self commitDomainPatterns];
    }
    [self notifyChanged];
}

- (void)commitDomainPatterns {
    LRRuleDraft *draft = self.selectedDraft;
    if (draft == nil || self.domainFields == nil) { return; }
    for (NSUInteger index = 0; index < self.domainFields.count; index++) {
        NSString *host = [self.domainFields[index].stringValue
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        BOOL subdomains = self.domainModeControls[index].selectedSegment == 1;
        self.domainPatterns[index] = subdomains && host.length > 0
                                         ? [@"*." stringByAppendingString:host]
                                         : host;
    }
    draft.hostsText = [self.domainPatterns componentsJoinedByString:@", "];
}

- (void)domainModeChanged:(NSSegmentedControl *)sender {
    (void)sender;
    [self commitDomainPatterns];
    [self notifyChanged];
}

- (void)addDomain:(id)sender {
    (void)sender;
    [self commitDomainPatterns];
    [self.domainPatterns addObject:@""];
    self.selectedDraft.hostsText = [self.domainPatterns componentsJoinedByString:@", "];
    [self rebuildDetail];
    [self.view.window makeFirstResponder:self.domainFields.lastObject];
    [self notifyChanged];
}

- (void)removeDomain:(NSButton *)sender {
    [self commitDomainPatterns];
    if (sender.tag < 0 || (NSUInteger)sender.tag >= self.domainPatterns.count) { return; }
    if (self.domainPatterns.count == 1) {
        self.domainPatterns[0] = @"";
    } else {
        [self.domainPatterns removeObjectAtIndex:(NSUInteger)sender.tag];
    }
    self.selectedDraft.hostsText = [self.domainPatterns componentsJoinedByString:@", "];
    [self rebuildDetail];
    [self notifyChanged];
}

- (void)browserChanged:(NSSegmentedControl *)sender {
    [self commitCurrentEditing];
    if (self.specialSelection == LRSpecialSelectionFallback) {
        LRBrowserApplication application = (LRBrowserApplication)sender.selectedSegment;
        self.fallbackTarget = [LRBrowserTarget
            targetWithApplication:application
                           profile:application == LRBrowserApplicationChrome
                                       ? self.fallbackTarget.profile
                                       : nil
                   privateBrowsing:application == LRBrowserApplicationChrome &&
                                       self.fallbackTarget.privateBrowsing];
        [self updateSpecialButtons];
        [self rebuildDetail];
        [self notifyChanged];
        return;
    }
    LRRuleDraft *draft = self.selectedDraft;
    if (draft == nil) { return; }
    draft.application = (LRBrowserApplication)sender.selectedSegment;
    if (draft.application != LRBrowserApplicationChrome) { draft.privateBrowsing = NO; }
    [self reloadSelectedSidebarRow];
    [self rebuildDetail];
    [self notifyChanged];
}

- (void)privateChanged:(NSButton *)sender {
    if (self.specialSelection == LRSpecialSelectionFallback) {
        if (self.fallbackTarget.application != LRBrowserApplicationChrome) { return; }
        self.fallbackTarget = [LRBrowserTarget
            targetWithApplication:LRBrowserApplicationChrome
                           profile:self.fallbackTarget.profile
                   privateBrowsing:sender.state == NSControlStateValueOn];
        [self updateSpecialButtons];
        [self notifyChanged];
        return;
    }
    LRRuleDraft *draft = self.selectedDraft;
    if (draft == nil || draft.application != LRBrowserApplicationChrome) { return; }
    draft.privateBrowsing = sender.state == NSControlStateValueOn;
    [self reloadSelectedSidebarRow];
    [self notifyChanged];
}

- (void)addRule:(id)sender {
    (void)sender;
    [self commitCurrentEditing];
    [self.drafts addObject:LRRuleDraft.newDraft];
    [self.tableView reloadData];
    NSInteger row = (NSInteger)self.drafts.count - 1;
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
                byExtendingSelection:NO];
    [self.tableView scrollRowToVisible:row];
    [self rebuildDetail];
    [self.view.window makeFirstResponder:self.nameField];
    [self notifyChanged];
}

- (void)removeRule:(id)sender {
    (void)sender;
    [self commitCurrentEditing];
    NSInteger row = self.tableView.selectedRow;
    if (row < 0) { return; }
    [self.drafts removeObjectAtIndex:(NSUInteger)row];
    [self.tableView reloadData];
    if (self.drafts.count > 0) {
        NSUInteger next = MIN((NSUInteger)row, self.drafts.count - 1);
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:next]
                    byExtendingSelection:NO];
    }
    [self updateSelectionState];
    [self rebuildDetail];
    [self notifyChanged];
}

- (void)moveRuleUp:(id)sender {
    (void)sender;
    [self moveSelectedRuleBy:-1];
}

- (void)moveRuleDown:(id)sender {
    (void)sender;
    [self moveSelectedRuleBy:1];
}

- (void)moveSelectedRuleBy:(NSInteger)offset {
    [self commitCurrentEditing];
    NSInteger source = self.tableView.selectedRow;
    NSInteger destination = source + offset;
    if (source < 0 || destination < 0 || destination >= (NSInteger)self.drafts.count) { return; }
    [self.drafts exchangeObjectAtIndex:(NSUInteger)source withObjectAtIndex:(NSUInteger)destination];
    [self.tableView reloadData];
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)destination]
                byExtendingSelection:NO];
    [self rebuildDetail];
    [self notifyChanged];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    if (self.tableView.selectedRow >= 0) { self.specialSelection = LRSpecialSelectionNone; }
    [self updateSelectionState];
    [self updateSpecialButtons];
    [self rebuildDetail];
}

- (void)selectFallback:(id)sender {
    (void)sender;
    [self commitCurrentEditing];
    self.specialSelection = LRSpecialSelectionFallback;
    [self.tableView deselectAll:nil];
    [self updateSelectionState];
    [self updateSpecialButtons];
    [self rebuildDetail];
}

- (void)selectLocalFiles:(id)sender {
    (void)sender;
    [self commitCurrentEditing];
    self.specialSelection = LRSpecialSelectionLocalFiles;
    [self.tableView deselectAll:nil];
    [self updateSelectionState];
    [self updateSpecialButtons];
    [self rebuildDetail];
}

- (void)reloadSelectedSidebarRow {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0) { return; }
    [self.tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
                             columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (void)updateSelectionState {
    NSInteger row = self.tableView.selectedRow;
    self.removeButton.enabled = row >= 0;
    self.moveUpButton.enabled = row > 0;
    self.moveDownButton.enabled = row >= 0 && row + 1 < (NSInteger)self.drafts.count;
}

- (void)updateSpecialButtons {
    if (self.fallbackButton == nil) { return; }
    self.fallbackButton.title = [NSString stringWithFormat:@"Unmatched links   %@",
                                                           [self shortSummaryForTarget:self.fallbackTarget]];
    self.localFilesButton.title = @"Local files   follows above";
    self.fallbackButton.state = self.specialSelection == LRSpecialSelectionFallback
                                    ? NSControlStateValueOn
                                    : NSControlStateValueOff;
    self.localFilesButton.state = self.specialSelection == LRSpecialSelectionLocalFiles
                                      ? NSControlStateValueOn
                                      : NSControlStateValueOff;
    [self.fallbackButton setAccessibilityLabel:[NSString
        stringWithFormat:@"Unmatched links, opens in %@", [self summaryForTarget:self.fallbackTarget]]];
    [self.localFilesButton setAccessibilityLabel:@"Local files, follows Unmatched links"];
}

- (NSString *)shortSummaryForTarget:(LRBrowserTarget *)target {
    NSString *browser = target.application == LRBrowserApplicationSafari ? @"Safari" : @"Chrome";
    return target.privateBrowsing ? [browser stringByAppendingString:@" · private"] : browser;
}

- (NSString *)summaryForTarget:(LRBrowserTarget *)target {
    if (target.application == LRBrowserApplicationSafari) { return @"Safari"; }
    NSString *profile = target.profile.length > 0 ? target.profile : @"Default";
    return [NSString stringWithFormat:@"Google Chrome · %@%@",
                                      profile,
                                      target.privateBrowsing ? @" · private" : @""];
}

- (void)notifyChanged {
    if (self.changeHandler != nil) { self.changeHandler(); }
}

@end

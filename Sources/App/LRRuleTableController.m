#import "LRRuleTableController.h"

#import "LRRuleDraft.h"

static NSString *const LRNameColumn = @"name";
static NSString *const LRHostsColumn = @"hosts";
static NSString *const LRBrowserColumn = @"browser";
static NSString *const LRProfileColumn = @"profile";

@interface LRRuleTableController () <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>
@property(nonatomic, strong) NSTableView *tableView;
@property(nonatomic, strong) NSMutableArray<LRRuleDraft *> *drafts;
@property(nonatomic, strong) NSButton *removeButton;
@property(nonatomic, strong) NSButton *moveUpButton;
@property(nonatomic, strong) NSButton *moveDownButton;
@end

@implementation LRRuleTableController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _drafts = [NSMutableArray array];
    }
    return self;
}

- (void)loadView {
    NSView *container = [[NSView alloc] initWithFrame:NSZeroRect];
    NSTextField *help = [NSTextField wrappingLabelWithString:
        @"Rules are checked from top to bottom. Separate host patterns with commas or new lines; *.example.com also matches example.com."];
    help.textColor = NSColor.secondaryLabelColor;

    self.tableView = [[NSTableView alloc] initWithFrame:NSZeroRect];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.usesAlternatingRowBackgroundColors = YES;
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.rowHeight = 26;
    [self.tableView setAccessibilityLabel:@"Ordered link routing rules"];
    [self addColumn:LRNameColumn title:@"Name" width:130];
    [self addColumn:LRHostsColumn title:@"Host patterns" width:270];
    [self addColumn:LRBrowserColumn title:@"Browser" width:125];
    [self addColumn:LRProfileColumn title:@"Chrome profile" width:130];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scrollView.documentView = self.tableView;
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSBezelBorder;

    NSButton *addButton = [NSButton buttonWithTitle:@"Add Rule"
                                            target:self
                                            action:@selector(addRule:)];
    self.removeButton = [NSButton buttonWithTitle:@"Remove"
                                           target:self
                                           action:@selector(removeRule:)];
    self.moveUpButton = [NSButton buttonWithTitle:@"Move Up"
                                           target:self
                                           action:@selector(moveRuleUp:)];
    self.moveDownButton = [NSButton buttonWithTitle:@"Move Down"
                                             target:self
                                             action:@selector(moveRuleDown:)];
    NSStackView *buttons = [NSStackView stackViewWithViews:@[
        addButton, self.removeButton, self.moveUpButton, self.moveDownButton
    ]];
    buttons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttons.spacing = 8;

    for (NSView *view in @[help, scrollView, buttons]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [container addSubview:view];
    }
    [NSLayoutConstraint activateConstraints:@[
        [help.topAnchor constraintEqualToAnchor:container.topAnchor],
        [help.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [help.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:help.bottomAnchor constant:8],
        [scrollView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [scrollView.heightAnchor constraintGreaterThanOrEqualToConstant:250],
        [buttons.topAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:8],
        [buttons.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [buttons.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
    self.view = container;
    [self updateButtonState];
}

- (void)addColumn:(NSString *)identifier title:(NSString *)title width:(CGFloat)width {
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:identifier];
    column.title = title;
    column.width = width;
    column.minWidth = 90;
    [self.tableView addTableColumn:column];
}

- (void)setRoutingRules:(NSArray<LRRoutingRule *> *)rules {
    self.drafts = [NSMutableArray arrayWithCapacity:rules.count];
    for (LRRoutingRule *rule in rules) {
        [self.drafts addObject:[LRRuleDraft draftFromRule:rule]];
    }
    [self.tableView reloadData];
    [self updateButtonState];
}

- (NSArray<LRRoutingRule *> *)routingRules {
    [self commitEditing];
    NSMutableArray<LRRoutingRule *> *rules = [NSMutableArray arrayWithCapacity:self.drafts.count];
    for (LRRuleDraft *draft in self.drafts) {
        [rules addObject:draft.routingRule];
    }
    return rules;
}

- (void)commitEditing {
    [self.view.window makeFirstResponder:nil];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return self.drafts.count;
}

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row {
    (void)tableView;
    LRRuleDraft *draft = self.drafts[(NSUInteger)row];
    NSString *identifier = tableColumn.identifier;
    if ([identifier isEqualToString:LRBrowserColumn]) {
        NSPopUpButton *picker = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
        [picker addItemsWithTitles:@[@"Safari", @"Google Chrome"]];
        [picker selectItemAtIndex:(NSInteger)draft.application];
        picker.tag = row;
        picker.target = self;
        picker.action = @selector(browserChanged:);
        [picker setAccessibilityLabel:[NSString stringWithFormat:@"Browser for rule %ld", row + 1]];
        return picker;
    }

    NSTextField *field = [[NSTextField alloc] initWithFrame:NSZeroRect];
    field.delegate = self;
    field.tag = row;
    field.identifier = tableColumn.identifier;
    field.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
    if ([identifier isEqualToString:LRNameColumn]) {
        field.stringValue = draft.name;
        field.placeholderString = @"Work";
        [field setAccessibilityLabel:[NSString stringWithFormat:@"Name for rule %ld", row + 1]];
    } else if ([identifier isEqualToString:LRHostsColumn]) {
        field.stringValue = draft.hostsText;
        field.placeholderString = @"*.example.com, internal.example.org";
        [field setAccessibilityLabel:[NSString stringWithFormat:@"Host patterns for rule %ld", row + 1]];
    } else {
        field.stringValue = draft.profile ?: @"";
        field.placeholderString = @"Default or Profile 1";
        field.enabled = draft.application == LRBrowserApplicationChrome;
        [field setAccessibilityLabel:[NSString stringWithFormat:@"Chrome profile for rule %ld", row + 1]];
    }
    return field;
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSTextField *field = notification.object;
    if (field.tag < 0 || (NSUInteger)field.tag >= self.drafts.count) {
        return;
    }
    LRRuleDraft *draft = self.drafts[(NSUInteger)field.tag];
    NSString *identifier = field.identifier;
    if ([identifier isEqualToString:LRNameColumn]) {
        draft.name = field.stringValue;
    } else if ([identifier isEqualToString:LRHostsColumn]) {
        draft.hostsText = field.stringValue;
    } else if ([identifier isEqualToString:LRProfileColumn]) {
        draft.profile = field.stringValue;
    }
}

- (void)browserChanged:(NSPopUpButton *)sender {
    LRRuleDraft *draft = self.drafts[(NSUInteger)sender.tag];
    draft.application = (LRBrowserApplication)sender.indexOfSelectedItem;
    NSIndexSet *row = [NSIndexSet indexSetWithIndex:(NSUInteger)sender.tag];
    NSIndexSet *column = [NSIndexSet indexSetWithIndex:3];
    [self.tableView reloadDataForRowIndexes:row columnIndexes:column];
}

- (void)addRule:(id)sender {
    (void)sender;
    [self commitEditing];
    [self.drafts addObject:LRRuleDraft.newDraft];
    [self.tableView reloadData];
    NSInteger row = (NSInteger)self.drafts.count - 1;
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
                byExtendingSelection:NO];
    [self.tableView scrollRowToVisible:row];
}

- (void)removeRule:(id)sender {
    (void)sender;
    NSInteger row = self.tableView.selectedRow;
    if (row < 0) { return; }
    [self.drafts removeObjectAtIndex:(NSUInteger)row];
    [self.tableView reloadData];
    [self updateButtonState];
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
    [self commitEditing];
    NSInteger source = self.tableView.selectedRow;
    NSInteger destination = source + offset;
    if (source < 0 || destination < 0 || destination >= (NSInteger)self.drafts.count) { return; }
    [self.drafts exchangeObjectAtIndex:(NSUInteger)source withObjectAtIndex:(NSUInteger)destination];
    [self.tableView reloadData];
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)destination]
                byExtendingSelection:NO];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    [self updateButtonState];
}

- (void)updateButtonState {
    NSInteger row = self.tableView.selectedRow;
    self.removeButton.enabled = row >= 0;
    self.moveUpButton.enabled = row > 0;
    self.moveDownButton.enabled = row >= 0 && row + 1 < (NSInteger)self.drafts.count;
}

@end

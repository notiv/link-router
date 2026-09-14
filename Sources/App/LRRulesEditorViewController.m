#import "LRRulesEditorViewController.h"

#import "LRRouting.h"

static NSString *const LRRulesGroup = @"Rules";
static NSString *const LRFallbackItem = @"Unmatched links";
static const NSTimeInterval LRDeleteHoverDelay = 0.4;
static NSPasteboardType const LRRulePasteboardType = @"com.linkrouter.rule-row";
static NSUserInterfaceItemIdentifier const LRSidebarColumnIdentifier = @"Route";
static NSUserInterfaceItemIdentifier const LRRuleCellIdentifier = @"RuleCell";
static NSUserInterfaceItemIdentifier const LRSpecialRouteCellIdentifier = @"SpecialRouteCell";
static NSUserInterfaceItemIdentifier const LRRulesGroupCellIdentifier = @"RulesGroupCell";
static NSUserInterfaceItemIdentifier const LRNameFieldIdentifier = @"RuleName";
static NSUserInterfaceItemIdentifier const LRProfileFieldIdentifier = @"Profile";
static NSUserInterfaceItemIdentifier const LRDomainFieldIdentifier = @"Domain";

@interface LRFlippedView : NSView
@end

@implementation LRFlippedView
- (BOOL)isFlipped { return YES; }
@end

@interface LRRulesOutlineView : NSOutlineView
@property(nonatomic, weak) id deleteTarget;
@property(nonatomic) SEL deleteAction;
@end

@implementation LRRulesOutlineView
- (NSRect)frameOfCellAtColumn:(NSInteger)column row:(NSInteger)row {
    NSRect frame = [super frameOfCellAtColumn:column row:row];
    id item = row >= 0 && row < self.numberOfRows ? [self itemAtRow:row] : nil;
    if (item != nil && ![item isEqual:LRRulesGroup]) {
        frame.size.width = MAX(0.0, NSWidth(self.bounds) - NSMinX(frame) - 2.0);
    }
    return frame;
}

- (void)keyDown:(NSEvent *)event {
    BOOL isDelete = event.keyCode == 51 || event.keyCode == 117;
    if (isDelete && self.selectedRow >= 0 && self.deleteTarget != nil) {
        [NSApplication.sharedApplication sendAction:self.deleteAction
                                                 to:self.deleteTarget
                                               from:self];
        return;
    }
    [super keyDown:event];
}
@end

@interface LRHoverDeleteButton : NSButton
@property(nonatomic, strong) NSTrackingArea *hoverTrackingArea;
@property(nonatomic, strong) NSTimer *hoverTimer;
@property(nonatomic, strong) NSButton *collapsedButton;
@property(nonatomic, strong) NSButton *expandedButton;
@property(nonatomic) BOOL expanded;
@property(nonatomic) BOOL configured;
@property(nonatomic) BOOL animating;
- (void)setExpanded:(BOOL)expanded;
@end

@implementation LRHoverDeleteButton

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.bordered = NO;
        self.title = @"";
        self.wantsLayer = YES;
        self.layer.masksToBounds = YES;

        _collapsedButton = [NSButton
            buttonWithImage:[NSImage imageWithSystemSymbolName:@"minus.circle"
                                      accessibilityDescription:@"Delete rule"]
                     target:nil
                     action:nil];
        _collapsedButton.bordered = NO;
        _collapsedButton.controlSize = NSControlSizeSmall;
        _collapsedButton.contentTintColor = [NSColor.whiteColor colorWithAlphaComponent:0.58];
        [_collapsedButton setAccessibilityElement:NO];

        _expandedButton = [NSButton buttonWithTitle:@"Delete" target:nil action:nil];
        _expandedButton.bezelStyle = NSBezelStyleAccessoryBarAction;
        _expandedButton.controlSize = NSControlSizeSmall;
        _expandedButton.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize
                                                 weight:NSFontWeightMedium];
        _expandedButton.alignment = NSTextAlignmentCenter;
        _expandedButton.hasDestructiveAction = YES;
        _expandedButton.bezelColor = nil;
        [_expandedButton setAccessibilityElement:NO];
        _expandedButton.hidden = YES;

        [self addSubview:_expandedButton];
        [self addSubview:_collapsedButton];
    }
    return self;
}

- (NSView *)hitTest:(NSPoint)point {
    // The whole slot is one click target; the animated visuals beneath never track clicks.
    // AppKit hands -hitTest: a point in the superview's coordinate space.
    NSPoint localPoint = [self convertPoint:point fromView:self.superview];
    return !self.hidden && NSPointInRect(localPoint, self.bounds) ? self : nil;
}

- (void)layout {
    [super layout];
    CGFloat width = NSWidth(self.bounds);
    self.collapsedButton.frame = NSMakeRect(MAX(0.0, width - 20.0),
                                            0.0,
                                            MIN(20.0, width),
                                            NSHeight(self.bounds));
    if (!self.animating) {
        self.expandedButton.frame = self.expanded
            ? self.bounds
            : NSOffsetRect(self.bounds, width, 0.0);
    }
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.hoverTrackingArea != nil) { [self removeTrackingArea:self.hoverTrackingArea]; }
    self.hoverTrackingArea = [[NSTrackingArea alloc]
        initWithRect:NSZeroRect
             options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow |
                     NSTrackingInVisibleRect
               owner:self
            userInfo:nil];
    [self addTrackingArea:self.hoverTrackingArea];
}

- (void)mouseEntered:(NSEvent *)event {
    (void)event;
    [self.hoverTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.hoverTimer = [NSTimer timerWithTimeInterval:LRDeleteHoverDelay
                                            repeats:NO
                                              block:^(NSTimer *timer) {
        (void)timer;
        LRHoverDeleteButton *button = weakSelf;
        button.hoverTimer = nil;
        [button setExpanded:YES];
    }];
    [NSRunLoop.mainRunLoop addTimer:self.hoverTimer forMode:NSRunLoopCommonModes];
}

- (void)mouseExited:(NSEvent *)event {
    (void)event;
    [self.hoverTimer invalidate];
    self.hoverTimer = nil;
    [self setExpanded:NO];
}

- (void)setExpanded:(BOOL)expanded {
    if (!expanded) {
        [self.hoverTimer invalidate];
        self.hoverTimer = nil;
    }
    BOOL shouldAnimate = self.configured && self.window != nil && self.expanded != expanded;
    self.configured = YES;
    _expanded = expanded;
    [self layoutSubtreeIfNeeded];
    if (!shouldAnimate) {
        self.animating = NO;
        self.collapsedButton.hidden = expanded;
        self.collapsedButton.alphaValue = expanded ? 0.0 : 1.0;
        self.expandedButton.hidden = !expanded;
        self.expandedButton.alphaValue = expanded ? 1.0 : 0.0;
        [self setNeedsLayout:YES];
        [self layoutSubtreeIfNeeded];
        return;
    }

    self.animating = YES;
    self.collapsedButton.hidden = NO;
    self.expandedButton.hidden = NO;
    if (expanded) {
        self.collapsedButton.alphaValue = 1.0;
        self.expandedButton.alphaValue = 1.0;
        self.expandedButton.frame = NSOffsetRect(self.bounds, NSWidth(self.bounds), 0.0);
    } else {
        self.collapsedButton.alphaValue = 0.0;
        self.expandedButton.alphaValue = 1.0;
        self.expandedButton.frame = self.bounds;
    }
    NSRect destination = expanded
        ? self.bounds
        : NSOffsetRect(self.bounds, NSWidth(self.bounds), 0.0);
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.18;
        self.expandedButton.animator.frame = destination;
        self.collapsedButton.animator.alphaValue = expanded ? 0.0 : 1.0;
    } completionHandler:^{
        if (self.expanded != expanded) { return; }
        self.animating = NO;
        self.collapsedButton.hidden = expanded;
        self.expandedButton.hidden = !expanded;
        [self setNeedsLayout:YES];
    }];
}

@end

@interface LRRuleSidebarCellView : NSTableCellView
@property(nonatomic, strong) LRHoverDeleteButton *deleteButton;
@end

@implementation LRRuleSidebarCellView
@end

static NSTextField *LRLabel(NSString *text, NSFont *font, NSColor *color) {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = font;
    label.textColor = color;
    label.maximumNumberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    return label;
}

static NSButton *LRSymbolButton(NSString *symbolName,
                                NSString *accessibilityLabel,
                                id target,
                                SEL action) {
    NSButton *button = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbolName
                                                          accessibilityDescription:accessibilityLabel]
                                         target:target
                                         action:action];
    button.bezelStyle = NSBezelStyleTexturedRounded;
    button.toolTip = accessibilityLabel;
    [button setAccessibilityLabel:accessibilityLabel];
    return button;
}

static NSStackView *LRVerticalStack(void) {
    NSStackView *stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 12.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    return stack;
}

static LRBrowserTarget *LRCopyTarget(LRBrowserTarget *target) {
    return [LRBrowserTarget targetWithApplication:target.application
                                          profile:target.profile
                                  privateBrowsing:target.privateBrowsing];
}

static LRRoutingRule *LRCopyRule(LRRoutingRule *rule) {
    return [LRRoutingRule ruleWithName:rule.name
                                hosts:[rule.hosts copy]
                               target:LRCopyTarget(rule.target)];
}

@interface LRRulesEditorViewController () <NSOutlineViewDataSource,
                                            NSOutlineViewDelegate,
                                            NSTextFieldDelegate>
@property(nonatomic, copy) LRRulesEditorChangeHandler configurationChanged;
@property(nonatomic, strong) LRBrowserTarget *defaultTarget;
@property(nonatomic, strong) NSMutableArray<LRRoutingRule *> *rules;
@property(nonatomic, strong) NSOutlineView *sidebarOutlineView;
@property(nonatomic, strong) NSOutlineView *specialRoutesOutlineView;
@property(nonatomic, strong) NSStackView *detailStack;
@property(nonatomic, strong) LRRoutingRule *draggedRule;
@property(nonatomic, strong) NSMutableSet<LRRoutingRule *> *rulesAwaitingInitialConfiguration;
- (void)renderDetail;
- (void)markRuleConfigured:(LRRoutingRule *)rule;
- (void)selectItem:(id)item;
- (void)updateRuleDeleteVisibility;
@end

@implementation LRRulesEditorViewController

- (instancetype)initWithConfiguration:(LRRouterConfiguration *)configuration
                  configurationChanged:(LRRulesEditorChangeHandler)configurationChanged {
    self = [super init];
    if (self) {
        _configurationChanged = [configurationChanged copy];
        _rulesAwaitingInitialConfiguration = [NSMutableSet set];
        self.splitView.vertical = YES;
        self.splitView.dividerStyle = NSSplitViewDividerStyleThin;
        [self buildSidebar];
        [self buildDetail];
        [self setConfiguration:configuration];
    }
    return self;
}

- (void)buildSidebar {
    NSVisualEffectView *sidebar = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    sidebar.material = NSVisualEffectMaterialSidebar;
    sidebar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    sidebar.state = NSVisualEffectStateFollowsWindowActiveState;

    self.sidebarOutlineView = [self outlineViewWithAccessibilityLabel:@"Routing rules"];
    self.specialRoutesOutlineView = [self outlineViewWithAccessibilityLabel:@"Other routes"];
    [self.sidebarOutlineView registerForDraggedTypes:@[LRRulePasteboardType]];
    [self.sidebarOutlineView setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
    LRRulesOutlineView *rulesOutlineView = (LRRulesOutlineView *)self.sidebarOutlineView;
    rulesOutlineView.deleteTarget = self;
    rulesOutlineView.deleteAction = @selector(removeRule:);

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scrollView.documentView = self.sidebarOutlineView;
    scrollView.hasVerticalScroller = YES;
    scrollView.drawsBackground = NO;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;

    NSScrollView *specialRoutes = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    specialRoutes.documentView = self.specialRoutesOutlineView;
    specialRoutes.hasVerticalScroller = NO;
    specialRoutes.drawsBackground = NO;
    specialRoutes.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *specialRoutesHeading = LRLabel(@"Everything Else",
                                                [NSFont systemFontOfSize:11.0
                                                                 weight:NSFontWeightSemibold],
                                                NSColor.secondaryLabelColor);
    specialRoutesHeading.translatesAutoresizingMaskIntoConstraints = NO;

    [sidebar addSubview:scrollView];
    [sidebar addSubview:specialRoutesHeading];
    [sidebar addSubview:specialRoutes];
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:sidebar.safeAreaLayoutGuide.topAnchor constant:8.0],
        [scrollView.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:specialRoutesHeading.topAnchor constant:-24.0],
        [specialRoutesHeading.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:12.0],
        [specialRoutesHeading.trailingAnchor constraintLessThanOrEqualToAnchor:sidebar.trailingAnchor
                                                                       constant:-12.0],
        [specialRoutesHeading.bottomAnchor constraintEqualToAnchor:specialRoutes.topAnchor constant:8.0],
        [specialRoutes.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor],
        [specialRoutes.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor],
        [specialRoutes.bottomAnchor constraintEqualToAnchor:sidebar.safeAreaLayoutGuide.bottomAnchor
                                                     constant:-18.0],
        [specialRoutes.heightAnchor constraintEqualToConstant:42.0],
    ]];

    NSViewController *sidebarController = [[NSViewController alloc] init];
    sidebarController.view = sidebar;
    NSSplitViewItem *sidebarItem = [NSSplitViewItem splitViewItemWithViewController:sidebarController];
    sidebarItem.minimumThickness = 220.0;
    sidebarItem.maximumThickness = 320.0;
    sidebarItem.canCollapse = NO;
    [self addSplitViewItem:sidebarItem];
}

- (NSOutlineView *)outlineViewWithAccessibilityLabel:(NSString *)accessibilityLabel {
    NSOutlineView *outlineView = [accessibilityLabel isEqualToString:@"Routing rules"]
        ? [[LRRulesOutlineView alloc] initWithFrame:NSZeroRect]
        : [[NSOutlineView alloc] initWithFrame:NSZeroRect];
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:LRSidebarColumnIdentifier];
    [outlineView addTableColumn:column];
    outlineView.outlineTableColumn = column;
    outlineView.headerView = nil;
    outlineView.delegate = self;
    outlineView.dataSource = self;
    outlineView.style = NSTableViewStyleSourceList;
    outlineView.rowSizeStyle = NSTableViewRowSizeStyleDefault;
    outlineView.indentationPerLevel = 0.0;
    outlineView.indentationMarkerFollowsCell = NO;
    outlineView.backgroundColor = NSColor.clearColor;
    outlineView.focusRingType = NSFocusRingTypeDefault;
    [outlineView setAccessibilityLabel:accessibilityLabel];
    return outlineView;
}

- (void)buildDetail {
    NSView *detail = [[NSView alloc] initWithFrame:NSZeroRect];
    [detail setAccessibilityLabel:@"Rule details"];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scrollView.hasVerticalScroller = YES;
    scrollView.drawsBackground = NO;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;

    LRFlippedView *document = [[LRFlippedView alloc] initWithFrame:NSZeroRect];
    document.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.documentView = document;

    self.detailStack = LRVerticalStack();
    [document addSubview:self.detailStack];
    [detail addSubview:scrollView];
    NSLayoutConstraint *preferredDetailWidth =
        [self.detailStack.widthAnchor constraintEqualToConstant:620.0];
    preferredDetailWidth.priority = NSLayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:detail.safeAreaLayoutGuide.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:detail.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:detail.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:detail.bottomAnchor],
        [document.widthAnchor constraintEqualToAnchor:scrollView.contentView.widthAnchor],
        [self.detailStack.topAnchor constraintEqualToAnchor:document.safeAreaLayoutGuide.topAnchor constant:8.0],
        [self.detailStack.centerXAnchor constraintEqualToAnchor:document.centerXAnchor],
        [self.detailStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:document.leadingAnchor
                                                                    constant:30.0],
        [self.detailStack.trailingAnchor constraintLessThanOrEqualToAnchor:document.trailingAnchor
                                                                   constant:-30.0],
        preferredDetailWidth,
        [self.detailStack.widthAnchor constraintLessThanOrEqualToConstant:620.0],
        [document.bottomAnchor constraintGreaterThanOrEqualToAnchor:self.detailStack.bottomAnchor
                                                           constant:108.0],
    ]];

    NSViewController *detailController = [[NSViewController alloc] init];
    detailController.view = detail;
    NSSplitViewItem *detailItem = [NSSplitViewItem splitViewItemWithViewController:detailController];
    detailItem.minimumThickness = 460.0;
    [self addSplitViewItem:detailItem];
}

- (void)setConfiguration:(LRRouterConfiguration *)configuration {
    [self.rulesAwaitingInitialConfiguration removeAllObjects];
    self.defaultTarget = LRCopyTarget(configuration.defaultTarget);
    self.rules = [NSMutableArray arrayWithCapacity:configuration.rules.count];
    for (LRRoutingRule *rule in configuration.rules) {
        [self.rules addObject:LRCopyRule(rule)];
    }
    [self.sidebarOutlineView reloadData];
    [self.specialRoutesOutlineView reloadData];
    [self.sidebarOutlineView expandItem:LRRulesGroup];
    [self selectItem:self.rules.firstObject ?: LRFallbackItem];
}

- (void)markConfigurationSaved {
    [self.rulesAwaitingInitialConfiguration removeAllObjects];
}

- (LRRouterConfiguration *)currentConfiguration {
    NSMutableArray<LRRoutingRule *> *rules = [NSMutableArray arrayWithCapacity:self.rules.count];
    for (LRRoutingRule *rule in self.rules) {
        [rules addObject:LRCopyRule(rule)];
    }
    return [[LRRouterConfiguration alloc] initWithDefaultTarget:LRCopyTarget(self.defaultTarget)
                                                          rules:rules];
}

- (void)selectItem:(id)item {
    NSOutlineView *outlineView = [item isKindOfClass:LRRoutingRule.class]
        ? self.sidebarOutlineView
        : self.specialRoutesOutlineView;
    NSOutlineView *otherOutlineView = outlineView == self.sidebarOutlineView
        ? self.specialRoutesOutlineView
        : self.sidebarOutlineView;
    [otherOutlineView deselectAll:nil];
    NSInteger row = [outlineView rowForItem:item];
    if (row >= 0) {
        [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
                 byExtendingSelection:NO];
    }
    [self updateRuleDeleteVisibility];
    [self renderDetail];
}

- (void)updateRuleDeleteVisibility {
    for (NSInteger row = 0; row < self.sidebarOutlineView.numberOfRows; row += 1) {
        NSView *cell = [self.sidebarOutlineView viewAtColumn:0 row:row makeIfNecessary:NO];
        if (![cell isKindOfClass:LRRuleSidebarCellView.class]) { continue; }
        LRHoverDeleteButton *deleteButton = ((LRRuleSidebarCellView *)cell).deleteButton;
        [deleteButton setExpanded:NO];
        deleteButton.hidden = row != self.sidebarOutlineView.selectedRow;
    }
}

- (void)markChanged {
    if (self.configurationChanged != nil) { self.configurationChanged(); }
}

- (id)selectedItem {
    NSInteger row = self.sidebarOutlineView.selectedRow;
    if (row >= 0) { return [self.sidebarOutlineView itemAtRow:row]; }
    row = self.specialRoutesOutlineView.selectedRow;
    return row < 0 ? nil : [self.specialRoutesOutlineView itemAtRow:row];
}

- (NSInteger)selectedRuleIndex {
    id item = [self selectedItem];
    if (![item isKindOfClass:LRRoutingRule.class]) { return NSNotFound; }
    return (NSInteger)[self.rules indexOfObjectIdenticalTo:item];
}

- (LRRoutingRule *)selectedRule {
    NSInteger index = [self selectedRuleIndex];
    return index == NSNotFound ? nil : self.rules[(NSUInteger)index];
}

- (LRBrowserTarget *)selectedTarget {
    LRRoutingRule *rule = [self selectedRule];
    return rule == nil ? self.defaultTarget : rule.target;
}

- (void)clearDetail {
    for (NSView *view in [self.detailStack.arrangedSubviews copy]) {
        [self.detailStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
}

- (NSTextField *)addHeading:(NSString *)heading detail:(NSString *)detail {
    NSTextField *title = LRLabel(heading,
                                 [NSFont systemFontOfSize:24.0 weight:NSFontWeightSemibold],
                                 NSColor.labelColor);
    [self.detailStack addArrangedSubview:title];
    if (detail.length > 0) {
        NSTextField *description = LRLabel(detail,
                                           [NSFont systemFontOfSize:NSFont.systemFontSize],
                                           NSColor.secondaryLabelColor);
        [self.detailStack addArrangedSubview:description];
        [self.detailStack setCustomSpacing:22.0 afterView:description];
    } else {
        [self.detailStack setCustomSpacing:22.0 afterView:title];
    }
    return title;
}

- (void)addSectionTitle:(NSString *)title {
    NSTextField *label = LRLabel(title,
                                 [NSFont systemFontOfSize:NSFont.systemFontSize
                                                  weight:NSFontWeightSemibold],
                                 NSColor.labelColor);
    [self.detailStack addArrangedSubview:label];
}

- (void)addBrowserControlsForTarget:(LRBrowserTarget *)target inlineTitle:(BOOL)inlineTitle {
    NSSegmentedControl *browser = [NSSegmentedControl
        segmentedControlWithLabels:@[@"Safari", @"Google Chrome"]
                      trackingMode:NSSegmentSwitchTrackingSelectOne
                            target:self
                            action:@selector(browserChanged:)];
    browser.selectedSegment = target.application == LRBrowserApplicationChrome ? 1 : 0;
    [browser setAccessibilityLabel:@"Browser"];
    NSMutableArray<NSView *> *browserViews = [NSMutableArray array];
    if (inlineTitle) {
        [browserViews addObject:LRLabel(@"Open in",
            [NSFont systemFontOfSize:NSFont.systemFontSize weight:NSFontWeightSemibold],
            NSColor.labelColor)];
    } else {
        [self addSectionTitle:@"Open in"];
    }
    [browserViews addObject:browser];

    if (target.application == LRBrowserApplicationChrome) {
        NSTextField *profile = [NSTextField textFieldWithString:target.profile ?: @""];
        profile.placeholderString = @"Profile";
        profile.identifier = LRProfileFieldIdentifier;
        profile.delegate = self;
        [profile setAccessibilityLabel:@"Chrome profile directory"];
        [profile.widthAnchor constraintEqualToConstant:180.0].active = YES;
        [browserViews addObject:profile];
    }

    NSStackView *browserRow = [NSStackView stackViewWithViews:browserViews];
    browserRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    browserRow.alignment = NSLayoutAttributeCenterY;
    browserRow.spacing = 10.0;
    [self.detailStack addArrangedSubview:browserRow];

    if (target.application == LRBrowserApplicationChrome) {
        NSButton *privateWindow = [NSButton checkboxWithTitle:@"Open in a private window"
                                                      target:self
                                                      action:@selector(privateBrowsingChanged:)];
        privateWindow.state = target.privateBrowsing ? NSControlStateValueOn : NSControlStateValueOff;
        [privateWindow setAccessibilityLabel:@"Open in a private Chrome window"];
        [self.detailStack addArrangedSubview:privateWindow];
    }
}

- (void)renderRule:(LRRoutingRule *)rule {
    NSTextField *name = [NSTextField textFieldWithString:rule.name];
    name.font = [NSFont systemFontOfSize:24.0 weight:NSFontWeightSemibold];
    name.identifier = LRNameFieldIdentifier;
    name.delegate = self;
    name.bordered = NO;
    name.drawsBackground = NO;
    name.placeholderString = @"Rule name";
    [name setAccessibilityLabel:@"Rule name"];
    [self.detailStack addArrangedSubview:name];
    [self.detailStack setCustomSpacing:22.0 afterView:name];

    [self addSectionTitle:@"Domains"];
    [rule.hosts enumerateObjectsUsingBlock:^(NSString *pattern, NSUInteger index, BOOL *stop) {
        (void)stop;
        BOOL includesSubdomains = [pattern hasPrefix:@"*."];
        NSTextField *field = [NSTextField textFieldWithString:pattern];
        field.placeholderString = @"example.com";
        field.identifier = LRDomainFieldIdentifier;
        field.tag = (NSInteger)index;
        field.delegate = self;
        [field setAccessibilityLabel:[NSString stringWithFormat:@"Domain %lu",
                                                                 (unsigned long)(index + 1)]];
        [field.widthAnchor constraintGreaterThanOrEqualToConstant:220.0].active = YES;

        NSSegmentedControl *mode = [NSSegmentedControl
            segmentedControlWithLabels:@[@"Exact", @"Subdomains"]
                          trackingMode:NSSegmentSwitchTrackingSelectOne
                                target:self
                                action:@selector(domainModeChanged:)];
        mode.selectedSegment = includesSubdomains ? 1 : 0;
        mode.tag = (NSInteger)index;
        [mode setAccessibilityLabel:[NSString stringWithFormat:@"Domain %lu matching",
                                                              (unsigned long)(index + 1)]];
        NSButton *remove = LRSymbolButton(@"xmark", @"Remove domain", self,
                                          @selector(removeDomain:));
        remove.tag = (NSInteger)index;
        remove.enabled = rule.hosts.count > 1;
        NSStackView *row = [NSStackView stackViewWithViews:@[field, mode, remove]];
        row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        row.spacing = 8.0;
        [self.detailStack addArrangedSubview:row];
    }];

    NSButton *addDomain = [NSButton buttonWithTitle:@"Add Domain"
                                             target:self
                                             action:@selector(addDomain:)];
    addDomain.bezelStyle = NSBezelStyleRounded;
    [addDomain setAccessibilityLabel:@"Add domain to selected rule"];
    [self.detailStack addArrangedSubview:addDomain];
    [self.detailStack setCustomSpacing:24.0 afterView:addDomain];
    [self addBrowserControlsForTarget:rule.target inlineTitle:NO];
}

- (void)renderDetail {
    [self clearDetail];
    id item = [self selectedItem];
    if ([item isKindOfClass:LRRoutingRule.class]) {
        [self renderRule:item];
    } else {
        [self addHeading:@"Unmatched links"
                  detail:@"Links that don't match a rule open here."];
        [self addBrowserControlsForTarget:self.defaultTarget inlineTitle:YES];
    }
}

- (void)addRule:(id)sender {
    (void)sender;
    LRRoutingRule *rule = [LRRoutingRule
        ruleWithName:@"New Rule"
               hosts:@[@"example.com"]
              target:[LRBrowserTarget targetWithApplication:LRBrowserApplicationChrome profile:nil]];
    [self.rules addObject:rule];
    [self.rulesAwaitingInitialConfiguration addObject:rule];
    [self.sidebarOutlineView reloadItem:LRRulesGroup reloadChildren:YES];
    [self.sidebarOutlineView expandItem:LRRulesGroup];
    [self selectItem:rule];
    [self markChanged];
    [self.view.window makeFirstResponder:self.detailStack.arrangedSubviews.firstObject];
}

- (void)removeRule:(id)sender {
    (void)sender;
    LRRoutingRule *rule = [self selectedRule];
    if (rule == nil) { return; }
    if ([self.rulesAwaitingInitialConfiguration containsObject:rule]) {
        [self removeSelectedRule];
        return;
    }
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = [NSString stringWithFormat:@"Remove “%@”?", rule.name];
    alert.informativeText = @"This rule will be removed when you save your changes.";
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) { [self removeSelectedRule]; }
    }];
}

- (void)removeRuleFromSidebar:(NSButton *)sender {
    [self removeRule:sender];
}

- (void)removeSelectedRule {
    NSInteger index = [self selectedRuleIndex];
    if (index == NSNotFound) { return; }
    [self.rulesAwaitingInitialConfiguration removeObject:self.rules[(NSUInteger)index]];
    [self.rules removeObjectAtIndex:(NSUInteger)index];
    [self.sidebarOutlineView reloadItem:LRRulesGroup reloadChildren:YES];
    id nextItem = self.rules.count == 0
        ? LRFallbackItem
        : self.rules[MIN((NSUInteger)index, self.rules.count - 1)];
    [self selectItem:nextItem];
    [self markChanged];
}

- (void)markRuleConfigured:(LRRoutingRule *)rule {
    [self.rulesAwaitingInitialConfiguration removeObject:rule];
}

- (void)moveRuleAtIndex:(NSUInteger)sourceIndex toChildIndex:(NSUInteger)childIndex {
    if (sourceIndex >= self.rules.count || childIndex > self.rules.count) {
        return;
    }
    LRRoutingRule *rule = self.rules[sourceIndex];
    [self.rules removeObjectAtIndex:sourceIndex];
    NSUInteger destinationIndex = childIndex > sourceIndex ? childIndex - 1 : childIndex;
    destinationIndex = MIN(destinationIndex, self.rules.count);
    [self.rules insertObject:rule atIndex:destinationIndex];
    [self.sidebarOutlineView reloadItem:LRRulesGroup reloadChildren:YES];
    [self selectItem:rule];
    [self markChanged];
}

- (void)addDomain:(id)sender {
    (void)sender;
    LRRoutingRule *rule = [self selectedRule];
    if (rule == nil) { return; }
    [self markRuleConfigured:rule];
    rule.hosts = [rule.hosts arrayByAddingObject:@"example.com"];
    [self renderDetail];
    [self markChanged];
    [self.view.window makeFirstResponder:self.detailStack.arrangedSubviews.lastObject];
}

- (void)removeDomain:(NSButton *)sender {
    LRRoutingRule *rule = [self selectedRule];
    if (rule == nil || rule.hosts.count <= 1 || sender.tag < 0 ||
        sender.tag >= (NSInteger)rule.hosts.count) {
        return;
    }
    [self markRuleConfigured:rule];
    NSMutableArray<NSString *> *hosts = [rule.hosts mutableCopy];
    [hosts removeObjectAtIndex:(NSUInteger)sender.tag];
    rule.hosts = hosts;
    [self renderDetail];
    [self markChanged];
}

- (void)domainModeChanged:(NSSegmentedControl *)sender {
    LRRoutingRule *rule = [self selectedRule];
    if (rule == nil || sender.tag < 0 || sender.tag >= (NSInteger)rule.hosts.count) { return; }
    [self markRuleConfigured:rule];
    NSMutableArray<NSString *> *hosts = [rule.hosts mutableCopy];
    NSString *host = [hosts[(NSUInteger)sender.tag] stringByReplacingOccurrencesOfString:@"*."
                                                                               withString:@""
                                                                                  options:NSAnchoredSearch
                                                                                    range:NSMakeRange(0, hosts[(NSUInteger)sender.tag].length)];
    hosts[(NSUInteger)sender.tag] = sender.selectedSegment == 1 && host.length > 0
        ? [@"*." stringByAppendingString:host]
        : host;
    rule.hosts = hosts;
    [self renderDetail];
    [self markChanged];
}

- (void)browserChanged:(NSSegmentedControl *)sender {
    LRBrowserTarget *target = [self selectedTarget];
    LRBrowserApplication application = sender.selectedSegment == 1
        ? LRBrowserApplicationChrome
        : LRBrowserApplicationSafari;
    LRBrowserTarget *replacement = [LRBrowserTarget targetWithApplication:application
                                                                  profile:application == LRBrowserApplicationChrome
                                                                              ? target.profile
                                                                              : nil
                                                          privateBrowsing:application == LRBrowserApplicationChrome &&
                                                                          target.privateBrowsing];
    LRRoutingRule *rule = [self selectedRule];
    if (rule == nil) {
        self.defaultTarget = replacement;
    } else {
        [self markRuleConfigured:rule];
        rule.target = replacement;
        [self.sidebarOutlineView reloadItem:rule];
    }
    [self renderDetail];
    [self markChanged];
}

- (void)privateBrowsingChanged:(NSButton *)sender {
    LRBrowserTarget *target = [self selectedTarget];
    if (target.application != LRBrowserApplicationChrome) { return; }
    LRBrowserTarget *replacement = [LRBrowserTarget targetWithApplication:target.application
                                                                  profile:target.profile
                                                          privateBrowsing:sender.state == NSControlStateValueOn];
    LRRoutingRule *rule = [self selectedRule];
    if (rule == nil) {
        self.defaultTarget = replacement;
    } else {
        [self markRuleConfigured:rule];
        rule.target = replacement;
        [self.sidebarOutlineView reloadItem:rule];
    }
    [self markChanged];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    NSTextField *field = notification.object;
    LRRoutingRule *rule = [self selectedRule];
    if (rule != nil) { [self markRuleConfigured:rule]; }
    if ([field.identifier isEqual:LRNameFieldIdentifier] && rule != nil) {
        rule.name = field.stringValue;
        [self.sidebarOutlineView reloadItem:rule];
    } else if ([field.identifier isEqual:LRProfileFieldIdentifier]) {
        LRBrowserTarget *target = [self selectedTarget];
        LRBrowserTarget *replacement = [LRBrowserTarget targetWithApplication:target.application
                                                                      profile:field.stringValue
                                                              privateBrowsing:target.privateBrowsing];
        if (rule == nil) {
            self.defaultTarget = replacement;
        } else {
            rule.target = replacement;
            [self.sidebarOutlineView reloadItem:rule];
        }
    } else if ([field.identifier isEqual:LRDomainFieldIdentifier] && rule != nil &&
               field.tag >= 0 && field.tag < (NSInteger)rule.hosts.count) {
        NSMutableArray<NSString *> *hosts = [rule.hosts mutableCopy];
        BOOL includesSubdomains = [hosts[(NSUInteger)field.tag] hasPrefix:@"*."];
        NSString *host = [field.stringValue hasPrefix:@"*."]
            ? [field.stringValue substringFromIndex:2]
            : field.stringValue;
        hosts[(NSUInteger)field.tag] = includesSubdomains && host.length > 0
            ? [@"*." stringByAppendingString:host]
            : host;
        rule.hosts = hosts;
    }
    [self markChanged];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item == nil) { return 1; }
    if (outlineView == self.sidebarOutlineView && [item isEqual:LRRulesGroup]) {
        return (NSInteger)self.rules.count;
    }
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        return outlineView == self.sidebarOutlineView
            ? LRRulesGroup
            : LRFallbackItem;
    }
    if (outlineView == self.sidebarOutlineView && [item isEqual:LRRulesGroup]) {
        return self.rules[(NSUInteger)index];
    }
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    (void)outlineView;
    return [item isEqual:LRRulesGroup];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item {
    (void)outlineView;
    return [item isEqual:LRRulesGroup];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    return ![self outlineView:outlineView isGroupItem:item];
}

- (NSView *)outlineView:(NSOutlineView *)outlineView
      viewForTableColumn:(NSTableColumn *)tableColumn
                    item:(id)item {
    (void)tableColumn;
    if ([self outlineView:outlineView isGroupItem:item]) {
        NSTableCellView *cell = [outlineView makeViewWithIdentifier:LRRulesGroupCellIdentifier
                                                              owner:self];
        if (cell == nil) {
            cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
            cell.identifier = LRRulesGroupCellIdentifier;
            NSTextField *label = LRLabel(@"Rules",
                [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold],
                NSColor.secondaryLabelColor);
            label.translatesAutoresizingMaskIntoConstraints = NO;
            NSButton *addButton = LRSymbolButton(@"plus", @"Add rule", self,
                                                  @selector(addRule:));
            addButton.bordered = NO;
            addButton.controlSize = NSControlSizeSmall;
            addButton.translatesAutoresizingMaskIntoConstraints = NO;
            cell.textField = label;
            [cell addSubview:label];
            [cell addSubview:addButton];
            [NSLayoutConstraint activateConstraints:@[
                [label.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:4.0],
                [label.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
                [addButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:label.trailingAnchor
                                                                      constant:8.0],
                [addButton.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-14.0],
                [addButton.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
                [addButton.widthAnchor constraintEqualToConstant:20.0],
                [addButton.heightAnchor constraintEqualToConstant:20.0],
            ]];
        }
        return cell;
    }
    BOOL isRule = [item isKindOfClass:LRRoutingRule.class];
    NSUserInterfaceItemIdentifier identifier = isRule
        ? LRRuleCellIdentifier
        : LRSpecialRouteCellIdentifier;
    NSTableCellView *cell = [outlineView makeViewWithIdentifier:identifier owner:self];
    if (cell == nil) {
        cell = isRule
            ? [[LRRuleSidebarCellView alloc] initWithFrame:NSZeroRect]
            : [[NSTableCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = identifier;
        NSTextField *label = [NSTextField labelWithString:@""];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.textField = label;
        [cell addSubview:label];
        if (isRule) {
            LRRuleSidebarCellView *ruleCell = (LRRuleSidebarCellView *)cell;
            LRHoverDeleteButton *deleteButton = [[LRHoverDeleteButton alloc]
                initWithFrame:NSZeroRect];
            deleteButton.target = self;
            deleteButton.action = @selector(removeRuleFromSidebar:);
            [deleteButton setAccessibilityLabel:@"Delete rule"];
            deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
            ruleCell.deleteButton = deleteButton;
            [ruleCell addSubview:deleteButton];
            [NSLayoutConstraint activateConstraints:@[
                [label.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:4.0],
                [label.trailingAnchor constraintEqualToAnchor:deleteButton.leadingAnchor constant:-6.0],
                [label.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
                [deleteButton.widthAnchor constraintEqualToConstant:50.0],
                [deleteButton.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor
                                                              constant:-14.0],
                [deleteButton.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
                [deleteButton.heightAnchor constraintEqualToConstant:20.0],
            ]];
            [deleteButton setExpanded:NO];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                [label.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:4.0],
                [label.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-4.0],
                [label.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            ]];
        }
    }
    cell.objectValue = item;
    if (isRule) {
        LRRuleSidebarCellView *ruleCell = (LRRuleSidebarCellView *)cell;
        NSInteger row = [outlineView rowForItem:item];
        [ruleCell.deleteButton setExpanded:NO];
        ruleCell.deleteButton.hidden = row != outlineView.selectedRow;
    }
    NSString *title = isRule ? ((LRRoutingRule *)item).name : item;
    cell.textField.stringValue = title.length > 0 ? title : @"Untitled rule";
    cell.toolTip = cell.textField.stringValue;
    return cell;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldShowOutlineCellForItem:(id)item {
    (void)outlineView;
    (void)item;
    return NO;
}

- (id<NSPasteboardWriting>)outlineView:(NSOutlineView *)outlineView
               pasteboardWriterForItem:(id)item {
    if (outlineView != self.sidebarOutlineView || ![item isKindOfClass:LRRoutingRule.class]) {
        return nil;
    }
    self.draggedRule = item;
    NSPasteboardItem *pasteboardItem = [[NSPasteboardItem alloc] init];
    [pasteboardItem setString:((LRRoutingRule *)item).name ?: @"" forType:LRRulePasteboardType];
    return pasteboardItem;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView
                  validateDrop:(id<NSDraggingInfo>)info
                  proposedItem:(id)item
            proposedChildIndex:(NSInteger)childIndex {
    (void)info;
    if (outlineView != self.sidebarOutlineView || self.draggedRule == nil) {
        return NSDragOperationNone;
    }
    if ([item isKindOfClass:LRRoutingRule.class]) {
        NSUInteger index = [self.rules indexOfObjectIdenticalTo:item];
        if (index == NSNotFound) { return NSDragOperationNone; }
        [outlineView setDropItem:LRRulesGroup dropChildIndex:(NSInteger)index];
        return NSDragOperationMove;
    }
    if ([item isEqual:LRRulesGroup] && childIndex >= 0 &&
        childIndex <= (NSInteger)self.rules.count) {
        return NSDragOperationMove;
    }
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
         acceptDrop:(id<NSDraggingInfo>)info
               item:(id)item
         childIndex:(NSInteger)childIndex {
    (void)info;
    if (outlineView != self.sidebarOutlineView || ![item isEqual:LRRulesGroup] ||
        childIndex < 0 || self.draggedRule == nil) {
        return NO;
    }
    NSUInteger sourceIndex = [self.rules indexOfObjectIdenticalTo:self.draggedRule];
    self.draggedRule = nil;
    if (sourceIndex == NSNotFound) { return NO; }
    [self moveRuleAtIndex:sourceIndex toChildIndex:(NSUInteger)childIndex];
    return YES;
}

- (void)outlineView:(NSOutlineView *)outlineView
     draggingSession:(NSDraggingSession *)session
        endedAtPoint:(NSPoint)screenPoint
           operation:(NSDragOperation)operation {
    (void)session;
    (void)screenPoint;
    (void)operation;
    if (outlineView == self.sidebarOutlineView) { self.draggedRule = nil; }
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    NSOutlineView *outlineView = notification.object;
    if (outlineView.selectedRow >= 0) {
        NSOutlineView *otherOutlineView = outlineView == self.sidebarOutlineView
            ? self.specialRoutesOutlineView
            : self.sidebarOutlineView;
        [otherOutlineView deselectAll:nil];
    }
    [self updateRuleDeleteVisibility];
    [self renderDetail];
}

@end

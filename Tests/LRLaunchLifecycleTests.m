#import <AppKit/AppKit.h>

#import "LRAppDelegate.h"
#import "LRTestSupport.h"

@interface LRAppDelegate (LaunchLifecycleTesting)
- (void)openRuleEditor:(id)sender;
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender;
- (BOOL)applicationOpenUntitledFile:(NSApplication *)sender;
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender
                    hasVisibleWindows:(BOOL)hasVisibleWindows;
@end

@interface LRRecordingAppDelegate : LRAppDelegate
@property(nonatomic) BOOL editorRequested;
@end

@implementation LRRecordingAppDelegate
- (void)openRuleEditor:(id)sender {
    (void)sender;
    self.editorRequested = YES;
}
@end

static void TestExplicitApplicationOpenShowsEditor(void) {
    LRRecordingAppDelegate *delegate = [[LRRecordingAppDelegate alloc] init];
    BOOL hasLaunchHandlers =
        [delegate respondsToSelector:@selector(applicationShouldOpenUntitledFile:)] &&
        [delegate respondsToSelector:@selector(applicationOpenUntitledFile:)] &&
        [delegate respondsToSelector:@selector(applicationShouldHandleReopen:hasVisibleWindows:)];
    LRAssert(hasLaunchHandlers, "explicit application opens should have dedicated editor handlers");
    if (!hasLaunchHandlers) {
        return;
    }

    NSApplication *unusedApplication = nil;
    LRAssert([delegate applicationShouldOpenUntitledFile:unusedApplication],
             "a launch without a URL should request the configuration editor");
    LRAssert([delegate applicationOpenUntitledFile:unusedApplication],
             "opening the editor should handle the untitled launch request");
    LRAssert(delegate.editorRequested, "a plain application launch should show the editor");

    delegate.editorRequested = NO;
    BOOL useDefaultReopenBehavior =
        [delegate applicationShouldHandleReopen:unusedApplication hasVisibleWindows:NO];
    LRAssert(!useDefaultReopenBehavior, "the app should handle reopen events itself");
    LRAssert(delegate.editorRequested, "reopening the running app should show the editor");
}

int main(void) {
    @autoreleasepool {
        TestExplicitApplicationOpenShowsEditor();
        return LRFinishTests();
    }
}

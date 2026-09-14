#import <AppKit/AppKit.h>

#import "LRAppDelegate.h"
#import "LRBrowserLauncher.h"
#import "LRRouting.h"
#import "LRTestSupport.h"

@interface LRAppDelegate (LaunchLifecycleTesting)
- (void)openRuleEditor:(id)sender;
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender;
- (BOOL)applicationOpenUntitledFile:(NSApplication *)sender;
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender
                    hasVisibleWindows:(BOOL)hasVisibleWindows;
- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)URLs;
@end

@interface LRRecordingAppDelegate : LRAppDelegate
@property(nonatomic) BOOL editorRequested;
@end

@interface LRRecordingBrowserLauncher : NSObject <LRBrowserLaunching>
@property(nonatomic, strong) NSURL *openedURL;
@property(nonatomic, strong) LRBrowserTarget *target;
@end

@implementation LRRecordingBrowserLauncher
- (void)openURL:(NSURL *)URL
         target:(LRBrowserTarget *)target
     completion:(LRBrowserLaunchCompletion)completion {
    self.openedURL = URL;
    self.target = target;
    completion(nil);
}
@end

@implementation LRRecordingAppDelegate
- (void)openRuleEditor:(id)sender {
    (void)sender;
    self.editorRequested = YES;
}

static void TestFileOpenEventRoutesToFallback(void) {
    LRAppDelegate *delegate = [[LRAppDelegate alloc] init];
    LRRecordingBrowserLauncher *launcher = [[LRRecordingBrowserLauncher alloc] init];
    [delegate setValue:launcher forKey:@"browserLauncher"];
    NSURL *fileURL = [NSURL fileURLWithPath:@"/tmp/page.html"];

    [delegate application:nil openURLs:@[fileURL]];

    LRAssert([launcher.openedURL isEqual:fileURL],
             "a macOS file-open event should reach the browser launcher");
    LRAssert(launcher.target.application == LRBrowserApplicationSafari,
             "a file-open event should use the configured fallback target");
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
        TestFileOpenEventRoutesToFallback();
        return LRFinishTests();
    }
}

#import <AppKit/AppKit.h>
#import <CoreServices/CoreServices.h>

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
- (BOOL)shouldOpenRuleEditorForAppleEvent:(NSAppleEventDescriptor *)event;
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
@end

// LinkRouter inherits the public.html content type when it becomes the default
// browser, so Finder hands it local .html files. Forward them to the fallback
// browser rather than dropping them: an LSUIElement agent has no window in which
// a dropped file could ever become visible.
static void TestFileOpenEventReachesTheFallbackBrowser(void) {
    LRAppDelegate *delegate = [[LRAppDelegate alloc] init];
    LRRecordingBrowserLauncher *launcher = [[LRRecordingBrowserLauncher alloc] init];
    [delegate setValue:launcher forKey:@"browserLauncher"];
    NSURL *fileURL = [NSURL fileURLWithPath:@"/tmp/page.html"];

    [delegate application:nil openURLs:@[fileURL]];

    LRAssert([launcher.openedURL isEqual:fileURL],
             "a macOS file-open event should reach the browser launcher");
    LRAssert(launcher.target.application == LRBrowserApplicationSafari,
             "a file-open event should use the fallback browser");
}

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

static NSAppleEventDescriptor *OpenApplicationEventWithLaunchReason(AEKeyword launchReason) {
    NSAppleEventDescriptor *event = [NSAppleEventDescriptor
        appleEventWithEventClass:kCoreEventClass
                         eventID:kAEOpenApplication
                targetDescriptor:nil
                        returnID:kAutoGenerateReturnID
                   transactionID:kAnyTransactionID];
    [event setParamDescriptor:[NSAppleEventDescriptor descriptorWithEnumCode:launchReason]
                  forKeyword:keyAEPropData];
    return event;
}

static void TestLoginLaunchDoesNotOpenEditor(void) {
    LRAppDelegate *delegate = [[LRAppDelegate alloc] init];
    NSAppleEventDescriptor *loginEvent =
        OpenApplicationEventWithLaunchReason(keyAELaunchedAsLogInItem);
    NSAppleEventDescriptor *serviceEvent =
        OpenApplicationEventWithLaunchReason(keyAELaunchedAsServiceItem);

    LRAssert(![delegate shouldOpenRuleEditorForAppleEvent:loginEvent],
             "a login-item launch should start silently in the menu bar");
    LRAssert(![delegate shouldOpenRuleEditorForAppleEvent:serviceEvent],
             "a service-item launch should start silently in the menu bar");
    LRAssert([delegate shouldOpenRuleEditorForAppleEvent:nil],
             "an ordinary app launch should continue to open the editor");
}

int main(void) {
    @autoreleasepool {
        TestExplicitApplicationOpenShowsEditor();
        TestLoginLaunchDoesNotOpenEditor();
        TestFileOpenEventReachesTheFallbackBrowser();
        return LRFinishTests();
    }
}

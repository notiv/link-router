#import "LRBrowserLauncher.h"

#import <AppKit/AppKit.h>

#import "LRRouting.h"

static NSErrorDomain const LRBrowserLauncherErrorDomain = @"com.linkrouter.browser-launcher";

@implementation LRBrowserLauncher

- (void)openURL:(NSURL *)URL
         target:(LRBrowserTarget *)target
     completion:(LRBrowserLaunchCompletion)completion {
    NSError *error = nil;
    LRLaunchPlan *plan = [LRLaunchPlan planForURL:URL target:target error:&error];
    if (plan == nil) {
        completion(error);
        return;
    }
    NSURL *applicationURL =
        [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:plan.bundleIdentifier];
    if (applicationURL == nil) {
        NSString *message = [NSString stringWithFormat:@"%@ is not installed.", target.displayName];
        completion([NSError errorWithDomain:LRBrowserLauncherErrorDomain
                                       code:1
                                   userInfo:@{NSLocalizedDescriptionKey: message}]);
        return;
    }

    if (plan.mode == LRLaunchModeExecutable) {
        NSURL *executableURL = [NSBundle bundleWithURL:applicationURL].executableURL;
        if (executableURL == nil) {
            completion([NSError errorWithDomain:LRBrowserLauncherErrorDomain
                                           code:2
                                       userInfo:@{
                                           NSLocalizedDescriptionKey: @"Google Chrome has no executable."
                                       }]);
            return;
        }
        NSTask *task = [[NSTask alloc] init];
        task.executableURL = executableURL;
        task.arguments = plan.arguments;
        task.standardOutput = NSFileHandle.fileHandleWithNullDevice;
        task.standardError = NSFileHandle.fileHandleWithNullDevice;
        NSError *launchError = nil;
        [task launchAndReturnError:&launchError];
        completion(launchError);
        return;
    }

    NSWorkspaceOpenConfiguration *configuration = NSWorkspaceOpenConfiguration.configuration;
    configuration.activates = YES;
    configuration.addsToRecentItems = YES;
    [NSWorkspace.sharedWorkspace openURLs:@[URL]
                    withApplicationAtURL:applicationURL
                            configuration:configuration
                        completionHandler:^(NSRunningApplication *application, NSError *openError) {
                            (void)application;
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completion(openError);
                            });
                        }];
}

@end

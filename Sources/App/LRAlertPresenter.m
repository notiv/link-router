#import "LRAlertPresenter.h"

#import <AppKit/AppKit.h>

@implementation LRAlertPresenter

- (void)presentFailureWithTitle:(NSString *)title message:(NSString *)message {
    // LinkRouter is an LSUIElement agent, so the status menu is the only place a
    // failure would otherwise appear. Surface it where the click happened instead.
    [NSApp activateIgnoringOtherApps:YES];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = title;
    alert.informativeText = message;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

@end

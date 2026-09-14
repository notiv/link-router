#import <AppKit/AppKit.h>

#import "LRIconFactory.h"
#import "LRTestSupport.h"

static void TestMenuBarIconIsAReusableTemplateImage(void) {
    NSImage *icon = [LRIconFactory menuBarIcon];

    LRAssert(icon != nil, "the menu-bar icon should be created");
    LRAssert(NSEqualSizes(icon.size, NSMakeSize(18.0, 18.0)),
             "the menu-bar icon should use the standard 18-point canvas");
    LRAssert(icon.template, "the menu-bar icon should adapt to the menu-bar appearance");
    LRAssert(icon.accessibilityDescription.length > 0,
             "the menu-bar icon should have an accessibility description");
}

static void TestApplicationIconHasAHighResolutionRepresentation(void) {
    NSImage *icon = [LRIconFactory applicationIconWithSize:1024.0];
    NSBitmapImageRep *representation = nil;
    for (NSImageRep *candidate in icon.representations) {
        if ([candidate isKindOfClass:NSBitmapImageRep.class]) {
            representation = (NSBitmapImageRep *)candidate;
            break;
        }
    }

    LRAssert(icon != nil, "the application icon should be created");
    LRAssert(representation != nil, "the application icon should contain bitmap pixels");
    LRAssert(representation.pixelsWide == 1024 && representation.pixelsHigh == 1024,
             "the application icon should render at the requested resolution");
}

int main(void) {
    @autoreleasepool {
        TestMenuBarIconIsAReusableTemplateImage();
        TestApplicationIconHasAHighResolutionRepresentation();
        return LRFinishTests();
    }
}

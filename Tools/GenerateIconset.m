#import <AppKit/AppKit.h>

#import "LRIconFactory.h"

static BOOL LRWriteIcon(NSString *directory, NSString *name, CGFloat size, NSError **error) {
    NSImage *image = [LRIconFactory applicationIconWithSize:size];
    NSBitmapImageRep *representation = (NSBitmapImageRep *)image.representations.firstObject;
    NSData *PNGData = [representation representationUsingType:NSBitmapImageFileTypePNG
                                                   properties:@{}];
    NSString *path = [directory stringByAppendingPathComponent:name];
    return [PNGData writeToFile:path options:NSDataWritingAtomic error:error];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "Usage: GenerateIconset OUTPUT.iconset\n");
            return 64;
        }

        NSString *directory = [NSString stringWithUTF8String:argv[1]];
        NSArray<NSDictionary<NSString *, id> *> *icons = @[
            @{@"name": @"icon_16x16.png", @"size": @16},
            @{@"name": @"icon_16x16@2x.png", @"size": @32},
            @{@"name": @"icon_32x32.png", @"size": @32},
            @{@"name": @"icon_32x32@2x.png", @"size": @64},
            @{@"name": @"icon_128x128.png", @"size": @128},
            @{@"name": @"icon_128x128@2x.png", @"size": @256},
            @{@"name": @"icon_256x256.png", @"size": @256},
            @{@"name": @"icon_256x256@2x.png", @"size": @512},
            @{@"name": @"icon_512x512.png", @"size": @512},
            @{@"name": @"icon_512x512@2x.png", @"size": @1024},
        ];
        for (NSDictionary<NSString *, id> *icon in icons) {
            NSError *error = nil;
            if (!LRWriteIcon(directory,
                             icon[@"name"],
                             [icon[@"size"] doubleValue],
                             &error)) {
                fprintf(stderr, "%s\n", error.localizedDescription.UTF8String);
                return 1;
            }
        }
        return 0;
    }
}

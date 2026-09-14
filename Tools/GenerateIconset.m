#import <AppKit/AppKit.h>

#import "LRIconFactory.h"

static NSData *LRPNGData(CGFloat size) {
    NSImage *image = [LRIconFactory applicationIconWithSize:size];
    NSBitmapImageRep *representation = (NSBitmapImageRep *)image.representations.firstObject;
    return [representation representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
}

static void LRAppendUInt32(NSMutableData *data, uint32_t value) {
    const uint8_t bytes[] = {
        (uint8_t)(value >> 24),
        (uint8_t)(value >> 16),
        (uint8_t)(value >> 8),
        (uint8_t)value,
    };
    [data appendBytes:bytes length:sizeof(bytes)];
}

static void LRAppendChunk(NSMutableData *data, NSString *type, NSData *PNGData) {
    [data appendData:[type dataUsingEncoding:NSASCIIStringEncoding]];
    LRAppendUInt32(data, (uint32_t)PNGData.length + 8);
    [data appendData:PNGData];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "Usage: GenerateIconset OUTPUT.icns\n");
            return 64;
        }

        NSString *outputPath = [NSString stringWithUTF8String:argv[1]];
        NSArray<NSDictionary<NSString *, id> *> *icons = @[
            @{@"type": @"ic04", @"size": @16},
            @{@"type": @"ic05", @"size": @32},
            @{@"type": @"ic11", @"size": @32},
            @{@"type": @"ic12", @"size": @64},
            @{@"type": @"ic07", @"size": @128},
            @{@"type": @"ic08", @"size": @256},
            @{@"type": @"ic13", @"size": @256},
            @{@"type": @"ic09", @"size": @512},
            @{@"type": @"ic14", @"size": @512},
            @{@"type": @"ic10", @"size": @1024},
        ];
        NSMutableData *iconData = [NSMutableData dataWithBytes:"icns\0\0\0\0" length:8];
        NSMutableDictionary<NSNumber *, NSData *> *PNGDataBySize = [NSMutableDictionary dictionary];
        for (NSDictionary<NSString *, id> *icon in icons) {
            NSNumber *size = icon[@"size"];
            NSData *PNGData = PNGDataBySize[size];
            if (PNGData == nil) {
                PNGData = LRPNGData(size.doubleValue);
                if (PNGData == nil) {
                    fprintf(stderr, "Could not render the %g-pixel application icon.\n",
                            size.doubleValue);
                    return 1;
                }
                PNGDataBySize[size] = PNGData;
            }
            LRAppendChunk(iconData, icon[@"type"], PNGData);
        }

        NSMutableData *lengthData = [NSMutableData data];
        LRAppendUInt32(lengthData, (uint32_t)iconData.length);
        [iconData replaceBytesInRange:NSMakeRange(4, 4)
                            withBytes:lengthData.bytes
                               length:lengthData.length];

        NSError *error = nil;
        if (![iconData writeToFile:outputPath options:NSDataWritingAtomic error:&error]) {
            fprintf(stderr, "%s\n", error.localizedDescription.UTF8String);
            return 1;
        }
        return 0;
    }
}

#import "LRIconFactory.h"

static NSBitmapImageRep *LRBitmapRepresentation(NSUInteger pixelSize) {
    return [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                  pixelsWide:(NSInteger)pixelSize
                                                  pixelsHigh:(NSInteger)pixelSize
                                               bitsPerSample:8
                                             samplesPerPixel:4
                                                    hasAlpha:YES
                                                    isPlanar:NO
                                              colorSpaceName:NSCalibratedRGBColorSpace
                                                 bytesPerRow:0
                                                bitsPerPixel:0];
}

static void LRDrawRoutingMark(NSPoint origin, CGFloat size, NSColor *color) {
    CGFloat strokeWidth = size * 0.105;
    NSPoint junction = NSMakePoint(origin.x + size * 0.50, origin.y + size * 0.50);
    NSPoint bottom = NSMakePoint(origin.x + size * 0.50, origin.y + size * 0.20);
    NSPoint left = NSMakePoint(origin.x + size * 0.23, origin.y + size * 0.78);
    NSPoint right = NSMakePoint(origin.x + size * 0.77, origin.y + size * 0.78);

    NSBezierPath *path = [NSBezierPath bezierPath];
    path.lineWidth = strokeWidth;
    path.lineCapStyle = NSLineCapStyleRound;
    path.lineJoinStyle = NSLineJoinStyleRound;
    [path moveToPoint:bottom];
    [path lineToPoint:junction];
    [path curveToPoint:left
         controlPoint1:NSMakePoint(origin.x + size * 0.50, origin.y + size * 0.63)
         controlPoint2:NSMakePoint(origin.x + size * 0.36, origin.y + size * 0.70)];
    [path moveToPoint:junction];
    [path curveToPoint:right
         controlPoint1:NSMakePoint(origin.x + size * 0.50, origin.y + size * 0.63)
         controlPoint2:NSMakePoint(origin.x + size * 0.64, origin.y + size * 0.70)];
    [color setStroke];
    [path stroke];

    CGFloat terminalRadius = size * 0.085;
    for (NSValue *value in @[[NSValue valueWithPoint:bottom],
                              [NSValue valueWithPoint:left],
                              [NSValue valueWithPoint:right]]) {
        NSPoint terminal = value.pointValue;
        NSRect circle = NSMakeRect(terminal.x - terminalRadius,
                                   terminal.y - terminalRadius,
                                   terminalRadius * 2.0,
                                   terminalRadius * 2.0);
        [color setFill];
        [[NSBezierPath bezierPathWithOvalInRect:circle] fill];
    }
}

static NSImage *LRImageFromRepresentation(NSBitmapImageRep *representation, NSSize logicalSize) {
    representation.size = logicalSize;
    NSImage *image = [[NSImage alloc] initWithSize:logicalSize];
    [image addRepresentation:representation];
    return image;
}

@implementation LRIconFactory

+ (NSImage *)menuBarIcon {
    const NSUInteger pixelSize = 36;
    NSBitmapImageRep *representation = LRBitmapRepresentation(pixelSize);
    NSGraphicsContext *previousContext = NSGraphicsContext.currentContext;
    NSGraphicsContext.currentContext = [NSGraphicsContext
        graphicsContextWithBitmapImageRep:representation];
    [NSGraphicsContext saveGraphicsState];
    [NSColor.clearColor setFill];
    NSRectFill(NSMakeRect(0.0, 0.0, pixelSize, pixelSize));
    LRDrawRoutingMark(NSZeroPoint, pixelSize, NSColor.blackColor);
    [NSGraphicsContext restoreGraphicsState];
    NSGraphicsContext.currentContext = previousContext;

    NSImage *image = LRImageFromRepresentation(representation, NSMakeSize(18.0, 18.0));
    image.template = YES;
    image.accessibilityDescription = @"LinkRouter";
    return image;
}

+ (NSImage *)applicationIconWithSize:(CGFloat)size {
    NSUInteger pixelSize = (NSUInteger)llround(size);
    NSBitmapImageRep *representation = LRBitmapRepresentation(pixelSize);
    NSGraphicsContext *previousContext = NSGraphicsContext.currentContext;
    NSGraphicsContext.currentContext = [NSGraphicsContext
        graphicsContextWithBitmapImageRep:representation];
    [NSGraphicsContext saveGraphicsState];

    NSRect canvas = NSMakeRect(0.0, 0.0, size, size);
    [NSColor.clearColor setFill];
    NSRectFill(canvas);

    NSRect tileRect = NSInsetRect(canvas, size * 0.06, size * 0.06);
    NSBezierPath *tile = [NSBezierPath bezierPathWithRoundedRect:tileRect
                                                        xRadius:size * 0.22
                                                        yRadius:size * 0.22];
    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowColor = [NSColor colorWithWhite:0.0 alpha:0.28];
    shadow.shadowBlurRadius = size * 0.045;
    shadow.shadowOffset = NSMakeSize(0.0, -size * 0.025);
    [shadow set];
    NSGradient *background = [[NSGradient alloc]
        initWithStartingColor:[NSColor colorWithSRGBRed:0.12 green:0.46 blue:0.96 alpha:1.0]
                  endingColor:[NSColor colorWithSRGBRed:0.08 green:0.16 blue:0.49 alpha:1.0]];
    [background drawInBezierPath:tile angle:90.0];
    [NSGraphicsContext restoreGraphicsState];

    [NSGraphicsContext saveGraphicsState];
    CGFloat markSize = size * 0.62;
    CGFloat markOrigin = (size - markSize) / 2.0;
    LRDrawRoutingMark(NSMakePoint(markOrigin, markOrigin), markSize, NSColor.whiteColor);
    [NSGraphicsContext restoreGraphicsState];
    NSGraphicsContext.currentContext = previousContext;

    return LRImageFromRepresentation(representation, NSMakeSize(size, size));
}

@end

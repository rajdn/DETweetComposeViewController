//
//  DEEmbossedLabel.m
//  DETweeter
//
//  Copyright (c) 2011 Double Encore, Inc. All rights reserved.
//
//  Portions of this class are based on code by Marcel Ruegenberg.
//  https://github.com/mruegenberg/objc-utils/tree/master/UIKitAdditions
//

#import "DEEmbossedLabel.h"


@interface DEEmbossedLabel ()

@property (nonatomic, retain) NSAttributedString *attString;

- (void)embossedLabelInit;
- (void)drawTextInContext:(CGContextRef)context;
UIImage *blackSquare(CGSize size);
CGImageRef createMask(CGSize size, void (^shapeBlock)(void));
void drawWithInnerShadow(CGRect rect, 
                         CGSize shadowSize, 
                         CGFloat shadowBlur, 
                         UIColor *shadowColor, 
                         void (^drawJustShapeBlock)(void), 
                         void (^drawColoredShapeBlock)(void));

@end


@implementation DEEmbossedLabel

@synthesize attString = _attString;


#pragma mark - Setup & Teardown

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self embossedLabelInit];
    }
    return self;
}


- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self embossedLabelInit];
    }
    return self;
}


- (void)embossedLabelInit
{
    self.shadowColor = nil;  // We'll always draw a shadow. Don't bother the superclass with this.
}


#pragma mark - Superclass Overrides

- (void)drawTextInRect:(CGRect)rect
{    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, 0.0f, rect.size.height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    
    drawWithInnerShadow(rect,
                        CGSizeMake(0.0f, -1.0f),
                        1.0f,
                        [UIColor colorWithWhite:0.0f alpha:0.5f],
                        ^ {
                            CGContextRef blockContext = UIGraphicsGetCurrentContext();
                            [self drawTextInContext:blockContext];
                        },
                        ^ {
                            CGContextRef blockContext = UIGraphicsGetCurrentContext();
                            CGContextSetFillColorWithColor(blockContext, self.textColor.CGColor);
                            CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.0f), 1.0f, [UIColor colorWithWhite:1.0f alpha:0.5f].CGColor);
                            [self drawTextInContext:blockContext];
                        });    
}


#pragma mark - Public

- (void)drawTextInContext:(CGContextRef)context
{
    CGContextSelectFont(context, [self.font.fontName cStringUsingEncoding:[NSString defaultCStringEncoding]], self.font.pointSize, kCGEncodingMacRoman);
    CGRect textRect = [self textRectForBounds:self.bounds limitedToNumberOfLines:1];
    CGContextSetTextPosition(context, textRect.origin.x, textRect.origin.y + 5.0f);
    CGContextShowText(context, [self.text UTF8String], strlen([self.text UTF8String]));
}


UIImage *blackSquare(CGSize size)
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);  
    [[UIColor blackColor] setFill];
    CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, size.width, size.height));
    UIImage *blackSquare = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return blackSquare;
}


CGImageRef createMask(CGSize size, void (^shapeBlock)(void))
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);  
    shapeBlock();
    CGImageRef shape = [UIGraphicsGetImageFromCurrentImageContext() CGImage];
    UIGraphicsEndImageContext();  
    CGImageRef mask = CGImageMaskCreate(CGImageGetWidth(shape),
                                        CGImageGetHeight(shape),
                                        CGImageGetBitsPerComponent(shape),
                                        CGImageGetBitsPerPixel(shape),
                                        CGImageGetBytesPerRow(shape),
                                        CGImageGetDataProvider(shape), NULL, false);
    return mask;
}


void drawWithInnerShadow(CGRect rect, 
                         CGSize shadowSize, 
                         CGFloat shadowBlur, 
                         UIColor *shadowColor, 
                         void (^drawJustShapeBlock)(void), 
                         void (^drawColoredShapeBlock)(void))
{
    CGImageRef mask = createMask(rect.size, ^{
        [[UIColor blackColor] setFill];
        CGContextFillRect(UIGraphicsGetCurrentContext(), rect);
        [[UIColor whiteColor] setFill];
        drawJustShapeBlock();
    });
    
    CGImageRef cutoutRef = CGImageCreateWithMask(blackSquare(rect.size).CGImage, mask);
    CGImageRelease(mask);
    UIImage *cutout = [UIImage imageWithCGImage:cutoutRef scale:[[UIScreen mainScreen] scale] orientation:UIImageOrientationUp];
    CGImageRelease(cutoutRef);
    
    CGImageRef shadedMask = createMask(rect.size, ^{
        [[UIColor whiteColor] setFill];
        CGContextFillRect(UIGraphicsGetCurrentContext(), rect);
        CGContextSetShadowWithColor(UIGraphicsGetCurrentContext(), shadowSize, shadowBlur, [shadowColor CGColor]);
        [cutout drawAtPoint:CGPointZero];
    });
    
        // create negative image
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0);
    [shadowColor setFill];
    drawJustShapeBlock();
    UIImage *negative = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext(); 
    
    CGImageRef innerShadowRef = CGImageCreateWithMask(negative.CGImage, shadedMask);
    CGImageRelease(shadedMask);
    UIImage *innerShadow = [UIImage imageWithCGImage:innerShadowRef scale:[[UIScreen mainScreen] scale] orientation:UIImageOrientationUp];
    CGImageRelease(innerShadowRef);
    
        // draw actual image
    drawColoredShapeBlock();
    
        // finally apply shadow
    [innerShadow drawAtPoint:CGPointZero];
}


@end

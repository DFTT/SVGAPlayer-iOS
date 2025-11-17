//
//  SVGABitmapLayer.m
//  SVGAPlayer
//
//  Created by 崔明辉 on 2017/2/20.
//  Copyright © 2017年 UED Center. All rights reserved.
//

#import "SVGABitmapLayer.h"
#import "SVGABezierPath.h"
#import "SVGAVideoSpriteFrameEntity.h"

#import "UIImage+SVGAImprove.h"

#import <objc/runtime.h>
CGColorSpaceRef XYZY_CGColorSpaceGetDeviceRGB(void) {
    static CGColorSpaceRef space;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        space = CGColorSpaceCreateDeviceRGB();
    });
    return space;
}

CGImageRef XYZY_CGImageCreateDecodedCopy(CGImageRef imageRef) {
    if (!imageRef) return NULL;
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    if (width == 0 || height == 0) return NULL;
    
    //decode with redraw (may lose some precision)
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef) & kCGBitmapAlphaInfoMask;
    BOOL hasAlpha = NO;
    if (alphaInfo == kCGImageAlphaPremultipliedLast ||
        alphaInfo == kCGImageAlphaPremultipliedFirst ||
        alphaInfo == kCGImageAlphaLast ||
        alphaInfo == kCGImageAlphaFirst) {
        hasAlpha = YES;
    }
    // BGRA8888 (premultiplied) or BGRX8888
    // same as UIGraphicsBeginImageContext() and -[UIView drawRect:]
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host;
    bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst;
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, XYZY_CGColorSpaceGetDeviceRGB(), bitmapInfo);
    if (!context) return NULL;
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef); // decode
    CGImageRef newImage = CGBitmapContextCreateImage(context);
    CFRelease(context);
    return newImage;
}


CGImageRef XYZY_DecodeThumbnailFromData(NSData *data, CGSize pixelSize) {
    NSData *imgData = data;
    if (!imgData || imgData.length == 0) return NULL;

    NSDictionary *options = @{
        (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
        (NSString *)kCGImageSourceThumbnailMaxPixelSize : @(MAX(pixelSize.width, pixelSize.height)),
        (NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES
    };

    CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)imgData, NULL);
    if (!source) return NULL;

    CGImageRef thumbRef = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    CFRelease(source);
    return thumbRef;
}

CGImageRef XYZY_DecodeThumbnailFromCGImage(CGImageRef imageRef, CGFloat scale) {
    double srcW = (double)CGImageGetWidth(imageRef);
    double srcH = (double)CGImageGetHeight(imageRef);
    if (srcW == 0 || srcH == 0) return NULL;
    size_t width = (size_t)MAX(1, (int)floor(srcW * scale));
    size_t height = (size_t)MAX(1, (int)floor(srcH * scale));
    
    //decode with redraw (may lose some precision)
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef) & kCGBitmapAlphaInfoMask;
    BOOL hasAlpha = NO;
    if (alphaInfo == kCGImageAlphaPremultipliedLast ||
        alphaInfo == kCGImageAlphaPremultipliedFirst ||
        alphaInfo == kCGImageAlphaLast ||
        alphaInfo == kCGImageAlphaFirst) {
        hasAlpha = YES;
    }
    // BGRA8888 (premultiplied) or BGRX8888
    // same as UIGraphicsBeginImageContext() and -[UIView drawRect:]
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host;
    bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst;
    
    CGContextRef ctx = CGBitmapContextCreate(NULL,
                                             width,
                                             height,
                                             8,
                                             width * 4,
                                             XYZY_CGColorSpaceGetDeviceRGB(),
                                             bitmapInfo);
    if (!ctx) return NULL;

    CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), imageRef);

    CGImageRef scaledImageRef = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);

    return scaledImageRef;
}


@interface UIImage (XYZY__ImageCoder_)
- (UIImage *)x__getImageByDecoded:(CGFloat)scale;
@end
@implementation UIImage (XYZY__ImageCoder_)
- (UIImage *)x__getImageByDecoded:(CGFloat)scale {
    if (self.didDecodedForDisplay) return self;
    
    if (scale > 0 && scale < 1) {
        NSData *imgData = self.originImageData;
        if (imgData != nil && imgData.length > 0) {
            // 解码缩略图
            CGImageRef newImageRef = XYZY_DecodeThumbnailFromData(imgData,
                                                                  CGSizeMake(self.size.width * self.scale * scale,
                                                                             self.size.height * self.scale * scale));
            if (newImageRef) {
                UIImage *newImage = [[self.class alloc] initWithCGImage:newImageRef scale:self.scale orientation:self.imageOrientation];
                CGImageRelease(newImageRef);
                if (newImage) {
                    newImage.didDecodedForDisplay = YES;
                    newImage.keyName = self.keyName;
                    self.originImageData = nil; //释放
                    return newImage;
                }
            }
        }
        
        CGImageRef imageRef = self.CGImage;
        if (imageRef) {
            // 绘制缩略图
            CGImageRef newImageRef = XYZY_DecodeThumbnailFromCGImage(imageRef, scale);
            if (newImageRef) {
                UIImage *newImage = [[self.class alloc] initWithCGImage:newImageRef scale:self.scale orientation:self.imageOrientation];
                CGImageRelease(newImageRef);
                if (newImage) {
                    newImage.didDecodedForDisplay = YES;
                    newImage.keyName = self.keyName;
                    self.originImageData = nil; //释放
                    return newImage;
                }
            }
        }
    }
    
    // 普通解码
    CGImageRef imageRef = self.CGImage;
    if (imageRef) {
        CGImageRef newImageRef = XYZY_CGImageCreateDecodedCopy(imageRef);
        if (newImageRef) {
            UIImage *newImage = [[self.class alloc] initWithCGImage:newImageRef scale:self.scale orientation:self.imageOrientation];
            CGImageRelease(newImageRef);
            if (newImage) {
                newImage.didDecodedForDisplay = YES;
                newImage.keyName = self.keyName;
                self.originImageData = nil; //释放
                return newImage;
            }
        }
    }
    
    // decode failed, return self.
    return self;
}
@end



@implementation SVGABitmapLayer
{
    UIImage *_image;
        
    NSBlockOperation *_decodeOpt;
}

- (CGSize)imgSize {
    return _image.size;
}
- (NSString *)imageKeyname {
    return _image.keyName;
}

- (instancetype)initWithImage:(UIImage *)img {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor clearColor].CGColor;
        self.masksToBounds = NO;
        self.contentsGravity = kCAGravityResizeAspect;
        _image = img;
    }
    return self;
}

- (void)stepToFrame:(NSInteger)frame {
    if (self.contents != nil) {
        return ;
    }
    // 这里基本不会走到了, 预解码结束后会赋值图片显示, plauyer里如果预解码未完成会等待
#if DEBUG && DEBUG == 1
    if (_image.didDecodedForDisplay == NO) {
        NSLog(@"--- realtime decode frameIndex = %d ---", (int)frame);
    }
#endif
    self.contents = (__bridge id _Nullable)_image.CGImage;
    _image.didDecodedForDisplay = true;
    _image.originImageData = nil;
    
    // 取消
    [_decodeOpt cancel];
    _decodeOpt = nil;
}

- (NSBlockOperation *)preDecodeOperationIfNeed:(CGFloat)scale {
    if (self.contents != nil || _image.didDecodedForDisplay) {
        return nil;
    }
    if (_decodeOpt != nil && _decodeOpt.isExecuting) {
        return nil;
    }
#if DEBUG && DEBUG == 1
    if (!_image) {
        NSLog(@"--- 预解码失败  图片缺失 ---");
        return nil;
    }
#endif
    
    __weak typeof(self) weak_self = self;
    return _decodeOpt = [NSBlockOperation blockOperationWithBlock:^{
        __strong typeof(weak_self) strong_self = weak_self;
        if (!strong_self) {
            return ;
        }
        @autoreleasepool {
            UIImage *decodeImg = [strong_self->_image x__getImageByDecoded:scale];
            if (decodeImg != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (strong_self.contents == nil) {
                        strong_self->_image = decodeImg; // 覆盖
                        strong_self.contents = (__bridge id _Nullable)([decodeImg CGImage]);
                        decodeImg.didDecodedForDisplay = YES;
                        decodeImg.originImageData = nil;
                    }
                });
            }else {
                NSLog(@"--- 预解码失败  真·预解码失败 ---");
            }
        }
    }];
}

- (void)freeMemory {
    self.contents = nil;
}
@end


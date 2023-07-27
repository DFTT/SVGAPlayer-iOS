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

@interface UIImage (XYZY__ImageCoder_)
- (instancetype)xyzy_imageByDecoded;
@end
@implementation UIImage (XYZY__ImageCoder_)

- (instancetype)xyzy_imageByDecoded {
    if (self.xyzy_isDecodedForDisplay) return self;
    CGImageRef imageRef = self.CGImage;
    if (!imageRef) return self;
    CGImageRef newImageRef = XYZY_CGImageCreateDecodedCopy(imageRef);
    if (!newImageRef) return self;
    UIImage *newImage = [[self.class alloc] initWithCGImage:newImageRef scale:self.scale orientation:self.imageOrientation];
    CGImageRelease(newImageRef);
    if (!newImage) newImage = self; // decode failed, return self.
    newImage.xyzy_isDecodedForDisplay = YES;
    return newImage;
}
- (BOOL)xyzy_isDecodedForDisplay {
    if (self.images.count > 1) return YES;
    NSNumber *num = objc_getAssociatedObject(self, @selector(xyzy_isDecodedForDisplay));
    return [num boolValue];
}

- (void)setXyzy_isDecodedForDisplay:(BOOL)isDecodedForDisplay {
    objc_setAssociatedObject(self, @selector(xyzy_isDecodedForDisplay), @(isDecodedForDisplay), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end



@implementation SVGABitmapLayer
{
    UIImage *_originImage;
    
    UIImage * _Nullable _decodeImage;
    
    NSBlockOperation *_decodeOpt;
}

- (instancetype)initWithImage:(UIImage *)img {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor clearColor].CGColor;
        self.masksToBounds = NO;
        self.contentsGravity = kCAGravityResizeAspect;
        _originImage = img;
    }
    return self;
}

- (void)stepToFrame:(NSInteger)frame {
    if (self.contents != nil) {
        return ;
    }
    // 这里基本不会走到了, 预解码结束后会赋值图片显示, plauyer里如果预解码未完成会等待
#if DEBUG && DEBUG == 1
    if (_decodeImage == nil) {
        NSLog(@"--- realtime decode frameIndex = %d ---", (int)frame);
    }
#endif
    self.contents = (__bridge id _Nullable)(_decodeImage ? _decodeImage.CGImage : [_originImage CGImage]);
    
    // 取消
    [_decodeOpt cancel];
    _decodeOpt = nil;
    _decodeImage = nil;
}

- (NSBlockOperation *)preDecodeOperationIfNeed {
    if (self.contents != nil || _decodeImage != nil) {
        return nil;
    }
    if (_decodeOpt != nil && _decodeOpt.isExecuting) {
        return nil;
    }
#if DEBUG && DEBUG == 1
    if (!_originImage) {
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
            UIImage *decodeImg = strong_self->_originImage.xyzy_imageByDecoded;
            if (decodeImg != nil) {
                strong_self->_decodeImage = decodeImg;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (strong_self.contents == nil) {
                        strong_self.contents = (__bridge id _Nullable)([decodeImg CGImage]);
                        strong_self->_decodeImage = nil;
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
    _decodeImage = nil;
}
@end


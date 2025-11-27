//
//  UIImage+SVGAImprove.m
//  SVGAPlayer
//
//  Created by dadadongl on 2025/11/14.
//  Copyright © 2025 UED Center. All rights reserved.
//

#import "UIImage+SVGAImprove.h"
#import <objc/runtime.h>

@implementation UIImage (SVGAImprove)

- (NSString *)keyName {
    NSString *name = objc_getAssociatedObject(self, @selector(keyName));
    return name;
}

- (void)setKeyName:(NSString *)name {
    objc_setAssociatedObject(self, @selector(keyName), name, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


- (NSData *)originImageData {
    NSData *data = objc_getAssociatedObject(self, @selector(originImageData));
    return  data;
}

- (void)setOriginImageData:(NSData *)originImageData {
    objc_setAssociatedObject(self, @selector(originImageData), originImageData, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


- (BOOL)didDecodedForDisplay {
    NSNumber *num = objc_getAssociatedObject(self, @selector(didDecodedForDisplay));
    if ([num boolValue]) {
        return YES;
    }
    if (self.images.count > 1) return YES;
    return NO;
}

- (void)setDidDecodedForDisplay:(BOOL)didDecodedForDisplay {
    objc_setAssociatedObject(self, @selector(didDecodedForDisplay), @(didDecodedForDisplay), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

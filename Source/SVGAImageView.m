//
//  SVGAImageView.m
//  SVGAPlayer
//
//  Created by 崔明辉 on 2017/10/17.
//  Copyright © 2017年 UED Center. All rights reserved.
//

#import "SVGAImageView.h"
#import "SVGAParser.h"

static SVGAParser *sharedParser;

@implementation SVGAImageView
{
    NSString *_dataKey;
}

+ (void)load {
    sharedParser = [SVGAParser new];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _autoPlay = YES;
    }
    return self;
}


- (void)setImageName:(NSString *)imageName {
    _imageName = imageName;
    __weak typeof(self) weakSelf = self;
    if ([imageName hasPrefix:@"http://"] || [imageName hasPrefix:@"https://"]) {
        [sharedParser parseWithURL:[NSURL URLWithString:imageName] completionBlock:^(SVGAVideoEntity * _Nullable videoItem) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            if (![strongSelf.imageName isEqualToString:imageName]) {
                return;
            }
            [strongSelf setVideoItem:videoItem];
            if (strongSelf.autoPlay) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [strongSelf startAnimation];
                }];
            }
            if (strongSelf->_parseCompletion) {
                strongSelf->_parseCompletion(strongSelf);
            }
        } failureBlock:nil];
    }
    else {
        __weak typeof(self) weakSelf = self;
        [sharedParser parseWithNamed:imageName inBundle:nil completionBlock:^(SVGAVideoEntity * _Nonnull videoItem) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            
            if (![strongSelf.imageName isEqualToString:imageName]) {
                return;
            }
            [strongSelf setVideoItem:videoItem];
            if (strongSelf.autoPlay) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [strongSelf startAnimation];
                }];
            }
            if (strongSelf->_parseCompletion) {
                strongSelf->_parseCompletion(strongSelf);
            }
            
        } failureBlock:nil];
    }
}

- (void)setImageWithName:(NSString *)name {
    [self setImageName:name];
}

- (void)setImageData:(NSData *)imageData forKey:(NSString *)aKey {
    if (!imageData) {
        return;
    }
    _dataKey = aKey;
    __weak typeof(self) weakSelf = self;
    [sharedParser parseWithData:imageData cacheKey:aKey completionBlock:^(SVGAVideoEntity * _Nonnull videoItem) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        if (aKey && ![strongSelf->_dataKey isEqualToString:aKey]) {
            return;
        }
        [strongSelf setVideoItem:videoItem];
        if (strongSelf.autoPlay) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [strongSelf startAnimation];
            }];
        }
        if (strongSelf->_parseCompletion) {
            strongSelf->_parseCompletion(strongSelf);
        }
        
    } failureBlock:nil];
}

- (NSString *)curImageDataKey {
    return _dataKey;
}

- (void)cancelParseAndStop {
    _imageName = nil;
    _dataKey = nil;
    [self stopAnimation];
}

@end

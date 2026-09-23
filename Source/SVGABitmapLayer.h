//
//  SVGABitmapLayer.h
//  SVGAPlayer
//
//  Created by 崔明辉 on 2017/2/20.
//  Copyright © 2017年 UED Center. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SVGAVideoSpriteFrameEntity;

@interface SVGABitmapLayer : CALayer

- (instancetype)initWithImage:(UIImage *)img;
/// 图层建好后替换位图(动态图)。连同持有的原图一起换 —— 只换 contents 的话, freeMemory 后重新渲染会回到旧图
- (void)setImage:(UIImage *)img;

- (void)stepToFrame:(NSInteger)frame;

- (NSBlockOperation *)preDecodeOperationIfNeed:(CGFloat)scale;
- (void)freeMemory;

- (CGSize)imgSize;
- (NSString *)imageKeyname;
@end

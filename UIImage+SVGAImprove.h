//
//  UIImage+SVGAImprove.h
//  SVGAPlayer
//
//  Created by dadadongl on 2025/11/14.
//  Copyright © 2025 UED Center. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (SVGAImprove)

// 在原始svga配置文件中的名字 便于调试排查问题
@property (nonatomic, copy, nullable) NSString *keyName;

// 原始的图片数据, 为了缩略图使用, 图片显示/解码后 会释放掉
@property (nonatomic, strong, nullable) NSData *originImageData;

// 标记是否解码
@property (nonatomic, assign) BOOL didDecodedForDisplay;

@end

NS_ASSUME_NONNULL_END

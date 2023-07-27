//
//  SVGAPlayer.h
//  SVGAPlayer
//
//  Created by 崔明辉 on 16/6/17.
//  Copyright © 2016年 UED Center. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SVGAVideoEntity, SVGAPlayer;

@protocol SVGAPlayerDelegate <NSObject>

@optional
- (void)svgaPlayerDidFinishedAnimation:(SVGAPlayer *)player ;

- (void)svgaPlayer:(SVGAPlayer *)player didAnimatedToFrame:(NSInteger)frame;
- (void)svgaPlayer:(SVGAPlayer *)player didAnimatedToPercentage:(CGFloat)percentage;

- (void)svgaPlayerDidAnimatedToFrame:(NSInteger)frame API_DEPRECATED("Use svgaPlayer:didAnimatedToFrame: instead", ios(7.0, API_TO_BE_DEPRECATED));
- (void)svgaPlayerDidAnimatedToPercentage:(CGFloat)percentage API_DEPRECATED("Use svgaPlayer:didAnimatedToPercentage: instead", ios(7.0, API_TO_BE_DEPRECATED));

@end

typedef void(^SVGAPlayerDynamicDrawingBlock)(CALayer *contentLayer, NSInteger frameIndex);

@interface SVGAPlayer : UIView

@property (nonatomic, weak) id<SVGAPlayerDelegate> delegate;
@property (nonatomic, strong) SVGAVideoEntity *videoItem;
@property (nonatomic, assign) IBInspectable int loops;
@property (nonatomic, assign) IBInspectable BOOL clearsAfterStop;
@property (nonatomic, copy) NSString *fillMode;
@property (nonatomic, copy) NSRunLoopMode mainRunLoopMode;

// 增加的属性 标识动画中
@property (nonatomic, assign) BOOL isAnimating;
// 当动画中 图片帧 在后续播放不需要使用时, 会及时释放掉, 再次播放时会重新解码
// 某种程度上可以理解用时间换空间, 仅建议在 播放次数少 & 动画内存峰值极高 时开启
// default NO, 如果loops == 1自动开启
@property (nonatomic, assign) BOOL needTimelyReleaseMemory;
// 增加的属性 便于全屏动画的是适配
// 对于美术给到的固定尺寸动画, 在不同屏幕上难以完美适配(要么一个维度撑不满, 要么一个维度会被裁剪, 要么铺满会变形)
// 对于全屏动画 建议设置如下 既能保证撑满屏幕不被裁剪, 也能显示出动画videoSize窗口之外的内容, 避免一个维度无法撑满的留白
// player.frame = [UIScreen mainScreen].bounds;
// player.contentMode = UIViewContentModeScaleAspectFit;
// player.unableAnimationContentClip = YES;
@property (nonatomic, assign) BOOL unableAnimationContentClip;

- (void)startAnimation;
- (void)startAnimationWithRange:(NSRange)range reverse:(BOOL)reverse;
- (void)pauseAnimation;
- (void)stopAnimation;
- (void)clear; // 勿随意使用, 必要时请搭配stopAnimation使用
- (void)stepToFrame:(NSInteger)frame andPlay:(BOOL)andPlay;
- (void)stepToPercentage:(CGFloat)percentage andPlay:(BOOL)andPlay;

#pragma mark - Dynamic Object

- (void)setImage:(UIImage *)image forKey:(NSString *)aKey;
- (void)setImageWithURL:(NSURL *)URL forKey:(NSString *)aKey;
- (void)setImage:(UIImage *)image forKey:(NSString *)aKey referenceLayer:(CALayer *)referenceLayer; // deprecated from 2.0.1
- (void)setAttributedText:(NSAttributedString *)attributedText forKey:(NSString *)aKey;
- (void)setDrawingBlock:(SVGAPlayerDynamicDrawingBlock)drawingBlock forKey:(NSString *)aKey;
- (void)setHidden:(BOOL)hidden forKey:(NSString *)aKey;
- (void)clearDynamicObjects;

@end

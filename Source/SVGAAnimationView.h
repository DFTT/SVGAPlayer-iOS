//
//  SVGAAnimationView.h
//  SVGAPlayer
//
//  SVGAImageView 的替代品: 同样是"给个资源就自己取、解析、起播", 但结果一定有回调。
//  SVGAImageView 仍然保留, 两者可共存, 接入方按需逐步替换。
//

#import "SVGAPlayer.h"

NS_ASSUME_NONNULL_BEGIN

@class SVGAAnimationView;

/// parseCompletion 里 error 的 domain
extern NSErrorDomain const SVGAAnimationViewErrorDomain;

typedef NS_ERROR_ENUM(SVGAAnimationViewErrorDomain, SVGAAnimationViewErrorCode) {
    SVGAAnimationViewErrorCancelled     = -1, // 被新任务顶掉, 或调用方 cancelParseAndStop
    SVGAAnimationViewErrorInvalidParam  = -2, // key 为空 / data 不合法
    SVGAAnimationViewErrorParseFailed   = -3, // 取资源或解析失败, 原始 error 见 NSUnderlyingErrorKey
    SVGAAnimationViewErrorInvalidEntity = -4, // 解出来了但播不了: FPS == 0 或 frames == 0
};

/// 解析结束的回调, error 为空即成功 —— 回调发生时画面已经画好, autoPlay 的话也真的在播了,
/// 所以在这里 cancelParseAndStop / 开下一个任务都能立刻生效。
/// 播放结束/中断走 SVGAPlayerDelegate, 不在这里报
typedef void(^SVGAAnimationParseCompletion)(SVGAAnimationView *view, NSString *itemKey, NSError *_Nullable error);

/// 与 UIKit 一致, 所有方法须在主线程调用
@interface SVGAAnimationView : SVGAPlayer

/// 解析成功后自动起播, default YES
@property (nonatomic, assign) BOOL autoPlay;

/// 最后一次 play 设置的 key。play 一调用就更新, 不随解析成败或 cancel 改变
@property (nonatomic, readonly) NSString *itemKey;

/// aKey 兼作解析缓存的 key, 不能为空。
/// 停掉上一个动画 → 解析 → 起播 → 回调
- (void)playData:(NSData *)data forKey:(NSString *)aKey completion:(SVGAAnimationParseCompletion)comp;

/// name 是 http(s) 链接就先下载, 否则在 mainBundle 里找同名 .svga。
/// 停掉上一个动画 → 取资源 → 解析 → 起播 → 回调
- (void)playNamed:(NSString *)name completion:(SVGAAnimationParseCompletion)comp;

/// 取消解析并停止播放, 进行中的任务会收到 Cancelled
- (void)cancelParseAndStop;

@end

NS_ASSUME_NONNULL_END

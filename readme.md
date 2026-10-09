# SVGAPlayer-iOS

SVGA 动画的 iOS 播放库，在 [svga/SVGAPlayer-iOS](https://github.com/svga/SVGAPlayer-iOS) 基础上维护和扩展。

在保留原有解析与播放 API 的基础上，优化位图解码和内存使用，新增解析结果回调、播放中断通知及渲染适配能力。

## 安装

版本：**3.0.0** · 最低支持：**iOS 12.0**

```ruby
pod 'SVGAPlayer', :git => 'https://github.com/DFTT/SVGAPlayer-iOS.git', :tag => '3.0.0'
```

请指定本仓库地址；CocoaPods trunk 上的 `SVGAPlayer` 为上游版本。

## 快速使用

`SVGAAnimationView` 支持加载应用包中的动画、HTTP(S) URL 或二进制数据。

```objc
#import <SVGAPlayer/SVGAAnimationView.h>

SVGAAnimationView *player = [[SVGAAnimationView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
player.loops = 1;
[self.view addSubview:player];

[player playNamed:@"animation" completion:^(SVGAAnimationView *view, NSString *itemKey, NSError *error) {
    if (error != nil) {
        NSLog(@"SVGA load failed: %@", error);
    }
}];
```

其他加载方式：

```objc
[player playNamed:@"https://example.com/animation.svga" completion:completion];
[player playData:data forKey:@"animation-key" completion:completion];
[player cancelParseAndStop];
```

- `autoPlay` 默认为 `YES`。设为 `NO` 时仅预解析；需要显示首帧时，在成功回调中调用 `[view stepToFrame:0 andPlay:NO]`，稍后调用 `startAnimation` 播放。
- completion 报告解析成功、失败或取消；播放结束通过 `SVGAPlayerDelegate` 通知。解析期间需持有播放器。
- 新请求会停止当前动画并取消待完成的旧请求。取消不会终止底层下载或解析；相同 key 应对应相同资源。
- `SVGAAnimationView` 的所有方法应在主线程调用。

`SVGAPlayer`、`SVGAParser` 和 `SVGAImageView` 仍可使用。基础用法见 [上游文档](readme.zh.md)，安装信息与 API 以本分支为准。

## 主要扩展

| 能力 | 说明 |
| --- | --- |
| 位图解码优化 | 后台预解码，并按显示尺寸下采样 |
| 内存释放 | `needTimelyReleaseMemory` 开启后释放已过期的图层位图；`loops == 1` 时自动启用 |
| 可见性优化 | 默认跳过不可见播放器的逐帧渲染，继续推进播放与 delegate 回调；可通过 `disableVisibilityCheck` 关闭 |
| 解析结果 | `SVGAAnimationView` 提供成功、取消、参数错误、解析失败及无效资源回调 |
| 播放中断 | 可选 delegate 方法 `svgaPlayer:didInterruptWithReason:` 报告空资源、无效 FPS 或播放中移出父视图 |
| 裁剪控制 | `unableAnimationContentClip` 允许显示超出 `videoSize` 的内容，父视图裁剪仍然生效 |
| 音量控制 | `volume` 默认 `1.0`，范围 `0～1`（`0` 为静音），播放中修改立即生效，换资源或重播时保留设置 |
| 动态绘制 | 绘制回调提供当前帧的 `transform`、`alpha` 等信息，示例见 `TPSVGABridgeView` |

解析错误使用 `SVGAAnimationViewErrorDomain` 和 `SVGAAnimationViewErrorCode`；底层错误在存在时通过 `NSUnderlyingErrorKey` 提供。

临时降低音效音量，在主线程设置播放器属性即可（`SVGAAnimationView`、`SVGAImageView` 同样支持）：

```objc
float originalVolume = player.volume;
player.volume = 0.2f;
// 需要恢复时：
player.volume = originalVolume;
```

该属性只影响当前播放器的资源音频，不修改系统音量。超出范围的值会限制在 `0～1`，`NaN` 按静音处理。

## 兼容性与注意事项

- 相较上游，`SVGAPlayerDynamicDrawingBlock` 增加第三个参数 `SVGAVideoSpriteFrameEntity *frame`，使用该回调的代码需调整。
- `SVGAImageView` 保留原有接口；其 `parseCompletion` 仅报告成功。
- `setVideoItem:`、`startAnimation*`、`stepToFrame:andPlay:` 和 `stepToPercentage:andPlay:` 在主线程同步执行，后台调用异步投递到主队列。绘制回调可能在方法返回前触发，其余方法应在主线程调用。
- 主动停止或暂停不触发播放中断回调。`clear` 只清除画面，停止播放请使用 `stopAnimation`。
- `stepToFrame:andPlay:YES` 不重置循环计数；需要重新播放完整动画时使用 `startAnimation`。
- `SVGAAnimationView` 拒绝 FPS 或帧数为零的资源；直接使用 `SVGAPlayer` 时需自行确保资源和播放范围有效。

## 回归测试

安装依赖并启动 iOS 模拟器后运行：

```sh
bash Tests/run-regressions.sh booted
SVGA_TEST_CONFIGURATION=Release bash Tests/run-regressions.sh booted
```

覆盖音量控制、动态图文、定帧、循环、旧接口及示例资源。可将 `booted` 替换为模拟器 UDID，日志目录会在运行时输出。

## 许可证

本项目沿用上游的 [Apache License 2.0](LICENSE)。

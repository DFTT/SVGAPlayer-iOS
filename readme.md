# SVGAPlayer-iOS · DFTT fork

Fork 自 [svga/SVGAPlayer-iOS](https://github.com/svga/SVGAPlayer-iOS) v2.5.7，当前版本 3.0.0。

上游的渲染模型、文件格式与整体 API 形态保持不变。本分支的改动集中在三处：**降低大型动画的内存峰值与卡顿**、**让播放的异常终止可被上层观测**、**补充若干渲染适配能力**。

上游文档见 [readme.zh.md](readme.zh.md)。

---

## 接入

```ruby
pod 'SVGAPlayer', :git => 'https://github.com/DFTT/SVGAPlayer-iOS.git', :tag => '3.0.0'
```

CocoaPods trunk 上的 `SVGAPlayer` 属于上游，不指定 `:git` 拉到的是上游版本。最低支持 iOS 12.0。

---

## 一、内存与性能

### 位图预解码与按需下采样

上游在渲染当前帧时才解码位图，图片素材多的动画在起播瞬间会产生巨大的内存峰值并伴随明显卡顿。

本分支把解码搬到播放前一帧的后台队列，并按播放器的实际显示尺寸下采样：

```
drawScale = min(播放器像素尺寸 / videoItem.videoSize, 1.0)
```

即动画设计尺寸 340pt 而播放器只有 100pt 时，位图按约 0.88 倍解码而非原尺寸。`SVGAPlayer.next` 在预解码队列未清空时整帧跳过，保证画面不会出现未解码的空白。

### 及时释放已过期的图层位图

```objc
@property (nonatomic, assign) BOOL needTimelyReleaseMemory; // default NO
```

开启后，某个图层一旦越过它最后一次出现的帧就立即释放位图，再次播放时重新解码——以时间换空间。`loops == 1` 时自动开启。仅建议在**播放次数少且内存峰值极高**的场景使用。

### 不可见时跳过渲染

播放器自身或其任一祖先处于 `hidden`、`alpha ≈ 0`、不在 window 上、或 `bounds` 为空时，跳过每帧的图层刷新。

该优化只影响画面刷新，**不影响** `delegate` 回调、`loopCount` 推进与结束回调的时机。可关闭：

```objc
@property (nonatomic, assign) BOOL disableVisibilityCheck; // default NO（即默认开启优化）
```

---

## 二、播放状态可观测

### 中断回调

上游只有"正常播完"有回调。资源损坏、播放中被移出父视图等情况全部静默终止，依赖"播完再播下一个"的上层逻辑会永久卡住。

新增与 `svgaPlayerDidFinishedAnimation:` 互斥的中断回调，两者合起来覆盖播放器自行终止的全部路径：

```objc
typedef NS_ENUM(NSInteger, SVGAPlayerStopReason) {
    SVGAPlayerStopReasonInvalidEntity,  // videoItem 为 nil
    SVGAPlayerStopReasonInvalidFPS,     // videoItem.FPS == 0
    SVGAPlayerStopReasonDetached,       // 播放中被移出父视图
};

- (void)svgaPlayer:(SVGAPlayer *)player didInterruptWithReason:(SVGAPlayerStopReason)reason;
```

调用方主动 `stopAnimation` / `pauseAnimation` / `stepToFrame:andPlay:` / `clear` 不触发——自己停的自己知道。

> **关于 `Detached`**：`UIView.drawHierarchy(afterScreenUpdates: true)` 对不在 window 上的视图截图时，UIKit 会把它临时挪进 `_UISnapshotWindow` 再挪回来。这会触发 `willMoveToSuperview:nil`，动画就此永久停止且无人知晓。该终止本身不能省略（`CADisplayLink` 持有 target，`loops == 0` 的播放器全靠它回收），因此改为让它可被感知。

### SVGAAnimationView

新增播放器子类，把"取资源 → 解析 → 起播"收成一次调用，且**结果一定有回调**：

```objc
- (void)playNamed:(NSString *)name completion:(SVGAAnimationParseCompletion)comp;
- (void)playData:(NSData *)data forKey:(NSString *)aKey completion:(SVGAAnimationParseCompletion)comp;
- (void)cancelParseAndStop;

@property (nonatomic, assign) BOOL autoPlay;       // default YES
@property (nonatomic, readonly) NSString *itemKey; // 最后一次 play 设置的 key，不随解析成败或 cancel 改变
```

错误按场景分类，原始错误挂在 `NSUnderlyingErrorKey` 下：

| code | 含义 |
| --- | --- |
| `Cancelled` | 被新任务顶掉，或调用方 `cancelParseAndStop` |
| `InvalidParam` | key 为空 / data 不合法 |
| `ParseFailed` | 取资源或解析失败 |
| `InvalidEntity` | 解析成功但播不了（`FPS == 0` 或 `frames == 0`） |

语义保证：

- 同一个播放器上开新任务会**先停掉上一个动画**，旧任务的 completion 收到 `Cancelled`。停下来是否清空画面沿用 `clearsAfterStop`——设为 `NO` 时图层树保留，重播同一资源不会重建。
- completion 触发时画面已绘制完成，`autoPlay` 时动画已在播——因此在 completion 内 `cancelParseAndStop` 或开下一个任务都能立即生效。
- 与 UIKit 一致，所有方法须在主线程调用。

`SVGAImageView` 原样保留，两者可共存，便于渐进式替换。

### 起播链路同步化

上游 `setVideoItem:` 把建图层无条件投递到主队列，赋值返回时图层树尚未建立，其后的 `stopAnimation` / `clear` 也拦不住已入队的绘制——画面会在停止后被重新画出来。

本分支改为：主线程调用即同步完成，非主线程调用才回一趟主队列。`startAnimation` / `stepToFrame:andPlay:` 随之同步，返回时首帧已渲染、播放状态已落定。

新增状态位：

```objc
@property (nonatomic, assign) BOOL isAnimating;
```

### 解析失败不再被吞掉

`SVGAParser` 原有若干失败路径既不触发 `completionBlock` 也不触发 `failureBlock`（如 zlib 数据合法但 protobuf 解析失败、缓存目录中的 `movie.spec` 不是字典等），调用方永久等待。已全部补齐 `failureBlock`。

---

## 三、渲染适配

### 显示 videoSize 之外的内容

美术给定固定尺寸的动画在不同屏幕上难以完美适配：要么某个维度撑不满，要么被裁剪，要么铺满后变形。

```objc
@property (nonatomic, assign) BOOL unableAnimationContentClip; // default NO
```

全屏动画推荐配置，既撑满屏幕又不裁剪，同时显示 `videoSize` 窗口之外的内容：

```objc
player.frame = UIScreen.mainScreen.bounds;
player.contentMode = UIViewContentModeScaleAspectFit;
player.unableAnimationContentClip = YES;
```

### 动画图层驱动原生控件

`SVGAPlayerDynamicDrawingBlock` 增加第三个参数，回调中可拿到该帧的 `transform` 与 `alpha`，从而让原生控件（头像、文本等）严格跟随动画图层运动：

```objc
// 上游：^(CALayer *contentLayer, NSInteger frameIndex)
typedef void(^SVGAPlayerDynamicDrawingBlock)(CALayer *contentLayer,
                                             NSInteger frameIndex,
                                             SVGAVideoSpriteFrameEntity *frame);
```

用法参见示例工程中的 `TPSVGABridgeView`。

---

## 四、缺陷修复

- 依赖的 Protobuf 升到 3.23.0 后编译报错
- 下采样 scale 计算错误
- 音频播放失败
- `next` 中 `stopAnimation` 使 `CADisplayLink` 释放最后一个引用后，`self` 提前析构导致的野指针访问
- `p_shouldRenderNow` 祖先遍历的 `do-while` 在 `superview` 为 nil 时会先执行一次循环体
- 起播首帧的 `dynamicDrawingBlock` 里调用 `stopAnimation` 会被起播的后续步骤覆盖；在里面再次起播会挂上两个 `CADisplayLink`，动画以两倍速播放
- 图层建好后调用的 `setImage:forKey:` 只替换了显示内容：位图被及时释放后重新渲染，会变回素材里的原图

---

## 五、兼容性

| 项 | 说明 |
| --- | --- |
| 最低系统版本 | **iOS 7.0 → 12.0**。当前 Xcode 已移除 iOS 9 以下部署目标所需的 `libarclite` |
| `SVGAImageView` | 未改动 |
| `SVGAPlayer` | 仅新增属性与可选 delegate 方法，无删除，无签名变更 |
| `SVGAPlayerDynamicDrawingBlock` | **签名变更**，增加第三个参数。使用 `setDrawingBlock:forKey:` 的代码需要调整 |
| `svgaPlayer:didInterruptWithReason:` | `@optional`，不实现不影响原有行为 |

---

## 六、已知限制

- `SVGAAnimationView` 在解析途中被释放时，进行中的 completion 不会被调用。
- `frames == 0` 的资源、与 frames 无交集的 range 沿用上游行为：`loops > 0` 时很快回调 `svgaPlayerDidFinishedAnimation:`，`loops == 0` 时原地空转。`SVGAAnimationView` 会在解析后拦下 `frames == 0` 并报 `InvalidEntity`。
- `stepToFrame:andPlay:YES` 不重置 `loopCount`，在动画播完后调用会立即再次触发结束回调。
- 除 `SVGAPlayer` 的 `setVideoItem:` / `startAnimation*` / `stepToFrame:andPlay:` 沿用上游行为允许子线程调用外，其余方法须在主线程调用。

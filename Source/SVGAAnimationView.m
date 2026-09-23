//
//  SVGAAnimationView.m
//  SVGAPlayer
//

#import "SVGAAnimationView.h"
#import "SVGAParser.h"
#import "SVGAVideoEntity.h"

NSErrorDomain const SVGAAnimationViewErrorDomain = @"SVGAAnimationViewErrorDomain";

static SVGAParser *sharedParser;

static NSError *SVGAError(SVGAAnimationViewErrorCode code, NSString *desc, NSError *underlying) {
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:desc forKey:NSLocalizedDescriptionKey];
    if (underlying != nil) {
        info[NSUnderlyingErrorKey] = underlying;
    }
    return [NSError errorWithDomain:SVGAAnimationViewErrorDomain code:code userInfo:info];
}

@implementation SVGAAnimationView
{
    // "有一次解析在跑"这个状态本身, 值就是它的 key, nil 表示没有。
    // 解析异步返回时拿它比对, 对不上说明任务已被顶掉/取消; 对得上就立刻归零 —— 解析到此结束
    NSString *_parsingItemKey;
    SVGAAnimationParseCompletion _currentBlock;
}
@synthesize itemKey = _itemKey; // 最后一次 play 设置的 key

+ (void)load {
    sharedParser = [SVGAParser new];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _itemKey = @"";
        _autoPlay = YES;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _itemKey = @"";
        _autoPlay = YES;
    }
    return self;
}

#pragma mark - 任务: 开始 → 解析返回 → 结束

/// 登记新任务, 返回"把旧任务以取消收尾"的 block。
/// 调用方要在本任务的状态全部落定后才执行它: 旧回调里可能又开一个任务, 早执行的话本任务后续的
/// 验参失败/起解析就会落到那个新任务头上
- (dispatch_block_t)p_beginTaskWithKey:(NSString *)key completion:(SVGAAnimationParseCompletion)comp {
    SVGAAnimationParseCompletion oldBlk = _currentBlock;
    NSString *oldKey = _itemKey ?: @"";

    // 新任务一来就停掉上一个: 新资源解析要时间(URL 还得先下载), 不停的话调用方看到的是
    // "我明明已经换了一个, 屏幕上还是老的"。
    // 停下来要不要清画面由 clearsAfterStop 决定, 这里不越权 —— 顺带地, clearsAfterStop = NO 时
    // 图层树保留着, 重播同一个资源会命中 setVideoItem: 的复用快路径, 不必重建
    [self stopAnimation];

    _itemKey = key ?: @"";
    _parsingItemKey = _itemKey;
    _currentBlock = [comp copy];

    return ^{
        if (oldBlk) {
            oldBlk(self, oldKey, SVGAError(SVGAAnimationViewErrorCancelled, @"被新任务取消", nil));
        }
    };
}

/// 解析异步返回了
- (void)p_handleParseResult:(SVGAVideoEntity *)videoItem error:(NSError *)error forKey:(NSString *)key {
    if (![_parsingItemKey isEqualToString:key]) {
        return; // 任务已被顶掉 / 取消
    }
    _parsingItemKey = nil;

    if (videoItem == nil || error != nil) {
        [self p_finishWithError:SVGAError(SVGAAnimationViewErrorParseFailed,
                                          error.localizedDescription ?: @"解析失败", error)];
        return;
    }
    if (videoItem.FPS == 0 || videoItem.frames == 0) {
        // 解出来也播不了: 放进 displayLink 只会得到一个永远不推进的动画
        [self p_finishWithError:SVGAError(SVGAAnimationViewErrorInvalidEntity, @"videoItem 的 FPS/frames 为 0", nil)];
        return;
    }

    // setVideoItem / startAnimation 都是同步的, 所以回调发出去时画面和播放状态已经落定
    SVGAAnimationParseCompletion mine = _currentBlock;
    [self setVideoItem:videoItem];
    if (self.autoPlay) {
        [self startAnimation];
    }
    // startAnimation → update 会同步跑业务的 dynamicDrawingBlock, 业务可能在里面就换了资源/取消了,
    // 本任务已被收尾, 再报成功就错报给了新任务。只比 block 不够: 两次都传 nil 或传同一个 block 时相等,
    // 所以还要看有没有新任务在解析
    if (_parsingItemKey == nil && _currentBlock == mine) {
        [self p_finishWithError:nil];
    }
}

/// 结束并回调。先取出再清空、最后才回调: 调用方可能在回调里就开下一个任务
- (void)p_finishWithError:(NSError *)err {
    SVGAAnimationParseCompletion blk = _currentBlock;
    NSString *key = _itemKey ?: @"";
    _parsingItemKey = nil; // 验参失败那条路压根没启动解析, 也要归零
    _currentBlock = nil;
    if (blk) {
        blk(self, key, err);
    }
}

#pragma mark - 对外

- (void)playNamed:(NSString *)name completion:(SVGAAnimationParseCompletion)comp {
    dispatch_block_t cancelOld = [self p_beginTaskWithKey:name completion:comp];
    if (name.length == 0) {
        [self p_finishWithError:SVGAError(SVGAAnimationViewErrorInvalidParam, @"无效的name", nil)];
    } else {
        // name 非空, 和 _parsingItemKey 一定相等 —— 下面的回调靠这个比对任务
        __weak typeof(self) weakSelf = self; // self 没了就是给 nil 发消息, 不用再判空
        void (^onOK)(SVGAVideoEntity *) = ^(SVGAVideoEntity *item) {
            [weakSelf p_handleParseResult:item error:nil forKey:name];
        };
        void (^onErr)(NSError *) = ^(NSError *error) {
            [weakSelf p_handleParseResult:nil error:error forKey:name];
        };
        if ([name hasPrefix:@"http://"] || [name hasPrefix:@"https://"]) {
            [sharedParser parseWithURL:[NSURL URLWithString:name] completionBlock:onOK failureBlock:onErr];
        } else {
            [sharedParser parseWithNamed:name inBundle:nil completionBlock:onOK failureBlock:onErr];
        }
    }
    cancelOld();
}

- (void)playData:(NSData *)data forKey:(NSString *)aKey completion:(SVGAAnimationParseCompletion)comp {
    dispatch_block_t cancelOld = [self p_beginTaskWithKey:aKey completion:comp];
    // aKey 也要验: 它是 parser 的 cacheKey(传 nil 会在 NSMapTable 那里抛), 而且下面的回调拿它
    // 比对任务 —— 空 key 比不上任何东西, 调用方会永远等不到 comp
    if (aKey.length == 0 || data.length < 4) {
        [self p_finishWithError:SVGAError(SVGAAnimationViewErrorInvalidParam,
                                          aKey.length == 0 ? @"无效的aKey" : @"无效的data", nil)];
    } else {
        __weak typeof(self) weakSelf = self;
        [sharedParser parseWithData:data cacheKey:aKey completionBlock:^(SVGAVideoEntity *item) {
            [weakSelf p_handleParseResult:item error:nil forKey:aKey];
        } failureBlock:^(NSError *error) {
            [weakSelf p_handleParseResult:nil error:error forKey:aKey];
        }];
    }
    cancelOld();
}

- (void)cancelParseAndStop {
    [self stopAnimation];
    // p_finishWithError: 会把 _parsingItemKey 归零, 进行中的解析回调回来就会自己作废
    [self p_finishWithError:SVGAError(SVGAAnimationViewErrorCancelled, @"主动取消", nil)];
}

@end

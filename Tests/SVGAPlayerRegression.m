// 独立模拟器回归检查，运行方式见 run-regressions.sh。Release 构建也必须执行断言。
#undef NDEBUG
#include <assert.h>
#include <math.h>
#import <UIKit/UIKit.h>
#import "SVGAPlayer.h"
#import "SVGAParser.h"
#import "SVGAImageView.h"
#import "SVGAVideoEntity.h"
#import "SVGAContentLayer.h"
#import "SVGABitmapLayer.h"
#import "SVGAAudioLayer.h"
#import "SVGAAudioEntity.h"

@interface SVGAPlayer (Regression)
- (void)next;
@end

static void drain(void) {
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

static UIImage *image(UIColor *color) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(32, 32), NO, 1);
    [color setFill];
    UIRectFill(CGRectMake(0, 0, 32, 32));
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

static SVGAVideoEntity *movie(NSArray<NSString *> *keys, NSDictionary *images) {
    NSMutableArray *frames = [NSMutableArray array];
    for (int i = 0; i < 100; i++) {
        [frames addObject:@{@"alpha": @1, @"layout": @{@"x": @0, @"y": @0, @"width": @32, @"height": @32}}];
    }
    NSMutableArray *sprites = [NSMutableArray array];
    for (NSString *key in keys) [sprites addObject:@{@"imageKey": key, @"frames": frames}];
    NSDictionary *json = @{@"movie": @{@"fps": @20, @"frames": @100,
                                     @"viewBox": @{@"width": @100, @"height": @100}}, @"sprites": sprites};
    SVGAVideoEntity *result = [[SVGAVideoEntity alloc] initWithJSONObject:json cacheDir:@""];
    [result resetSpritesWithJSONObject:json];
    [result setValue:images forKey:@"images"];
    return result;
}

static SVGAPlayer *player(void) {
    return [[SVGAPlayer alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
}

static NSArray<SVGAContentLayer *> *layers(SVGAPlayer *p) { return [p valueForKey:@"contentLayers"]; }
static CADisplayLink *displayLinkOf(SVGAPlayer *p) { return [p valueForKey:@"displayLink"]; }
static NSInteger frame(SVGAPlayer *p) { return [[p valueForKey:@"currentFrame"] integerValue]; }

static void volumeRegression(void) {
    // 一秒静音 PCM WAV，使用真实 AVAudioPlayer，不依赖示例资源是否带音频。
    const unsigned char header[] = {
        'R','I','F','F', 0xa4,0x3e,0,0, 'W','A','V','E',
        'f','m','t',' ', 16,0,0,0, 1,0, 1,0, 0x40,0x1f,0,0,
        0x80,0x3e,0,0, 2,0, 16,0, 'd','a','t','a', 0x80,0x3e,0,0
    };
    NSMutableData *audio = [NSMutableData dataWithBytes:header length:sizeof(header)];
    [audio increaseLengthBy:16000];
    SVGAVideoEntity *video = movie(@[], @{});
    NSMutableArray *items = [NSMutableArray array];
    for (int i = 0; i < 2; i++) {
        SVGAAudioEntity *item = [SVGAAudioEntity new];
        [item setValue:@"sound" forKey:@"audioKey"];
        [item setValue:@99 forKey:@"endFrame"];
        [items addObject:item];
    }
    [video setValue:items forKey:@"audios"];
    [video setValue:@{@"sound": audio} forKey:@"audiosData"];
    SVGAPlayer *p = player();
    assert(p.volume == 1.0f);
    p.volume = 0.2f;
    // 覆盖加载前配置、已加载配置，以及清理后重建音频图层。
    for (int phase = 0; phase < 3; phase++) {
        assert(p.volume == 0.2f);
        if (phase < 2) p.videoItem = video;
        [p startAnimation];
        displayLinkOf(p).paused = YES;
        NSArray<SVGAAudioLayer *> *audioLayers = [p valueForKey:@"audioLayers"];
        assert(audioLayers.count == 2);
        for (SVGAAudioLayer *layer in audioLayers) {
            assert(layer.audioPlayer && layer.audioPlaying);
            assert(fabsf(layer.audioPlayer.volume - 0.2f) < 0.001f);
        }
        const float values[] = {0.4f, 0.0f, 1.0f, -1.0f, 2.0f, NAN};
        const float expected[] = {0.4f, 0.0f, 1.0f, 0.0f, 1.0f, 0.0f};
        for (int i = 0; i < 6; i++) {
            p.volume = values[i];
            assert(p.volume == expected[i]);
            for (SVGAAudioLayer *layer in audioLayers) {
                assert(fabsf(layer.audioPlayer.volume - expected[i]) < 0.001f);
            }
        }
        p.volume = 0.2f;
        [p stopAnimation];
    }
    puts("PASS audio volume defaults, live updates, bounds, resource reload and restart");
}

static void textRegression(void) {
    UIImage *original = image(UIColor.blueColor);
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.alignment = NSTextAlignmentCenter;
    style.lineBreakMode = NSLineBreakByTruncatingTail;
    NSAttributedString *text = [[NSAttributedString alloc] initWithString:@"Hello"
        attributes:@{NSParagraphStyleAttributeName: style, NSFontAttributeName: [UIFont systemFontOfSize:12]}];
    // 配置发生在赋值前、赋值后、已经定帧之后，结果都应覆盖每个同名图层。
    for (int phase = 0; phase < 3; phase++) {
        SVGAPlayer *p = player();
        if (phase == 0) [p setAttributedText:text forKey:@"head"];
        p.videoItem = movie(@[@"head", @"head", @"other"], @{@"head": original, @"other": original});
        if (phase == 2) [p stepToFrame:5 andPlay:NO];
        if (phase != 0) [p setAttributedText:text forKey:@"head"];
        for (int update = 0; update < 2; update++) {
            NSAttributedString *expected = update == 0 ? text : [[NSAttributedString alloc] initWithString:@"Bye"];
            if (update) [p setAttributedText:expected forKey:@"head"];
            int count = 0;
            for (SVGAContentLayer *layer in layers(p)) {
                if ([layer.imageKey isEqualToString:@"other"]) { assert(layer.textLayer == nil); continue; }
                assert([layer.textLayer.string isEqual:expected]);
                assert(layer.textLayer.bounds.size.width > 0);
                assert(layer.textLayer.contentsScale == UIScreen.mainScreen.scale);
                assert([layer.textLayer.truncationMode isEqualToString:kCATruncationEnd]);
                count++;
            }
            assert(count == 2);
        }
        [p stopAnimation];
    }
    puts("PASS dynamic text before/after assignment, repeated keys and updates");
}

static void imageRegression(void) {
    UIImage *original = image(UIColor.blueColor), *replacement = image(UIColor.redColor);
    NSArray *cases = @[@[@"head", @"head"], @[@"head.matte", @"head"],
                      @[@"user.avatar.png", @"user.avatar"], @[@"head.matte", @"head.matte"]];
    for (NSArray *keys in cases) {
        for (int missing = 0; missing < 2; missing++) {
            for (int phase = 0; phase < 3; phase++) {
                // 完整 .matte key 原有契约是更新已建图层；保留该用法，不扩展缓存 key 语义。
                if (phase == 0 && [keys[1] hasSuffix:@".matte"]) continue;
                SVGAPlayer *p = player();
                if (phase == 0) [p setImage:replacement forKey:keys[1]];
                p.videoItem = movie(@[keys[0]], missing ? @{} : @{[keys[0] stringByDeletingPathExtension]: original});
                if (phase == 2) [p stepToFrame:5 andPlay:NO];
                SVGAContentLayer *layer = layers(p).firstObject;
                CATextLayer *overlay = [CATextLayer layer];
                [layer addSublayer:overlay];
                if (phase != 0) [p setImage:replacement forKey:keys[1]];
                [p stepToFrame:0 andPlay:NO];
                assert(layer.bitmapLayer.contents == (__bridge id)replacement.CGImage);
                assert(layer.sublayers.firstObject == layer.bitmapLayer);
                assert(layer.sublayers.lastObject == overlay);
                assert(CGRectEqualToRect(layer.bitmapLayer.frame, layer.bounds));
                [layer.bitmapLayer freeMemory];
                [layer.bitmapLayer stepToFrame:0];
                assert(layer.bitmapLayer.contents == (__bridge id)replacement.CGImage);
                [p stopAnimation];
            }
        }
    }
    puts("PASS dynamic image keys, missing bitmaps, stacking, sizing and memory release");
}

static void percentageRegression(void) {
    SVGAPlayer *p = player();
    SVGAVideoEntity *video = movie(@[], @{});
    // 确保主队列暂不处理赋值，复现后台换资源后过早读取 frames 的问题。
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        assert(!NSThread.isMainThread);
        p.videoItem = video;
        [p stepToPercentage:0.5 andPlay:NO];
        dispatch_semaphore_signal(done);
    });
    long waited = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    assert(waited == 0);
    __block BOOL flushed = NO;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{ flushed = YES; }];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while (!flushed && deadline.timeIntervalSinceNow > 0) drain();
    assert(flushed && frame(p) == 50 && !p.isAnimating);
    [p stepToPercentage:1 andPlay:NO];
    assert(frame(p) == 99);
    [p stepToPercentage:0 andPlay:YES];
    assert(frame(p) == 0 && p.isAnimating && displayLinkOf(p));
    [p stopAnimation];
    puts("PASS background assignment + percentage seek and endpoint seeks");
}

@interface RegressionDelegate : NSObject <SVGAPlayerDelegate>
@property int finishes;
@property int ticks;
@end
@implementation RegressionDelegate
- (void)svgaPlayerDidFinishedAnimation:(SVGAPlayer *)p { self.finishes++; }
- (void)svgaPlayer:(SVGAPlayer *)p didAnimatedToFrame:(NSInteger)f { self.ticks++; }
@end

static void playbackRegression(void) {
    SVGAPlayer *p = player();
    p.videoItem = movie(@[@"head"], @{@"head": image(UIColor.blueColor)});
    p.disableVisibilityCheck = YES;
    p.clearsAfterStop = NO;
    p.loops = 2;
    RegressionDelegate *observer = [RegressionDelegate new];
    p.delegate = observer;
    for (int reverse = 0; reverse < 2; reverse++) {
        observer.finishes = observer.ticks = 0;
        p.fillMode = reverse ? @"Backward" : @"Forward";
        [p startAnimationWithRange:NSMakeRange(10, 3) reverse:reverse];
        displayLinkOf(p).paused = YES; // 手动推进，避免显示刷新率和测试机器负载影响结果。
        for (int i = 0; i < 6; i++) {
            [(NSOperationQueue *)[p valueForKey:@"preDecodeQueue"] waitUntilAllOperationsAreFinished];
            drain();
            [p next];
        }
        assert(observer.finishes == 1 && observer.ticks == 5);
        assert(frame(p) == (reverse ? 10 : 12));
        assert(!displayLinkOf(p) && !p.isAnimating);
    }
    [p stepToFrame:37 andPlay:YES];
    assert(frame(p) == 37 && displayLinkOf(p) && p.isAnimating);
    [p pauseAnimation];
    assert(!displayLinkOf(p) && !p.isAnimating && layers(p).count == 1);
    p.clearsAfterStop = YES;
    [p stopAnimation];
    [p startAnimation];
    assert(frame(p) == 0 && layers(p).count == 1 && displayLinkOf(p));
    [p stopAnimation];
    drain();
    assert(!displayLinkOf(p) && !p.isAnimating);
    __weak SVGAPlayer *weak = p;
    [p setDrawingBlock:^(CALayer *layer, NSInteger idx, SVGAVideoSpriteFrameEntity *item) {
        [weak stopAnimation];
    } forKey:@"head"];
    [p startAnimation];
    drain();
    assert(!displayLinkOf(p) && !p.isAnimating);
    puts("PASS loops, reverse, fill modes, pause, restart and stop during first drawing");
}

static void legacyImageViewRegression(void) {
    UIImage *replacement = image(UIColor.redColor);
    SVGAVideoEntity *video = movie(@[@"head", @"head", @"head.matte"], @{@"head": image(UIColor.blueColor)});
    NSString *key = NSUUID.UUID.UUIDString;
    [video saveCache:key];
    SVGAImageView *view = [[SVGAImageView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    view.autoPlay = YES;
    NSAttributedString *text = [[NSAttributedString alloc] initWithString:@"Legacy"];
    __block int callbacks = 0;
    view.parseCompletion = ^(SVGAImageView *parsed) {
        callbacks++;
        [parsed setImage:replacement forKey:@"head"];
        [parsed setAttributedText:text forKey:@"head"];
    };
    [view setImageData:[@"cache hit" dataUsingEncoding:NSUTF8StringEncoding] forKey:key];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while (!view.isAnimating && deadline.timeIntervalSinceNow > 0) drain();
    assert(callbacks == 1 && view.isAnimating && layers(view).count == 3);
    for (SVGAContentLayer *layer in layers(view)) {
        assert(layer.bitmapLayer.contents == (__bridge id)replacement.CGImage);
        if ([layer.imageKey isEqualToString:@"head"]) assert([layer.textLayer.string isEqual:text]);
    }
    [view cancelParseAndStop];
    assert(!view.isAnimating && !displayLinkOf(view));
    puts("PASS legacy SVGAImageView parse callback configuration and autoplay");
}

static void sampleRegression(NSString *directory) {
    SVGAParser *parser = [SVGAParser new];
    NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL];
    assert(names.count > 0);
    int count = 0;
    for (NSString *name in names) {
        if (![name hasSuffix:@".svga"]) continue;
        __block SVGAVideoEntity *video = nil;
        __block BOOL done = NO;
        [parser parseWithData:[NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:name]]
                    cacheKey:[@"regression-" stringByAppendingString:NSUUID.UUID.UUIDString]
             completionBlock:^(SVGAVideoEntity *item) { video = item; done = YES; }
                failureBlock:^(NSError *error) { NSLog(@"%@ failed: %@", name, error); done = YES; }];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
        while (!done && deadline.timeIntervalSinceNow > 0) drain();
        assert(done && video && video.FPS > 0 && video.frames > 0);
        if ([name isEqualToString:@"rose_2.0.0.svga"]) {
            SVGAPlayer *p = player();
            p.videoItem = video;
            NSAttributedString *text = [[NSAttributedString alloc] initWithString:@"Review"];
            [p setAttributedText:text forKey:@"01"];
            int matches = 0;
            for (SVGAContentLayer *layer in layers(p)) if ([layer.imageKey isEqualToString:@"01"]) {
                assert([layer.textLayer.string isEqual:text]);
                matches++;
            }
            assert(matches == 3);
            [p stopAnimation];
        }
        count++;
    }
    printf("PASS %d real samples and rose repeated-key text\n", count);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        assert(argc == 2 && NSThread.isMainThread);
        volumeRegression();
        textRegression();
        imageRegression();
        percentageRegression();
        playbackRegression();
        legacyImageViewRegression();
        sampleRegression([NSString stringWithUTF8String:argv[1]]);
        puts("ALL REGRESSIONS PASSED");
    }
    return 0;
}

//
//  ViewController.m
//  SVGAPlayer
//
//  Created by 崔明辉 on 16/6/17.
//  Copyright © 2016年 UED Center. All rights reserved.
//

#import "ViewController.h"
#import "SVGA.h"
#import "SVGAContentLayer.h"
#import "SVGAPlayer-Swift.h"

@interface ViewController ()<SVGAPlayerDelegate>
{
    TestContainerView *_testView;
}
@property (weak, nonatomic) IBOutlet SVGAPlayer *aPlayer;
@property (weak, nonatomic) IBOutlet UISlider *aSlider;
@property (weak, nonatomic) IBOutlet UIButton *onBeginButton;

@end

@implementation ViewController

static SVGAParser *parser;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _testView = [[TestContainerView alloc] initWithFrame:CGRectMake(20, 100, 200, 200)];
    [self.view addSubview:_testView];
    [_testView run];
    
    self.aPlayer.delegate = self;
    self.aPlayer.loops = 1;
    self.aPlayer.clearsAfterStop = YES;
    self.aPlayer.contentMode = UIViewContentModeScaleAspectFill;
    self.aPlayer.layer.borderWidth = 1;
    self.aPlayer.layer.borderColor = UIColor.redColor.CGColor;
    
    UIView *vvvvvv = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
    vvvvvv.backgroundColor = [UIColor.redColor colorWithAlphaComponent:0.7];
    [self.aPlayer addSubview:vvvvvv];
    
    
    [self.aPlayer setDrawingBlock:^(CALayer *contentLayer, NSInteger frameIndex, SVGAVideoSpriteFrameEntity *frameItem) {
        if (contentLayer.isHidden || frameItem.alpha <= 0.0) {
            vvvvvv.hidden = YES;
            return;
        }
        vvvvvv.hidden = NO;

        // 1) 还原旋转/缩放:只取线性部分(平移交给 center,否则会和 center 重复叠加导致错位)
        //    自身 transform 的旋转/缩放,再叠上 drawLayer(设计坐标系→播放器坐标系)的缩放
        CGAffineTransform t = frameItem.transform;
        t.tx = 0; t.ty = 0;
        CGAffineTransform p = contentLayer.superlayer.affineTransform; // superlayer 即 drawLayer
        p.tx = 0; p.ty = 0;
        t = CGAffineTransformConcat(t, p);

        // 2) 还原大小:bounds 用设计尺寸(= layout.size),缩放已在 transform 里,避免重复缩放
        vvvvvv.bounds = contentLayer.bounds;
        vvvvvv.transform = t;

        // 3) 还原位置:把 contentLayer 的中心点换算到播放器坐标系(已含所有平移:drawLayer offset / frameItem 平移 / nx-ny 补偿)
        CGPoint localCenter = CGPointMake(CGRectGetMidX(contentLayer.bounds),
                                          CGRectGetMidY(contentLayer.bounds));
        vvvvvv.center = [self.aPlayer.layer convertPoint:localCenter fromLayer:contentLayer];

        [self.aPlayer bringSubviewToFront:vvvvvv];
    } forKey:@"head"];
    parser = [[SVGAParser alloc] init];
    [self onChange:nil];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    [self onBeginButton:self.onBeginButton];
}

- (IBAction)onChange:(id)sender {
    NSArray *items = @[
                       @"https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/EmptyState.svga?raw=true",
                       @"https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/HamburgerArrow.svga?raw=true",
                       @"https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/PinJump.svga?raw=true",
                       @"https://github.com/svga/SVGA-Samples/raw/master/Rocket.svga",
                       @"https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/TwitterHeart.svga?raw=true",
                       @"https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/Walkthrough.svga?raw=true",
                       @"https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/angel.svga?raw=true",
                       @"https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/halloween.svga?raw=true",
                       @"https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/kingset.svga?raw=true",
                       @"https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/posche.svga?raw=true",
                       @"https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/rose.svga?raw=true",
                       ];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
//    parser.enabledMemoryCache = YES;
    NSURL *url = [NSURL URLWithString:items[arc4random() % items.count]];
    url = [NSURL fileURLWithPath:[NSBundle.mainBundle pathForResource:@"test2" ofType:@"svga"]];
    NSLog(@"播放 %@", url);
    [parser parseWithURL:url
         completionBlock:^(SVGAVideoEntity * _Nullable videoItem) {
             [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
             if (videoItem != nil) {
                 self.aPlayer.videoItem = videoItem;
                 NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];
                 [para setLineBreakMode:NSLineBreakByTruncatingTail];
                 [para setAlignment:NSTextAlignmentCenter];
                 NSAttributedString *str = [[NSAttributedString alloc]
                                            initWithString:@"Hello, World! Hello, World!"
                                            attributes:@{
                                                NSFontAttributeName: [UIFont systemFontOfSize:28],
                                                NSForegroundColorAttributeName: [UIColor whiteColor],
                                                NSParagraphStyleAttributeName: para,
                                            }];
                 [self.aPlayer setAttributedText:str forKey:@"banner"];

                 [self.aPlayer startAnimation];
                 
//                 [self.aPlayer startAnimationWithRange:NSMakeRange(10, 25) reverse:YES];
             }
         } failureBlock:nil];
//
//        [parser parseWithURL:[NSURL URLWithString:@"https://github.com/svga/SVGA-Samples/raw/master_aep/BitmapColorArea1.svga"] completionBlock:^(SVGAVideoEntity * _Nullable videoItem) {
//            if (videoItem != nil) {
//                self.aPlayer.videoItem = videoItem;
//                [self.aPlayer setImageWithURL:[NSURL URLWithString: @"https://i.imgur.com/vd4GuUh.png"] forKey:@"matte_EEKdlEml.matte"];
//                [self.aPlayer startAnimation];
//            }
//        } failureBlock:nil];
    
//    [parser parseWithNamed:@"Rocket" inBundle:nil completionBlock:^(SVGAVideoEntity * _Nonnull videoItem) {
//        self.aPlayer.videoItem = videoItem;
//        [self.aPlayer startAnimation];
//    } failureBlock:nil];
}

- (IBAction)onSliderClick:(UISlider *)sender {
    [self.aPlayer stepToPercentage:sender.value andPlay:NO];
}

- (IBAction)onSlide:(UISlider *)sender {
    [self.aPlayer stepToPercentage:sender.value andPlay:NO];
}

- (IBAction)onChangeColor:(UIButton *)sender {
    self.view.backgroundColor = sender.backgroundColor;
}

- (IBAction)onBeginButton:(UIButton *)sender {
    sender.selected = !sender.isSelected;
    if (sender.selected) {
        [self.aPlayer pauseAnimation];
    } else {
        [self.aPlayer stepToPercentage:(self.aSlider.value == 1 ? 0 : self.aSlider.value) andPlay:YES];
    }
}

- (IBAction)onRetreatButton:(UIButton *)sender {
    
}

- (IBAction)onForwardButton:(UIButton *)sender {
    
}


#pragma - mark SVGAPlayer Delegate
- (void)svgaPlayerDidAnimatedToPercentage:(CGFloat)percentage {
    self.aSlider.value = percentage;
}

- (void)svgaPlayerDidFinishedAnimation:(SVGAPlayer *)player {
    self.onBeginButton.selected = YES;
}
@end

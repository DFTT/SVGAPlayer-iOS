//
//  SVGAImageView.h
//  SVGAPlayer
//
//  Created by 崔明辉 on 2017/10/17.
//  Copyright © 2017年 UED Center. All rights reserved.
//

#import "SVGAPlayer.h"

@interface SVGAImageView : SVGAPlayer

@property (nonatomic, assign) IBInspectable BOOL autoPlay;
@property (nonatomic, copy  ) void(^parseCompletion)(SVGAImageView *);

@property (nonatomic, readonly) NSString *curImageDataKey;
- (void)setImageData:(NSData *)imageData forKey:(NSString *)aKey;

@property (nonatomic, copy  ) IBInspectable NSString *imageName;
- (void)setImageWithName:(NSString *)name;


///
- (void)cancelParseAndStop;
@end

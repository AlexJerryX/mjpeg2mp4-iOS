//
//  mjpeg2mp4.h
//  
//
//  Created by Alex on 2020/4/12.
//  Copyright © 2020 HOT. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
//#import <AssetsLibrary/AssetsLibrary.h>
#import "ALAssetsLibrary+CustomPhotoAlbum.h"
#import <Photos/Photos.h>
#import "Macros.h"

NS_ASSUME_NONNULL_BEGIN

@interface mjpeg2mp4 : NSObject

@property(nonatomic, strong)NSDateFormatter *formatterDate;
@property(nonatomic, strong)NSDateFormatter *formatterTime;

+(instancetype) sharedInstance;
+(instancetype) alloc __attribute__((unavailable("call sharedInstance instead")));
+(instancetype) new __attribute__((unavailable("call sharedInstance instead")));
-(instancetype) copy __attribute__((unavailable("call sharedInstance instead")));
-(instancetype) mutableCopy __attribute__((unavailable("call sharedInstance instead")));

-(void)startCreateMovieFile;
-(void)createMovieFileWithImageSequence:(NSMutableArray*)imageArray start:(NSUInteger)start end:(NSUInteger)end;
- (void)finishCreateMovieFile;

+(UIImage*)modifyImage:(UIImage *)sourceImage withBrightness:(float)brightness withContrast:(float)contrast withSaturation:(float)saturation;

+(UIImage *)grayishImage:(UIImage *)inputImage;

+(UIImage *)convertToGrayImage:(UIImage *)inputImage;

+(UIImage *)changeToGrayImage:(UIImage *)inputImage;

-(UIImage *)addFilterWithImage:(UIImage*)image withGammaValue:(float)gamma;

//-(NSDateFormatter *)formatterDate;
//
//-(NSDateFormatter *)formatterTime;

/**
 给图片添加文字水印
 */
- (UIImage *)waterImageOnImage:(UIImage *)image withText:(NSString *)text textPoint:(CGPoint)point attributedString:(NSDictionary * )attributed;

-(UIImage *)setFilterInImage:(UIImage *)image withColorRed:(float)red Green:(float)green Blue:(float)blue Alpha:(float) alpha;

@end

NS_ASSUME_NONNULL_END

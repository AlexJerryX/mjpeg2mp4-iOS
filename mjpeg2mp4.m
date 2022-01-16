//
//  mjpeg2mp4.m
//
//
//  Created by Alex on 2020/4/12.
//  Copyright © 2020 HOT. All rights reserved.
//

#import "mjpeg2mp4.h"
#define  VIDEO_DEBUG YES

@interface mjpeg2mp4 ()
{
    NSArray * imageArr;
    NSString * fileUrl;
    AVAssetWriter * videoWriter;
    AVAssetWriterInput * writerInput;
    AVAssetWriterInputPixelBufferAdaptor * adaptor;
    CVPixelBufferRef pixelBuffer;
    CIFilter *filter; // 滤镜
    CIFilter *colorFilter; // 颜色滤镜
    CIContext *ciContext; // 上下文
    unsigned long _curFrameIndex; // 当前的帧索引
}

@end

@implementation mjpeg2mp4
static mjpeg2mp4 *_instance = nil;
//单例模式
+(instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[super alloc] init];
    });
    return _instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
       // [self createMovieWriter];
        [self initData];
    }
    return self;
}

-(void)initData
{
    [self initFilter];
    [self initColorFilter];
    _curFrameIndex = -1;
}
// asset writer
-(void)createMovieWriter
{
    _curFrameIndex = -1;
    
    fileUrl = [NSTemporaryDirectory() stringByAppendingString:@"tmp.mp4"];
    unlink([fileUrl UTF8String]);
    
    NSError * err = nil;
    videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:fileUrl] fileType:AVFileTypeMPEG4 error:&err];

    NSParameterAssert(videoWriter);
    if (err) {
        NSLog(@"videowriterfailed");
    }
    
    NSDictionary * videoSettings = @{
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoWidthKey: [NSNumber numberWithInt:VIDEO_W],
        AVVideoHeightKey: [NSNumber numberWithInt:VIDEO_H]
    };
    
    writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];

    adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:nil];
    
    NSParameterAssert(writerInput);
    NSParameterAssert([videoWriter canAddInput:writerInput]);
    
    if ([videoWriter canAddInput:writerInput]) {
        [videoWriter addInput:writerInput];
    }
    
}

- (void)startCreateMovieFile
{
    [self releaseInstance];
    [self createMovieWriter];
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
}
-(void)createMovieFileWithImageSequence:(NSMutableArray*)imageArray start:(NSUInteger)start end:(NSUInteger)end
{
    if (end < start) {
        return;
    }
//    NSDictionary *dicAttribute = @{
//                    //NSFontAttributeName:helveticaBold,
//                    NSForegroundColorAttributeName:[UIColor orangeColor]
//    };
//    CGPoint datePoint = CGPointMake(VIDEO_W-Size(60, 60), VIDEO_H-Size(50, 50));
//    CGPoint timePoint = CGPointMake(VIDEO_W-Size(60, 60), VIDEO_H-Size(30, 30));
//    CGPoint namePoint = CGPointMake(Size(10, 10), Size(20, 20));
    for (NSUInteger i=start-1; i< end; i++) {
        @autoreleasepool {
            CGImageRef inputImage = [[imageArray objectAtIndex:i] CGImage];
            
            _curFrameIndex++;
            if (writerInput.readyForMoreMediaData) {
                [self appendNewFrame:inputImage frame:_curFrameIndex];
            } else {
                i--;
                _curFrameIndex--;
            }
        }
    }
}
- (void)finishCreateMovieFile
{
    [writerInput markAsFinished];
    [videoWriter finishWritingWithCompletionHandler:^{
       //ALAssetsLibrary
        ALAssetsLibrary * library = [[ALAssetsLibrary alloc] init];
      
        if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:[NSURL fileURLWithPath:fileUrl]]) {
            [library writeVideoAtPathToSavedPhotosAlbum:[NSURL fileURLWithPath:fileUrl] completionBlock:^(NSURL *assetURL, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) {
                        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"" message:@"saveFailed" delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil, nil];
                        [alert show];
                    } else {
                        // sucess
//                        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"温馨提示" message:@"视频已保持到手机相册中" delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil, nil];
//                        [alert show];
                    }
                    // 删除沙盒中的临时文件
                    [[NSFileManager defaultManager] removeItemAtPath:fileUrl error:nil];

                    [[NSNotificationCenter defaultCenter] postNotificationName:@"videoSaveFinish" object:nil];
                });
            }];
        }
        
//        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileUrl)) {
//            NSURL *myUrl = [NSURL fileURLWithPath:fileUrl];
//            [library saveVideo:myUrl toAlbum:@"album" completion:^(NSURL *assetURL, NSError *error) {
//                NSLog(@"video save success");
//            } failure:^(NSError *error) {
//                UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"" message:@"saveFailed" delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil, nil];
//                [alert show];
//            }];
//
//             // 删除沙盒中的临时文件
//             [[NSFileManager defaultManager] removeItemAtPath:fileUrl error:nil];
//             [[NSNotificationCenter defaultCenter] postNotificationName:@"videoSaveFinish" object:nil];
//        }
    }];
}

-(void)releaseInstance
{
    if (writerInput) {
        writerInput = nil;
    }
    if (videoWriter) {
        videoWriter = nil;
    }
    if (adaptor) {
        adaptor = nil;
    }
}
-(void)appendNewFrame:(CGImageRef)inputImage frame:(NSUInteger)frame
{
    NSLog(@"frameTime::::%lu",frame);
    
    CVPixelBufferRef pixelBuffer = [self imageToPixelBuffer:inputImage];
    [adaptor appendPixelBuffer:pixelBuffer withPresentationTime:CMTimeMake(frame, FPS)];
    CFRelease(pixelBuffer);
    
}

-(CVPixelBufferRef)imageToPixelBuffer:(CGImageRef)image
{
    CVPixelBufferRef pixelBuffer = NULL;
    
    // 创建视频
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],
                             kCVPixelBufferCGImageCompatibilityKey, [NSNumber numberWithBool:YES],
                             kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
    
    int width = VIDEO_W;
    int height = VIDEO_H;

    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)options, &pixelBuffer);
    
    // 进行断言判断 返回的status
    NSParameterAssert(status == kCVReturnSuccess && pixelBuffer != NULL);
    
    // CVPixelBuffer已经有了，但是我们创建的CVPixelBuffer目前只是一块内存区域，我们需要给他内容
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pixelBuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(pxdata, width, height, 8, 4*width, rgbColorSpace, kCGImageAlphaNoneSkipFirst);
    
    // 断言
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    
    
    CGContextDrawImage(context, CGRectMake(0, 0, VIDEO_W, VIDEO_H), image);
    
    
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}

+(UIImage*)modifyImage:(UIImage *)sourceImage withBrightness:(float)brightness withContrast:(float)contrast withSaturation:(float)saturation
{
    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *superImage = [CIImage imageWithCGImage:sourceImage.CGImage];
    CIFilter *lighten = [CIFilter filterWithName:@"CIColorControls"];
    [lighten setValue:superImage forKey:kCIInputImageKey];
    
    // 修改亮度 -1---1 数越大越亮
    if (brightness >= -1 && brightness <= 1) {
        [lighten setValue:@(brightness) forKey:@"inputBrightness"];
    }
    // 修改饱和度 0---2
    if (saturation >=0 && saturation <= 2) {
        [lighten setValue:@(saturation) forKey:@"inputSaturation"];
    }
    // 修改对比度 0---4
    if (contrast >= 0 && contrast <= 4) {
        [lighten setValue:@(contrast) forKey:@"inputContrast"];
    }
    
    CIImage *result = [lighten valueForKey:kCIOutputImageKey];
    CGImageRef cgImage = [context createCGImage:result fromRect:[superImage extent]];

    // 修改后的图片
    UIImage * resultImage = [UIImage imageWithCGImage:cgImage];
    // 释放中间对象
    CGImageRelease(cgImage);
    
    return resultImage;
}

// 利用kCGBlendModeLuminosit混合模式
+ (UIImage *)grayishImage:(UIImage *)inputImage {
    
    CGFloat scale = [UIScreen mainScreen].scale;
    UIGraphicsBeginImageContextWithOptions(inputImage.size, YES, scale);
    
    CGRect rect = CGRectMake(0, 0, inputImage.size.width, inputImage.size.height);
    
    [inputImage drawInRect:rect blendMode:kCGBlendModeLuminosity alpha:1.0];
    
    UIImage *filterImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return filterImage;
}

// 利用灰度公式将每个像素的颜色转成灰色
+ (UIImage *)convertToGrayImage:(UIImage *)inputImage {

    CGImageRef imageRef = [inputImage CGImage];
    
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    
    size_t bitsPerComponent = 8;
    size_t bytesPerRow = width * 4;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    uint32_t *pixels = (uint32_t *) calloc(bytesPerRow * height, sizeof(uint8_t));
    
    // kCGImageAlphaPremultipliedFirst      ARGB
    // kCGImageAlphaPremultipliedLast       RGBA
    
    // kCGBitmapByteOrder32Little   小端 (低位字节在前)
    // kCGBitmapByteOrder32Big      大端 (高位字节在前)
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            uint8_t *rgbaPixel = (uint8_t *) &pixels[y * width + x];
            
            uint32_t gray = 0.3 * rgbaPixel[0] + 0.59 * rgbaPixel[1] + 0.11 * rgbaPixel[2];
            
            rgbaPixel[0] = gray;
            rgbaPixel[1] = gray;
            rgbaPixel[2] = gray;
        }
    }
    
    CGImageRef newImageRef = CGBitmapContextCreateImage(context);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(pixels);
    
    UIImage *resultImage = [UIImage imageWithCGImage:newImageRef];
    
    CGImageRelease(newImageRef);
    
    return resultImage;
}

// 利用CGColorSpaceCreateDeviceGray()
+ (UIImage *)changeToGrayImage:(UIImage *)inputImage {
    
    CGImageRef imageRef = [inputImage CGImage];
    
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    
    size_t bitsPerComponent = 8;
    size_t bytesPerRow = width * 4;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    
    uint32_t *pixels = (uint32_t *) calloc(bytesPerRow * height, sizeof(uint8_t));
    
    CGContextRef contextRef = CGBitmapContextCreate(pixels, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, width, height), imageRef);
    
    CGImageRef newImageRef = CGBitmapContextCreateImage(contextRef);
    
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    free(pixels);
    
    UIImage *resultImage = [UIImage imageWithCGImage:newImageRef];
    
    CGImageRelease(newImageRef);
    
    return resultImage;
    
}

-(void)initColorFilter
{
    // 查看哪些值
    //    NSArray* filters =  [CIFilter filterNamesInCategory:kCICategoryColorAdjustment];
    //    for (NSString* filterName in filters) {
    //        NSLog(@"filter name:%@",filterName);
    //        // 我们可以通过filterName创建对应的滤镜对象
    //        CIFilter* filter = [CIFilter filterWithName:filterName];
    //        NSDictionary* attributes = [filter attributes];
    //        // 获取属性键/值对（在这个字典中我们可以看到滤镜的属性以及对应的key）
    //        NSLog(@"filter attributes:%@",attributes);
    //    }
        // 这里设置gamma/灰阶属性
        colorFilter = [CIFilter filterWithName:@"CIColorMonochrome"];
        //1.创建基于CPU的CIContext对象
    //    context = [CIContext contextWithOptions:
    //        [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
    //     forKey:kCIContextUseSoftwareRenderer]];

        //2.创建基于GPU的CIContext对象
        ciContext = [CIContext contextWithOptions: nil];
        
        //3.创建基于OpenGL优化的CIContext对象，可获得实时性能
        //context = [CIContext contextWithEAGLContext:[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2]];

        // 设置滤镜属性值为默认值
        //[filter setDefaults];
}

- (void)initFilter
{
    // 查看哪些值
//    NSArray* filters =  [CIFilter filterNamesInCategory:kCICategoryColorAdjustment];
//    for (NSString* filterName in filters) {
//        NSLog(@"filter name:%@",filterName);
//        // 我们可以通过filterName创建对应的滤镜对象
//        CIFilter* filter = [CIFilter filterWithName:filterName];
//        NSDictionary* attributes = [filter attributes];
//        // 获取属性键/值对（在这个字典中我们可以看到滤镜的属性以及对应的key）
//        NSLog(@"filter attributes:%@",attributes);
//    }
    // 这里设置gamma/灰阶属性
    filter = [CIFilter filterWithName:@"CIGammaAdjust"];
    //1.创建基于CPU的CIContext对象
//    context = [CIContext contextWithOptions:
//        [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
//     forKey:kCIContextUseSoftwareRenderer]];

    //2.创建基于GPU的CIContext对象
    ciContext = [CIContext contextWithOptions: nil];
    
    //3.创建基于OpenGL优化的CIContext对象，可获得实时性能
    //context = [CIContext contextWithEAGLContext:[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2]];

    // 设置滤镜属性值为默认值
    //[filter setDefaults];
}
/**
 gamma: 0-3 default 0.75
 */
-(UIImage *)addFilterWithImage:(UIImage*)image withGammaValue:(float)gamma
{
    //   1. 需要有一个输入的原图
    CIImage *inputImage = [CIImage imageWithCGImage:image.CGImage];
    //   通过打印可以设置的属性里面 得到可以设置 inputImage ——》在接口文件里面查找得到的key
    // 这里我们使用的是KVC的方式给filter设置属性
    [filter setValue:inputImage forKey:@"inputImage"];
    // 设置gamma值
    [filter setValue:@(gamma) forKey:@"inputPower"];
    // 3.有一个CIContext的对象去合并原图和滤镜效果
//    CIImage *outputImage = filter.outputImage;
    // 获取输出图像
    CIImage * outputImage = [filter valueForKey:@"outputImage"];
    
    CGImageRef cgImg = [ciContext createCGImage:outputImage fromRect:outputImage.extent];
    UIImage *resultImg = [UIImage imageWithCGImage:cgImg];
    CGImageRelease(cgImg);
    
    return resultImg;
}
/**
 设置颜色滤镜的颜色
 */
-(UIImage *)setFilterInImage:(UIImage *)image withColorRed:(float)red Green:(float)green Blue:(float)blue Alpha:(float) alpha
{
    //   1. 输入的原图
    CIImage *inputImage = [CIImage imageWithCGImage:image.CGImage];
    // 2. 这里我们使用的是KVC的方式给filter设置属性
    [colorFilter setValue:inputImage forKey:@"inputImage"];
    // 3. 设置滤镜的颜色
    [colorFilter setValue:[CIColor colorWithRed:red green:green blue:blue alpha:alpha] forKey:kCIInputColorKey];
    // 可以查询滤镜里的属性
    if (VIDEO_DEBUG) {
       // NSLog(@"%@",colorFilter.attributes);
        //NSLog(@"%@",[CIFilter filterNamesInCategory:kCICategoryColorEffect]);
    }
    
    // 获取输出图像
    CIImage * outputImage = [colorFilter valueForKey:@"outputImage"];
    
    CGImageRef cgImg = [ciContext createCGImage:outputImage fromRect:outputImage.extent];
    UIImage *resultImg = [UIImage imageWithCGImage:cgImg];
    CGImageRelease(cgImg);

    return resultImg;
}
/**
 给图片添加文字水印
 */
- (UIImage *)waterImageOnImage:(UIImage *)image withText:(NSString *)text textPoint:(CGPoint)point attributedString:(NSDictionary * )attributed
{
    //1.开启上下文
    UIGraphicsBeginImageContextWithOptions(image.size, NO, 0);
    //2.绘制图片
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    //3.添加水印文字
    [text drawAtPoint:point withAttributes:attributed];
    //4.从上下文中获取新的图片
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    //5.关闭图形上下文
    UIGraphicsEndImageContext();
    // 返回图片地址
    return newImage;
}

-(NSDateFormatter *)formatterDate
{
    if (!_formatterDate) {
        _formatterDate = [[NSDateFormatter alloc] init];
        //设置你想要的格式,hh与HH的区别:分别表示12小时制,24小时制
        [_formatterDate setDateFormat:@"MM-dd-YYYY"];
    }
    return _formatterDate;
}

-(NSDateFormatter *)formatterTime
{
    if (!_formatterTime) {
        _formatterTime = [[NSDateFormatter alloc] init];
        //设置你想要的格式,hh与HH的区别:分别表示12小时制,24小时制
        [_formatterTime setDateFormat:@" HH:mm"];
    }
    return _formatterTime;
}
    
@end

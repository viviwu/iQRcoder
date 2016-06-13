//
//  ViewController.m
//  iQRcoder
//
//  Created by qway on 16/6/13.
//  Copyright © 2016年 qway. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <UIKit/UIKit.h>

#define kScreenW [UIScreen mainScreen].bounds.size.width
#define kScreenH [UIScreen mainScreen].bounds.size.height
@interface ViewController ()<AVCaptureMetadataOutputObjectsDelegate,UIImagePickerControllerDelegate>//用于处理采集信息的代理
{
    AVCaptureSession * captureSession ;//输入输出的中间桥梁
    AVCaptureVideoPreviewLayer * previewLayer;//预览图层
}
@property (weak, nonatomic) IBOutlet UITextField *inputBox;
@property (weak, nonatomic) IBOutlet UIImageView *imgShower;
@property (weak, nonatomic) IBOutlet UILabel *resultShower;

@property (weak, nonatomic) IBOutlet UIButton *generateBtn;
@property (weak, nonatomic) IBOutlet UIButton *stopbtn;
@property (weak, nonatomic) IBOutlet UIButton *detectorBtn;

@end

@implementation ViewController


- (IBAction)scanQRcode:(id)sender {
    _resultShower.text=nil;
    if (nil==previewLayer) {
        previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
        previewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;
        previewLayer.frame=_imgShower.layer.bounds;
    }
    //    [_imgShower.layer insertSublayer:layer atIndex:0];
    [_imgShower.layer addSublayer:previewLayer];
    
    //开始捕获
    [captureSession startRunning];
    _inputBox.hidden=YES;
    _generateBtn.hidden=YES;
    _imgShower.image=nil;
    _stopbtn.hidden=NO;
}

- (IBAction)stopScanning:(id)sender {
    _resultShower.text=nil;
    [self captureSessionStopRunning];
}

-(void)captureSessionStopRunning{
    [captureSession stopRunning];
    _inputBox.hidden=NO;
    _generateBtn.hidden=NO;
    _imgShower.image=nil;
    _stopbtn.hidden=YES;
    
    for (CALayer * subLayer in _imgShower.layer.sublayers) {
        [subLayer removeFromSuperlayer];
    }
}

#pragma mark--AVCaptureMetadataOutputObjectsDelegate

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    
    if (metadataObjects.count>0) {
        //[session stopRunning];
        AVMetadataMachineReadableCodeObject * metadataObject = [metadataObjects objectAtIndex : 0 ];
        NSString *result;
        if ([[metadataObject type] isEqualToString:AVMetadataObjectTypeQRCode]) {
            result = metadataObject.stringValue;
            _resultShower.text=result;
            [self captureSessionStopRunning];
            
//            // 对扫描到的二维码进行描边
//            AVMetadataMachineReadableCodeObject *obj = (AVMetadataMachineReadableCodeObject *)[previewLayer transformedMetadataObjectForMetadataObject:metadataObject];
//            // 绘制描边
//            [self drawLine:obj];
            
            //输出扫描字符串
            NSLog(@"%@", result);
        } else {
            NSLog(@"不是二维码");
        }
    }
    
}

- (void)drawLine:(AVMetadataMachineReadableCodeObject *)objc
{
    NSArray *array = objc.corners;
    
    // 1.创建形状图层, 用于保存绘制的矩形
    CAShapeLayer *layer = [[CAShapeLayer alloc] init];
    // 设置线宽
    layer.lineWidth = 2;
    // 设置描边颜色
    layer.strokeColor = [UIColor greenColor].CGColor;
    layer.fillColor = [UIColor clearColor].CGColor;
    
    // 2.创建UIBezierPath, 绘制矩形
    UIBezierPath *path = [[UIBezierPath alloc] init];
    CGPoint point = CGPointZero;
    int index = 0;
    
    CFDictionaryRef dict = (__bridge CFDictionaryRef)(array[index++]);
    // 把点转换为不可变字典
    // 把字典转换为点，存在point里，成功返回true 其他false
    CGPointMakeWithDictionaryRepresentation(dict, &point);
    
    // 设置起点
    [path moveToPoint:point];
    
    // 2.2连接其它线段
    for (int i = 1; i<array.count; i++) {
        CGPointMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)array[i], &point);
        [path addLineToPoint:point];
    }
    // 2.3关闭路径
    [path closePath];
    
    layer.path = path.CGPath;
    // 3.将用于保存矩形的图层添加到界面上
    [_imgShower.layer addSublayer:layer];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    _inputBox.text=@"http://www.91qway.com";
    _stopbtn.hidden=YES;
    
    // Do any additional setup after loading the view, typically from a nib.
    //初始化链接对象
    captureSession = [[AVCaptureSession alloc]init];
    //高质量采集率
    [captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    
    //获取摄像设备
    AVCaptureDevice * device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError * error;
    //创建输入流
    AVCaptureDeviceInput * input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        NSLog(@"%@", [error localizedDescription]);
    }
    
    //创建输出流
    AVCaptureMetadataOutput * output = [[AVCaptureMetadataOutput alloc]init];
    //设置代理 在主线程里刷新
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    [captureSession addInput:input];
    [captureSession addOutput:output];
    //设置扫码支持的编码格式(如下设置条形码和二维码兼容)
    output.metadataObjectTypes=@[   AVMetadataObjectTypeQRCode,
                                    AVMetadataObjectTypeEAN13Code,
                                    AVMetadataObjectTypeEAN8Code,
                                    AVMetadataObjectTypeCode128Code
                                ];
//    output.rectOfInterest=CGRectMake(0.5,   0.5,    0.5, 0.5);
}


#pragma mark--generateQRcode

//因为生成的二维码是一个CIImage，我们直接转换成UIImage的话大小不好控制，所以使用下面方法返回需要大小的UIImage：
- (UIImage *)createNonInterpolatedUIImageFormCIImage:(CIImage *)image withSize:(CGFloat) size {
    CGRect extent = CGRectIntegral(image.extent);
    CGFloat scale = MIN(size/CGRectGetWidth(extent), size/CGRectGetHeight(extent));
    // 创建bitmap;
    size_t width = CGRectGetWidth(extent) * scale;
    size_t height = CGRectGetHeight(extent) * scale;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    CGContextRef bitmapRef = CGBitmapContextCreate(nil, width, height, 8, 0, cs, (CGBitmapInfo)kCGImageAlphaNone);
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef bitmapImage = [context createCGImage:image fromRect:extent];
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    CGContextScaleCTM(bitmapRef, scale, scale);
    CGContextDrawImage(bitmapRef, extent, bitmapImage);
    // 保存bitmap到图片
    CGImageRef scaledImage = CGBitmapContextCreateImage(bitmapRef);
    CGContextRelease(bitmapRef);
    CGImageRelease(bitmapImage);
    return [UIImage imageWithCGImage:scaledImage];
}
//因为生成的二维码是黑白的，所以还要对二维码进行颜色填充，并转换为透明背景，使用遍历图片像素来更改图片颜色，因为使用的是CGContext，速度非常快：
void ProviderReleaseData (void *info, const void *data, size_t size){
    free((void*)data);
}
- (UIImage*)imageBlackToTransparent:(UIImage*)image withRed:(CGFloat)red andGreen:(CGFloat)green andBlue:(CGFloat)blue{
    const int imageWidth = image.size.width;
    const int imageHeight = image.size.height;
    size_t      bytesPerRow = imageWidth * 4;
    uint32_t* rgbImageBuf = (uint32_t*)malloc(bytesPerRow * imageHeight);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(rgbImageBuf, imageWidth, imageHeight, 8, bytesPerRow, colorSpace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipLast);
    CGContextDrawImage(context, CGRectMake(0, 0, imageWidth, imageHeight), image.CGImage);
    // 遍历像素
    int pixelNum = imageWidth * imageHeight;
    uint32_t* pCurPtr = rgbImageBuf;
    for (int i = 0; i < pixelNum; i++, pCurPtr++){
        if ((*pCurPtr & 0xFFFFFF00) < 0x99999900)    // 将白色变成透明
        {
            // 改成下面的代码，会将图片转成想要的颜色
            uint8_t* ptr = (uint8_t*)pCurPtr;
            ptr[3] = red; //0~255
            ptr[2] = green;
            ptr[1] = blue;
        }
        else
        {
            uint8_t* ptr = (uint8_t*)pCurPtr;
            ptr[0] = 0;
        }
    }
    // 输出图片
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, rgbImageBuf, bytesPerRow * imageHeight, ProviderReleaseData);
    CGImageRef imageRef = CGImageCreate(imageWidth, imageHeight, 8, 32, bytesPerRow, colorSpace,
                                        kCGImageAlphaLast | kCGBitmapByteOrder32Little, dataProvider,
                                        NULL, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);
    UIImage* resultUIImage = [UIImage imageWithCGImage:imageRef];
    // 清理空间
    CGImageRelease(imageRef);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    return resultUIImage;
}


//首先是二维码的生成，使用CIFilter很简单，直接传入生成二维码的字符串即可：
- (CIImage *)createQRForString:(NSString *)qrString {
    NSData *stringData = [qrString dataUsingEncoding:NSUTF8StringEncoding];
    // 创建filter
    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    // 设置内容和纠错级别
    [qrFilter setValue:stringData forKey:@"inputMessage"];
    [qrFilter setValue:@"M" forKey:@"inputCorrectionLevel"];
    // 返回CIImage
    return qrFilter.outputImage;
}

- (IBAction)generateQRcode:(id)sender {
    
    _imgShower.layer.shadowOffset = CGSizeMake(0, 0.5);  // 设置阴影的偏移量
    _imgShower.layer.shadowRadius = 1;  // 设置阴影的半径
    _imgShower.layer.shadowColor = [UIColor blackColor].CGColor; // 设置阴影的颜色为黑色
    _imgShower.layer.shadowOpacity = 0.3; // 设置阴影的不透明度
    
    CIImage * ciimg=nil;
    if(_inputBox.text!=nil){
        ciimg=[self createQRForString:_inputBox.text];
    }else{
        if (_resultShower.text !=nil) {
            ciimg=[self createQRForString:_inputBox.text];
        }else{
            return;
        }
    }
    
    UIImage * uiimg=[self createNonInterpolatedUIImageFormCIImage:ciimg withSize: 320.0f];
    uiimg=[self imageBlackToTransparent:uiimg withRed:50.0f andGreen:100.0f andBlue:100.0f];
    _imgShower.image=uiimg;
}

- (IBAction)quitKeyboard:(id)sender {
    [self.view endEditing:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark--实现相册二维码识别
//1.打开系统相册
- (IBAction)openCameralClick:(id)sender {
    // 1.判断相册是否可以打开
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) return;
    // 2. 创建图片选择控制器
    UIImagePickerController *ipc = [[UIImagePickerController alloc] init];
    
    ipc.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    // 4.设置代理
    ipc.delegate = (id)self;
    
    // 5.modal出这个控制器
    [self presentViewController:ipc animated:YES completion:nil];
}

//2.实现代理方法(注意需要遵守两个代理协议)
#pragma mark -------- UIImagePickerControllerDelegate---------
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    // 1.取出选中的图片
    UIImage *pickImage = info[UIImagePickerControllerOriginalImage];
    NSData *imageData = UIImagePNGRepresentation(pickImage);
    
    CIImage *ciImage = [CIImage imageWithData:imageData];
    
    // 2.从选中的图片中读取二维码数据
    // 2.1创建一个探测器
    CIDetector *detector = [CIDetector detectorOfType: CIDetectorTypeQRCode
                                              context: nil
                                              options: @{CIDetectorAccuracy: CIDetectorAccuracyLow}
                            ];
    
    // 2.2利用探测器探测数据
    NSArray *feature = [detector featuresInImage:ciImage];
    
    // 2.3取出探测到的数据
    for (CIQRCodeFeature *result in feature) {
         NSLog(@"%@",result.messageString);
        NSString *urlStr = result.messageString;
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr]];
    }
    
    // 注意: 如果实现了该方法, 当选中一张图片时系统就不会自动关闭相册控制器
    [picker dismissViewControllerAnimated:YES completion:nil];
}

//3.在界面消失的时候关闭session
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [captureSession stopRunning];
}


@end

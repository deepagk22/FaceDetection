//
//  ViewController.swift
//  FaceDetection
//
//  Created by Ryan Davies on 02/09/2014.
//  Copyright (c) 2014 Ryan Davies. All rights reserved.
//

import UIKit
import CoreImage
import AVFoundation

protocol VideoFeedDelegate {
    func videoFeed(videoFeed: VideoFeed, didUpdateWithSampleBuffer sampleBuffer: CMSampleBuffer!)
}

class VideoFeed: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    // create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured
    // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
    // see the header doc for setSampleBufferDelegate:queue: for more information
    let outputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL)
    
    let device: AVCaptureDevice? = {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]
        var camera: AVCaptureDevice? = nil
        for device in devices {
            if device.position == .Front {
                camera = device
            }
        }
        return camera
    }()
    
    var input: AVCaptureDeviceInput? = nil
    var delegate: VideoFeedDelegate? = nil
    
    let session: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSessionPresetHigh
        return session
    }()
    
    let videoDataOutput: AVCaptureVideoDataOutput = {
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [ kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt: kCMPixelFormat_32BGRA) ]
        output.alwaysDiscardsLateVideoFrames = true
        return output
    }()
    
    func start() throws {
        var error: NSError! = NSError(domain: "Migrator", code: 0, userInfo: nil)
        do {
            try configure()
            session.startRunning()
            return
        } catch let error1 as NSError {
            error = error1
        }
        throw error
    }
    
    func stop() {
        session.stopRunning()
    }
    
    private func configure() throws {
        var error: NSError! = NSError(domain: "Migrator", code: 0, userInfo: nil)
        do {
            let maybeInput: AnyObject = try AVCaptureDeviceInput(device: device!)
            input = maybeInput as? AVCaptureDeviceInput
            if session.canAddInput(input) {
                session.addInput(input)
                videoDataOutput.setSampleBufferDelegate(self, queue: outputQueue);
                if session.canAddOutput(videoDataOutput) {
                    session.addOutput(videoDataOutput)
                    let connection = videoDataOutput.connectionWithMediaType(AVMediaTypeVideo)
                    connection.videoOrientation = AVCaptureVideoOrientation.Portrait
                    return
                } else {
                    print("Video output error.");
                }
            } else {
                print("Video input error. Maybe unauthorised or no camera.")
            }
        } catch let error1 as NSError {
            error = error1
            print("Failed to start capturing video with error: \(error)")
        }
        throw error
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        // Update the delegate
        if delegate != nil {
            delegate!.videoFeed(self, didUpdateWithSampleBuffer: sampleBuffer)
        }
    }
}

class FaceObscurationFilter {
    let inputImage: CIImage
    var outputImage: UIImage? = UIImage(named:"hige_100.png")
    
    init(inputImage: CIImage) {
        self.inputImage = inputImage
    }
    
    convenience init(sampleBuffer: CMSampleBuffer) {
        // Create a CIImage from the buffer
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let image = CIImage(CVPixelBuffer: imageBuffer!)
        
        self.init(inputImage: image)
    }
    
    func process() {
        // Detect any faces in the image
        let detector = CIDetector(ofType: CIDetectorTypeFace, context:nil, options:nil)
        let features = detector.featuresInImage(inputImage)
        
        print("Features: \(features)")
        
        // Build a pixellated version of the image using the CIPixellate filter
        let imageSize = inputImage.extent.size
        UIGraphicsBeginImageContext(imageSize)
        let image = UIImage(CIImage: inputImage)
        image.drawInRect(CGRectMake(0,0,imageSize.width,imageSize.height))
        
        // Build a masking image for each of the faces
        var maskImage: CIImage?
        for feature in features {
            let drawCtxt = UIGraphicsGetCurrentContext()
            var higeWidth:CGFloat = 0.0
            var higeHeight:CGFloat = 0.0
            let higeImg      = UIImage(named:"hige_100.png")
            //outputImage = higeImg
            
            if let feature1 = feature as? CIFaceFeature {
                //face
                var faceRect = (feature).bounds
                print(1)
                faceRect.origin.y = imageSize.height - faceRect.origin.y - faceRect.size.height
                CGContextSetStrokeColorWithColor(drawCtxt, UIColor.redColor().CGColor)
                CGContextStrokeRect(drawCtxt,faceRect)
                //mush
                let mouseRectY = imageSize.height - feature1.mouthPosition.y
                let mouseRect  = CGRectMake(feature1.mouthPosition.x - 5,mouseRectY - 5,10,10)
                
                let higeWidth  = feature.bounds.size.width * 4/5
                let higeHeight = higeWidth * 0.3
                let higeRect  = CGRectMake(feature1.mouthPosition.x - higeWidth/2,mouseRectY - higeHeight/2,higeWidth,higeHeight)
                CGContextDrawImage(drawCtxt,higeRect,higeImg!.CGImage)
                let drawedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                outputImage = drawedImage
            }
        }
       
      
        

//                var blendOptions: [String: AnyObject] = [:]
//        blendOptions[kCIInputImageKey] = pixellatedImage
//        blendOptions[kCIInputBackgroundImageKey] = inputImage
//        blendOptions[kCIInputMaskImageKey] = maskImage
//        let blend = CIFilter(name: "CIBlendWithMask", withInputParameters: blendOptions)
        
        // Finally, set the resulting image as the output
//        outputImage = blend!.outputImage
    }
}

class ViewController: UIViewController, VideoFeedDelegate {
    @IBOutlet weak var imageView: UIImageView!
    let feed: VideoFeed = VideoFeed()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        feed.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        startVideoFeed()
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        feed.stop()
    }
    
    func startVideoFeed() {
        do {
            try feed.start()
            print("Video started.")
        }
        catch {
            // alert?
            // need to look into device permissions
        }
    }
    
    @IBAction func PhotoPressed(sender: UIButton) {
        capturePicture()
    }
    
    func capturePicture(){
        print("snapStillImage")
//        feed.start()
UIImageWriteToSavedPhotosAlbum(self.imageView.image!, nil, nil, nil)
                    print("Save Image")
        
        
        
    }

    func videoFeed(videoFeed: VideoFeed, didUpdateWithSampleBuffer sampleBuffer: CMSampleBuffer!) {
        let filter = FaceObscurationFilter(sampleBuffer: sampleBuffer)
        filter.process()
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.imageView.image =  filter.outputImage!
            
            
        })
        
    }

}

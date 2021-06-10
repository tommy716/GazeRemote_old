//
//  GazeMouseViewController.swift
//  GazeRemote
//
//  Created by Tommy on 2021/06/10.
//

import UIKit
import AVFoundation
import CoreVideo
import MLKit

enum BlinkingStatus {
    case none
    case singleBlink
    case doubleBlink
}

class GazeMouseViewController: UIViewController {
    
    // MARK: Init variable
    lazy var captureSession = AVCaptureSession()
    lazy var sessionQueue = DispatchQueue(label: "jp.tommy.detectingFace")
    var lastFrame: CMSampleBuffer?
    
    var mouseView: UIView!
    let screenSize = UIScreen.main.bounds.size
    var topBarHeight: CGFloat {
        return (view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0) +
            (self.navigationController?.navigationBar.frame.height ?? 0.0)
    }
//    var timer = Timer()
    var blinkStatus = BlinkingStatus.none
    
    // MARK: Life Cycle Events
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpCaptureSessionOutput()
        setUpCaptureSessionInput()
        
        mouseView = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        mouseView.center = self.view.center
        mouseView.backgroundColor = UIColor.gray
        mouseView.layer.cornerRadius = 25
        mouseView.layer.shadowColor = UIColor.black.cgColor
        mouseView.layer.shadowOpacity = 1
        mouseView.layer.shadowRadius = 4
        mouseView.layer.shadowOffset = CGSize(width: 2, height: 2)
        self.view.addSubview(mouseView)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopSession()
    }
    
    // MARK: Face Detector
    func detectFacesOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat) {
        // MARK: Setup Detector
        let options = FaceDetectorOptions()
        options.landmarkMode = .none
        options.contourMode = .none
        options.classificationMode = .all
        options.performanceMode = .fast
        let faceDetector = FaceDetector.faceDetector(options: options)
        var faces: [Face]
        do {
            faces = try faceDetector.results(in: image)
        } catch let error {
            print(error)
            return
        }
        guard !faces.isEmpty else {
            print("No Face")
            return
        }
        // MARK: Showing Result
        DispatchQueue.main.sync {
            let blinkingProbability = (1 - faces.first!.rightEyeOpenProbability) * (1 - faces.first!.leftEyeOpenProbability)
            
            //            print("FaceAngleX: \(String(format: "%.2f", faces.first!.headEulerAngleX))")
            //            print("FaceAngleY: \(String(format: "%.2f", faces.first!.headEulerAngleY))")
            //            print("FaceAngleZ: \(String(format: "%.2f", faces.first!.headEulerAngleZ))")
            //            print("Blinking Probability: \(String(format: "%.2f", blinkingProbability))")
            
            self.moveMouse(x: faces.first!.headEulerAngleX, y: faces.first!.headEulerAngleY)
            
            if (blinkingProbability > 0.85 && blinkStatus == BlinkingStatus.singleBlink) {
                blinkStatus = BlinkingStatus.doubleBlink
                self.mouseView.backgroundColor = .orange
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.mouseView.backgroundColor = .gray
                    self.blinkStatus = BlinkingStatus.none
                }
            } else if (blinkingProbability > 0.85 && blinkStatus == BlinkingStatus.none) {
                blinkStatus = BlinkingStatus.singleBlink
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    self.blinkStatus = BlinkingStatus.none
                }
            }
        }
    }
    
    // MARK: Detector Util
    func setUpCaptureSessionOutput() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            strongSelf.captureSession.beginConfiguration()
            strongSelf.captureSession.sessionPreset = AVCaptureSession.Preset.medium
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            let outputQueue = DispatchQueue(label: "vision.outputQueue")
            output.setSampleBufferDelegate(strongSelf, queue: outputQueue)
            guard strongSelf.captureSession.canAddOutput(output) else {
                print("Failed to add capture session output.")
                return
            }
            strongSelf.captureSession.addOutput(output)
            strongSelf.captureSession.commitConfiguration()
        }
    }
    
    func setUpCaptureSessionInput() {
        sessionQueue.async {
            let cameraPosition: AVCaptureDevice.Position = .front
            guard let device = self.captureDevice(forPosition: cameraPosition) else {
                print("Failed to get capture device for camera position: \(cameraPosition)")
                return
            }
            do {
                self.captureSession.beginConfiguration()
                let currentInputs = self.captureSession.inputs
                for input in currentInputs {
                    self.captureSession.removeInput(input)
                }
                
                let input = try AVCaptureDeviceInput(device: device)
                guard self.captureSession.canAddInput(input) else {
                    print("Failed to add capture session input.")
                    return
                }
                self.captureSession.addInput(input)
                self.captureSession.commitConfiguration()
            } catch {
                print("Failed to create capture device input: \(error.localizedDescription)")
            }
        }
    }
    
    func startSession() {
        sessionQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        sessionQueue.async {
            self.captureSession.stopRunning()
        }
    }
    
    func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if #available(iOS 10.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .front
            )
            return discoverySession.devices.first { $0.position == position }
        }
        return nil
    }
    
    func moveMouse(x: CGFloat, y: CGFloat) {
        mouseView.center.x += x
        mouseView.center.y -= y
        
        if mouseView.center.x >= screenSize.width - (mouseView.frame.width / 2) {
            mouseView.center.x = screenSize.width - (mouseView.frame.width / 2)
        }
        if mouseView.center.y >= screenSize.height - (mouseView.frame.height / 2) {
            mouseView.center.y = screenSize.height - (mouseView.frame.height / 2)
        }
        if mouseView.center.x <= (mouseView.frame.height / 2) {
            mouseView.center.x = mouseView.frame.height / 2
        }
        if mouseView.center.y <= topBarHeight + (mouseView.frame.height / 2) {
            mouseView.center.y = 0 + topBarHeight + (mouseView.frame.height / 2)
        }
    }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate
extension GazeMouseViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        
        lastFrame = sampleBuffer
        let visionImage = VisionImage(buffer: sampleBuffer)
        let orientation = imageOrientation(
            fromDevicePosition: .front
        )
        
        visionImage.orientation = orientation
        let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        
        detectFacesOnDevice(in: visionImage, width: imageWidth, height: imageHeight)
    }
}

// MARK: Orientation Manager
extension GazeMouseViewController {
    func imageOrientation(
        fromDevicePosition devicePosition: AVCaptureDevice.Position = .back
    ) -> UIImage.Orientation {
        var deviceOrientation = UIDevice.current.orientation
        if deviceOrientation == .faceDown || deviceOrientation == .faceUp
            || deviceOrientation
            == .unknown
        {
            deviceOrientation = currentUIOrientation()
        }
        switch deviceOrientation {
        case .landscapeLeft:
            return .downMirrored
        case .landscapeRight:
            return .upMirrored
        case .faceDown, .faceUp, .unknown:
            return .up
        default:
            print("Invalid Orientation")
            return .downMirrored
        }
    }
    
    func currentUIOrientation() -> UIDeviceOrientation {
        let deviceOrientation = { () -> UIDeviceOrientation in
            switch UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.windowScene?.interfaceOrientation {
            case .landscapeLeft:
                return .landscapeRight
            case .landscapeRight:
                return .landscapeLeft
            default:
                print("Invalid Orientation")
                return .unknown
            }
        }
        guard Thread.isMainThread else {
            var currentOrientation: UIDeviceOrientation = .portrait
            DispatchQueue.main.sync {
                currentOrientation = deviceOrientation()
            }
            return currentOrientation
        }
        return deviceOrientation()
    }
}

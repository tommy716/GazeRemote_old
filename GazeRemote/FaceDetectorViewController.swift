//
//  FaceDetectorViewController.swift
//  GazeRemote
//
//  Created by Tommy on 2021/06/07.
//

import UIKit
import AVFoundation
import CoreVideo
import MLKit

class FaceDetectorViewController: UIViewController {
    
    // MARK: Init variable
    var previewLayer: AVCaptureVideoPreviewLayer!
    lazy var captureSession = AVCaptureSession()
    lazy var sessionQueue = DispatchQueue(label: "jp.tommy.detectingFace")
    var lastFrame: CMSampleBuffer?
    
    lazy var previewOverlayView: UIImageView = {
        precondition(isViewLoaded)
        let previewOverlayView = UIImageView(frame: .zero)
        previewOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
        previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return previewOverlayView
    }()
    
    // MARK: IBOutlet
    @IBOutlet var cameraView: UIView!
    @IBOutlet var faceAngleXLabel: UILabel!
    @IBOutlet var faceAngleYLabel: UILabel!
    @IBOutlet var faceAngleZLabel: UILabel!
    @IBOutlet var rightEyeLabel: UILabel!
    @IBOutlet var leftEyeLabel: UILabel!
    @IBOutlet var blinkingLabel: UILabel!
    @IBOutlet var faceInfoStackView: UIStackView!
    @IBOutlet var noFaceLabel: UILabel!
    
    // MARK: Life Cycle Events
    override func viewDidLoad() {
        super.viewDidLoad()
        faceInfoStackView.isHidden = false
        noFaceLabel.isHidden = true
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        setUpPreviewOverlayView()
        setUpCaptureSessionOutput()
        setUpCaptureSessionInput()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = cameraView.frame
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
            DispatchQueue.main.sync {
                noFaceLabel.text = "Failed to detect faces with error: \(error.localizedDescription)."
                faceInfoStackView.isHidden = true
                noFaceLabel.isHidden = false
            }
            return
        }
        DispatchQueue.main.sync {
            updatePreviewOverlayViewWithLastFrame()
        }
        guard !faces.isEmpty else {
            DispatchQueue.main.sync {
                noFaceLabel.text = "No Face"
                faceInfoStackView.isHidden = true
                noFaceLabel.isHidden = false
            }
            return
        }
        // MARK: Showing Result
        DispatchQueue.main.sync {
            faceInfoStackView.isHidden = false
            noFaceLabel.isHidden = true
            
            let blinkingProbability = (1 - faces.first!.rightEyeOpenProbability) * (1 - faces.first!.leftEyeOpenProbability)
            
            faceAngleXLabel.text = "FaceAngleX: \(String(format: "%.2f", faces.first!.headEulerAngleX))"
            faceAngleYLabel.text = "FaceAngleY: \(String(format: "%.2f", faces.first!.headEulerAngleY))"
            faceAngleZLabel.text = "FaceAngleZ: \(String(format: "%.2f", faces.first!.headEulerAngleZ))"
            rightEyeLabel.text = "Right Eye Opening Probability: \(String(format: "%.2f", faces.first!.rightEyeOpenProbability))"
            leftEyeLabel.text = "Left Eye Opening Probability: \(String(format: "%.2f", faces.first!.leftEyeOpenProbability))"
            blinkingLabel.text = "Blinking?: \(String(format: "%.2f", blinkingProbability))"
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
    
    func setUpPreviewOverlayView() {
        cameraView.addSubview(previewOverlayView)
        NSLayoutConstraint.activate([
            previewOverlayView.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
            previewOverlayView.centerYAnchor.constraint(equalTo: cameraView.centerYAnchor),
            previewOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            previewOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
        ])
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
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate
extension FaceDetectorViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
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

// MARK: Building Preview
extension FaceDetectorViewController {
    func updatePreviewOverlayViewWithLastFrame() {
        guard let lastFrame = lastFrame,
              let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame)
        else {
            return
        }
        self.updatePreviewOverlayViewWithImageBuffer(imageBuffer)
    }
    
    func updatePreviewOverlayViewWithImageBuffer(_ imageBuffer: CVImageBuffer?) {
        guard let imageBuffer = imageBuffer else {
            return
        }
        let orientation: UIImage.Orientation = imageOrientation()
        let image = createUIImage(from: imageBuffer, orientation: orientation)
        previewOverlayView.image = image
    }
    
    func createUIImage(
        from imageBuffer: CVImageBuffer,
        orientation: UIImage.Orientation
    ) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
}

// MARK: Orientation Manager
extension FaceDetectorViewController {
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

//
//  ViewController.swift
//  Camera App
//
//  Created by Mahnoor Khan on 03/10/2019.
//  Copyright © 2019 Mahnoor Khan. All rights reserved.
//

import UIKit
import AVFoundation

enum CameraMode {
    case photo
    case video
}

class ViewController: UIViewController {
    @IBOutlet weak var cameraView       : UIView!
    @IBOutlet weak var takePhoto        : UIButton!
    @IBOutlet weak var cameraPosition   : UIButton!
    @IBOutlet weak var flashStatus      : UIButton!
    @IBOutlet weak var cameraMode       : UIButton!
    @IBOutlet weak var capturedImage    : UIImageView!
    
    @IBOutlet weak var cameraHeight     : NSLayoutConstraint!
    @IBOutlet weak var cameraWidth      : NSLayoutConstraint!
    
    var captureSession                  = AVCaptureSession()
    var videoPreviewLayer               : AVCaptureVideoPreviewLayer?
    var capturePhotoOutput              = AVCapturePhotoOutput()
    var flashMode                       = AVCaptureDevice.FlashMode.off
    
    let movieOutput                     = AVCaptureMovieFileOutput()
    
    let heightforcamera                 : CGFloat = 450
    
    var image                           : UIImage?
    
    var mode                            : CameraMode = .photo
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initButton()
        setOrientation()
        initPhotoUI(.back)
        addOutput()
        viewImage()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let targetRotation = coordinator.targetTransform
        let inverseRotation = targetRotation.inverted()

        coordinator.animate(alongsideTransition: { context in
            self.cameraView.transform = self.cameraView.transform.concatenating(inverseRotation)
            self.cameraView.frame = self.cameraView.frame
          context.viewController(forKey: UITransitionContextViewControllerKey.from)
        }, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "viewCapturedImage" {
            guard let vc = segue.destination as? ImageViewController else { return }
            vc.image = self.image
        }
    }
}


extension ViewController {
    func viewImage() {
        let singleTap = UITapGestureRecognizer(target: self, action: Selector(("tapDetected")))
        singleTap.numberOfTapsRequired = 1
        capturedImage.isUserInteractionEnabled = true
        capturedImage.addGestureRecognizer(singleTap)
    }
    
    @objc func tapDetected() {
        if image != nil {
            performSegue(withIdentifier: "viewCapturedImage", sender: nil)
        }
    }
    
    func setOrientation() {
        let orientation = UIApplication.shared.statusBarOrientation
        if orientation == .portrait {
            cameraWidth.constant = view.frame.width
            cameraHeight.constant = heightforcamera
        } else if orientation == .landscapeRight || orientation == .landscapeLeft {
            cameraWidth.constant = heightforcamera
            cameraHeight.constant = view.frame.height
        } else {
            cameraWidth.constant = view.frame.width
            cameraHeight.constant = heightforcamera
        }
    }
    
    @IBAction func capture(_ sender: UIButton) {
        if mode == .photo {
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.isAutoStillImageStabilizationEnabled = true
            photoSettings.isHighResolutionPhotoEnabled = true
            if capturePhotoOutput.supportedFlashModes.contains(AVCaptureDevice.FlashMode(rawValue: self.flashMode.rawValue)!) {
                photoSettings.flashMode = self.flashMode
            }
            capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
        } else if mode == .video {
            recordVideo()
        }
    }
    
    @IBAction func switchCamera(_ sender: UIButton) {
        guard let input: AVCaptureInput = captureSession.inputs.first else { return }
        guard let currentInput = input as? AVCaptureDeviceInput else { return }
        removeInputs()
        captureSession.stopRunning()
        if mode == .photo {
            if currentInput.device.position == .back {
                initPhotoUI(.front)
                cameraPosition.setTitle("  Front  ", for: .normal)
            } else if currentInput.device.position == .front {
                initPhotoUI(.back)
                cameraPosition.setTitle("  Rear  ", for: .normal)
            }
        } else if mode == .video {
            initVideoUI()
            if currentInput.device.position == .back {
                initVideoUI()
                cameraPosition.setTitle("  Front  ", for: .normal)
            }
            else if currentInput.device.position == .front {
                initVideoUI()
                cameraPosition.setTitle("  Rear  ", for: .normal)
            }
        }
    }
    
    @IBAction func changeFlashStatus(_ sender: Any) {
        switch flashMode {
        case .off:
            flashMode = .on
            flashStatus.setTitle("  Flash: On  ", for: .normal)
        case .on:
            flashMode = .off
            flashStatus.setTitle("  Flash: Off  ", for: .normal)
        case .auto:
            flashMode = .off
            flashStatus.setTitle("  Flash: Off  ", for: .normal)
        @unknown default:
            break
        }
    }
    
    @IBAction func switchCameraMode(_ sender: Any) {
        if mode == .photo {
            mode = .video
            cameraMode.setTitle("  Video  ", for: .normal)
        } else if mode == .video {
            mode = .photo
            cameraMode.setTitle("  Photo  ", for: .normal)
        }
    }
}

extension ViewController {
    func initButton() {
        takePhoto.layer.cornerRadius = takePhoto.frame.size.width/2
        takePhoto.layer.masksToBounds = true
    }
    
    func initPhotoUI(_ position: AVCaptureDevice.Position) {
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position ) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(input)
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            
            view.layoutSubviews()
            videoPreviewLayer?.frame = cameraView.layer.bounds
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill

            cameraView.layer.addSublayer(videoPreviewLayer!)
            
            captureSession.commitConfiguration()
            captureSession.startRunning()
            
        } catch {
            print("Error")
        }
    }
    
    func initVideoUI() {
        removeInputs()
        captureSession.sessionPreset = AVCaptureSession.Preset.high
        let camera = AVCaptureDevice.default(for: AVMediaType.video)!
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            print("Error setting device video input: \(error)")
        }
        if !captureSession.isRunning {
            DispatchQueue.main.async {
                self.captureSession.startRunning()
            }
        }
    }
    
    func addOutput() {
        capturePhotoOutput.isHighResolutionCaptureEnabled = true
        captureSession.addOutput(capturePhotoOutput)
        captureSession.addOutput(movieOutput)
    }
    
    func removeInputs() {
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
    }
    
    func videoURL() -> URL? {
        let directory = NSTemporaryDirectory() as NSString

        if directory != "" {
            let path = directory.appendingPathComponent(NSUUID().uuidString + ".mp4")
            return URL(fileURLWithPath: path)
        }

        return nil
    }
    
    func currentVideoOrientation() -> AVCaptureVideoOrientation {
       var orientation: AVCaptureVideoOrientation

       switch UIDevice.current.orientation {
           case .portrait:
               orientation = AVCaptureVideoOrientation.portrait
           case .landscapeRight:
               orientation = AVCaptureVideoOrientation.landscapeLeft
           case .portraitUpsideDown:
               orientation = AVCaptureVideoOrientation.portraitUpsideDown
           default:
                orientation = AVCaptureVideoOrientation.landscapeRight
        }

        return orientation
    }
    
    func recordVideo() {
        if movieOutput.isRecording == false {
            takePhoto.backgroundColor = UIColor.red
            let connection = movieOutput.connection(with: AVMediaType.video)

            if (connection?.isVideoOrientationSupported)! {
                connection?.videoOrientation = currentVideoOrientation()
            }

            if (connection?.isVideoStabilizationSupported)! {
                connection?.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.auto
            }
                
            guard let input: AVCaptureInput = captureSession.inputs.first else { return }
            guard let currentInput = input as? AVCaptureDeviceInput else { return }

            if (currentInput.device.isSmoothAutoFocusSupported) {
                do {
                    try currentInput.device.lockForConfiguration()
                    currentInput.device.isSmoothAutoFocusEnabled = false
                    currentInput.device.unlockForConfiguration()
                } catch {
                   print("Error setting configuration: \(error)")
                }
            }
            guard let outputURL = videoURL() else { return }
            movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        } else {
            if movieOutput.isRecording == true {
                takePhoto.backgroundColor = UIColor.white
                movieOutput.stopRecording()
            }
        }
    }
}

extension ViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if (error != nil) {
            print("Error recording movie: \(error!.localizedDescription)")
        } else {
//            performSegue(withIdentifier: "showVideo", sender: outputFileURL)
            UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
        }
    }
    
    
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        AudioServicesDisposeSystemSoundID(1108)
        if let error = error {
            print("error occured : \(error.localizedDescription)")
        }
        if let dataImage = photo.fileDataRepresentation() {
            if let image = UIImage(data: dataImage) {
                var croppedImage = UIImage()
                var orientedImage = UIImage()
                let orientation = UIDevice.current.orientation
                
                croppedImage = cropImage(sourceImage: image, width: cameraWidth.constant, height: cameraHeight.constant)
                guard let croppedCg = croppedImage.cgImage else { return }
                
                guard let input: AVCaptureInput = captureSession.inputs.first else { return }
                guard let currentInput = input as? AVCaptureDeviceInput else { return}
                
                if currentInput.device.position == .back {
                    if orientation == .landscapeLeft {
                        orientedImage = UIImage(cgImage: croppedCg, scale: 1, orientation: .left)
                    } else if orientation == .landscapeRight {
                         orientedImage = UIImage(cgImage: croppedCg, scale: 1, orientation: .right)
                    } else if orientation == .portraitUpsideDown {
                        orientedImage = UIImage(cgImage: croppedCg, scale: 1, orientation: .down)
                    } else {
                        orientedImage = croppedImage
                    }
                } else if currentInput.device.position == .front {
                    if orientation == .landscapeLeft {
                        orientedImage = UIImage(cgImage: croppedCg, scale: 1, orientation: .right)
                    } else if orientation == .landscapeRight {
                         orientedImage = UIImage(cgImage: croppedCg, scale: 1, orientation: .left)
                    } else if orientation == .portraitUpsideDown {
                        orientedImage = UIImage(cgImage: croppedCg, scale: 1, orientation: .down)
                    } else {
                        orientedImage = croppedImage
                    }
                }
                
                self.image = orientedImage
                capturedImage.image = orientedImage
                UIImageWriteToSavedPhotosAlbum(orientedImage, nil, nil, nil)
            }
        }
    }
    
    private func cropImage(sourceImage: UIImage, width: CGFloat, height: CGFloat) -> UIImage {
        let inputSize: CGSize = sourceImage.size
        let width: CGFloat = ceil(width)
        let height: CGFloat = ceil(height)
        var outputSize: CGSize = .zero
        outputSize = CGSize(width: width, height: height)
        let scale: CGFloat = max(width / inputSize.width, height / inputSize.height)
        let scaledInputSize: CGSize = CGSize(width: inputSize.width * scale, height: inputSize.height * scale)
        let center: CGPoint = CGPoint(x: outputSize.width/2.0, y: outputSize.height/2.0)
        let outputRect: CGRect = CGRect(x: center.x - scaledInputSize.width/2.0, y: center.y - scaledInputSize.height/2.0, width: scaledInputSize.width, height: scaledInputSize.height)
        UIGraphicsBeginImageContextWithOptions(outputSize, true, 0)
        sourceImage.draw(in: outputRect)
        guard let outImage: UIImage = UIGraphicsGetImageFromCurrentImageContext() else { return UIImage() }
        UIGraphicsEndImageContext()
        return outImage
    }
}


//
//  ViewController.swift
//  Camera App
//
//  Created by Mahnoor Khan on 03/10/2019.
//  Copyright © 2019 Mahnoor Khan. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    @IBOutlet weak var cameraView       : UIView!
    @IBOutlet weak var takePhoto        : UIButton!
    @IBOutlet weak var cameraPosition   : UIButton!
    @IBOutlet weak var flashStatus      : UIButton!
    @IBOutlet weak var capturedImage    : UIImageView!
    @IBOutlet weak var timerLabel       : UILabel!
    
    @IBOutlet weak var btnHeight        : NSLayoutConstraint!
    @IBOutlet weak var btnWidth         : NSLayoutConstraint!
    @IBOutlet weak var cameraHeight     : NSLayoutConstraint!
    @IBOutlet weak var cameraWidth      : NSLayoutConstraint!
    
    var captureSession                  = AVCaptureSession()
    var videoPreviewLayer               : AVCaptureVideoPreviewLayer?
    var capturePhotoOutput              = AVCapturePhotoOutput()
    var flashMode                       = AVCaptureDevice.FlashMode.off
    
    let movieOutput                     = AVCaptureMovieFileOutput()
    
    var heightforcamera                 : CGFloat?
    
    var image                           : UIImage?
    
    var counterSecond                   = 0
    var counterMinute                   = 0
    var counterHour                     = 0
    var timer                           = Timer()
    var isPlaying                       = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        heightforcamera = view.frame.height
        initButton()
        setOrientation()
        initUI(.back)
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
        let longGesture = UILongPressGestureRecognizer(target: self, action: #selector(long(recognizer:)))
        takePhoto.addGestureRecognizer(longGesture)
        cameraWidth.constant = view.frame.width
        cameraHeight.constant = heightforcamera!
    }
    
    @objc func long(recognizer: UILongPressGestureRecognizer) {
        if (recognizer.state == UIGestureRecognizer.State.began) {
            recordVideo()
        } else {
            if (recognizer.state == UIGestureRecognizer.State.cancelled || recognizer.state == UIGestureRecognizer.State.failed || recognizer.state == UIGestureRecognizer.State.ended) {
                stopVideo()
            }
        }
        
    }
    
    @IBAction func capture(_ sender: UIButton) {
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isAutoStillImageStabilizationEnabled = true
        photoSettings.isHighResolutionPhotoEnabled = true
        if capturePhotoOutput.supportedFlashModes.contains(AVCaptureDevice.FlashMode(rawValue: self.flashMode.rawValue)!) {
            photoSettings.flashMode = self.flashMode
        }
        capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    @IBAction func switchCamera(_ sender: UIButton) {
        guard let input: AVCaptureInput = captureSession.inputs.first else { return }
        guard let currentInput = input as? AVCaptureDeviceInput else { return }
        removeInputs()
        captureSession.stopRunning()
        if currentInput.device.position == .back {
            initUI(.front)
            cameraPosition.setTitle("  Front  ", for: .normal)
        } else if currentInput.device.position == .front {
            initUI(.back)
            cameraPosition.setTitle("  Rear  ", for: .normal)
        }
    }
    
    @IBAction func changeFlashStatus(_ sender: Any) {
        switch flashMode {
        case .off:
            flashMode = .on
            flashStatus.setImage(#imageLiteral(resourceName: "flashOn"), for: .normal)
        case .on:
            flashMode = .off
            flashStatus.setImage(#imageLiteral(resourceName: "flashOff"), for: .normal)
        case .auto:
            flashMode = .auto
            flashStatus.setTitle("  Flash: Auto  ", for: .normal)
        @unknown default:
            break
        }
    }
}

extension ViewController {
    func initButton() {
        takePhoto.layer.cornerRadius = btnWidth.constant / 2
        takePhoto.layer.masksToBounds = true
        
        flashStatus.layer.cornerRadius = flashStatus.frame.width / 2
        flashStatus.layer.masksToBounds = true
    }
    
    func initUI(_ position: AVCaptureDevice.Position) {
        timerLabel.text = ""
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else { return }
        
        guard let microphone = AVCaptureDevice.default(for: AVMediaType.audio) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            let micInput = try AVCaptureDeviceInput(device: microphone)
            if captureSession.canAddInput(micInput) {
                captureSession.addInput(micInput)
            }
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
    
    @objc func UpdateTimer() {
        counterSecond = counterSecond + 1
        if counterSecond == 60 {
            counterSecond = 0
            counterMinute += 1
            if counterMinute == 60 {
                counterMinute = 0
                counterHour += 1
            }
        }
        timerLabel.text = "  \(counterHour):\(counterMinute):\(counterSecond)  "
        timerLabel.text = "  \(counterHour):\(counterMinute):\(counterSecond)  "
    }
    
    func stopVideo() {
        if movieOutput.isRecording == true {
            takePhoto.backgroundColor = UIColor.white
            btnWidth.constant = 60
            btnHeight.constant = 60
            initButton()
            takePhoto.layer.removeAllAnimations()
            movieOutput.stopRecording()
            timer.invalidate()
            isPlaying = false
            counterSecond = 0
            counterMinute = 0
            counterHour = 0
            timerLabel.text = ""
        }
    }
    
    func recordVideo() {
        if movieOutput.isRecording == false {
            self.takePhoto.backgroundColor = UIColor.red
            self.btnWidth.constant = 80
            self.btnHeight.constant = 80
            UIView.animate(withDuration: 2, delay: 1, options: .repeat, animations: {
                self.view.layoutSubviews()
                self.initButton()
            }, completion: nil)
            
            timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(UpdateTimer), userInfo: nil, repeats: true)

            guard let connection = movieOutput.connection(with: AVMediaType.video) else { return }

            if (connection.isVideoOrientationSupported) {
                connection.videoOrientation = currentVideoOrientation()
            }

            if (connection.isVideoStabilizationSupported) {
                connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.auto
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
            stopVideo()
        }
    }
}

extension ViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if (error != nil) {
            print("Error recording movie: \(error!.localizedDescription)")
        } else {
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


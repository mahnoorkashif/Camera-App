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
    @IBOutlet weak var cameraMode       : UIButton!
    @IBOutlet weak var flashStatus      : UIButton!
    @IBOutlet weak var capturedImage    : UIImageView!
    
    @IBOutlet weak var cameraHeight     : NSLayoutConstraint!
    @IBOutlet weak var cameraWidth      : NSLayoutConstraint!
    
    var captureSession                  = AVCaptureSession()
    var videoPreviewLayer               : AVCaptureVideoPreviewLayer?
    var capturePhotoOutput              = AVCapturePhotoOutput()
    var flashMode                       = AVCaptureDevice.FlashMode.off
    
    let heightforcamera                 : CGFloat = 450
    
    var image                           : UIImage = UIImage()
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
    
    @IBAction func captureImage(_ sender: UIButton) {
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
        guard let currentInput = input as? AVCaptureDeviceInput else { return}
        
        if currentInput.device.position == .back {
            removeInputs()
            captureSession.stopRunning()
            initUI(.front)
            cameraMode.setTitle("  Front  ", for: .normal)
        } else if currentInput.device.position == .front {
            removeInputs()
            captureSession.stopRunning()
            initUI(.back)
            cameraMode.setTitle("  Rear  ", for: .normal)
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
}

extension ViewController {
    func initButton() {
        takePhoto.layer.cornerRadius = takePhoto.frame.size.width/2
        takePhoto.layer.masksToBounds = true
    }
    
    func initUI(_ position: AVCaptureDevice.Position) {
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
    
    func addOutput() {
        capturePhotoOutput.isHighResolutionCaptureEnabled = true
        captureSession.addOutput(capturePhotoOutput)
    }
    
    func removeInputs() {
        for input in captureSession.inputs {
            captureSession.removeInput(input)
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


//
//  ViewController.swift
//  MLKitTest
//
//  Created by Mathias Claassen on 6/5/18.
//  Copyright © 2018 Xmartlabs. All rights reserved.
//

import AVFoundation
import FirebaseMLVision
import UIKit

class ViewController: BaseController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var toggleCameraButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var resultLabel: UILabel!
    let options = VisionLabelDetectorOptions(
        confidenceThreshold: Constants.labelConfidenceThreshold
    )
    lazy var vision = Vision.vision()
    var labelDetector: VisionLabelDetector!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        labelDetector = vision.labelDetector(options: options)

        // Add Video sublayer
        let layer = AVCaptureVideoPreviewLayer(session: CaptureController.instance.captureSession)
        layer.frame = videoView.bounds
        videoView.layer.addSublayer(layer)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let uiImage = info[UIImagePickerControllerOriginalImage] as? UIImage {

            imageView.image = uiImage
            let image = VisionImage(image: uiImage)
            detect(image: image)
            picker.dismiss(animated: true, completion: nil)
        }
    }

    override func run(buffer: CMSampleBuffer?) {
        if let buffer = buffer {
            let image = VisionImage(buffer: buffer)
            let metadata = VisionImageMetadata()
            metadata.orientation = .topLeft
            image.metadata = metadata
            detect(image: image)
        }
    }

    func detect(image: VisionImage) {
        labelDetector.detect(in: image) { (labels, error) in
            self.runQueue.pop()
            guard error == nil, let labels = labels, !labels.isEmpty else {
                // Error.
                self.resultLabel.text = "No idea"
                return
            }
            self.resultLabel.text = labels.reduce("") { $0 + "\($1.label) (\($1.confidence))\n" }
        }
    }

    @IBAction func selectImage(_ sender: Any) {
        stopVideo()
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }

    func stopVideo() {
        CaptureController.instance.stopVideoCapture()
        view.bringSubview(toFront: imageView)
        toggleCameraButton.setTitle("Start video", for: .normal)
    }

    func startVideo() {
        CaptureController.instance.startVideoCapture()
        view.bringSubview(toFront: videoView)
        toggleCameraButton.setTitle("Stop video", for: .normal)
    }

    @IBAction func toggleCamera(_ sender: Any) {
        if CaptureController.instance.captureSession.isRunning {
            stopVideo()
        } else {
            startVideo()
        }
    }

}


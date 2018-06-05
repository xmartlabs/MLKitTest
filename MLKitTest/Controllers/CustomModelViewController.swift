//
//  CustomModelViewController.swift
//  MLKitTest
//
//  Created by Mathias Claassen on 6/6/18.
//  Copyright © 2018 Xmartlabs. All rights reserved.
//

import AVFoundation
import FirebaseMLModelInterpreter
import UIKit

class CustomModelViewController: BaseController {

    @IBOutlet weak var modelControl: UISegmentedControl!
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var fpsSlider: UISlider!
    @IBOutlet weak var totalLabel: UILabel!

    // models
    var interpreter: ModelInterpreter!
    var ioOptions: ModelInputOutputOptions!
    var coreMLMobilenet: Mobilenet!
    var labels: [String]!
    var runMLKit = true

    var frameTimer: Timer!
    var frames = 0

    let resizeTimer = TimeChecker()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        labels = readClassLabels("mobilenet_labels")
        fpsSlider.addTarget(self, action: #selector(changeFPS(_:)), for: .valueChanged)

        let layer = AVCaptureVideoPreviewLayer(session: CaptureController.instance.captureSession)
        layer.frame = videoView.bounds
        videoView.layer.addSublayer(layer)

        resizeTimer.cleanAfterCount = 100
        resizeTimer.onClean = {
            print("Resize: \($0)")
        }

        setupCoreMLModel()
        setupSegmentedControl()
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.totalLabel.text = "\(self!.frames) real FPS"
            self?.frames = 0
        }

    }

    func setupSegmentedControl() {
        modelControl.addTarget(self, action: #selector(toggleModel(_:)), for: .valueChanged)
    }

    override func modelSetup() {
        let conditions = ModelDownloadConditions(wiFiRequired: true, idleRequired: false)
        let cloudModelSource = CloudModelSource(
            modelName: Constants.Models.cloudMobilenet,
            enableModelUpdates: true,
            initialConditions: conditions,
            updateConditions: conditions
        )
        _ = ModelManager.modelManager().register(cloudModelSource)

        guard let modelPath = Bundle.main.path(forResource: "mobilenet", ofType: "tflite") else {
            return
        }
        let localModelSource = LocalModelSource(modelName: Constants.Models.localMobilenet,
                                                path: modelPath)
        ModelManager.modelManager().register(localModelSource)

        let options = ModelOptions(
            cloudModelName: Constants.Models.cloudMobilenet,
            localModelName: Constants.Models.localMobilenet
        )
        interpreter = ModelInterpreter(options: options)

        ioOptions = ModelInputOutputOptions()
        do {
            try ioOptions.setInputFormat(index: 0, type: ModelElementType.uInt8, dimensions: [1, 224, 224, 3])
            try ioOptions.setOutputFormat(index: 0, type: ModelElementType.uInt8, dimensions: [1, NSNumber(value: Constants.mobilenetLabelCount)])
        } catch let error as NSError {
            print("Failed to set input or output format with error: \(error.localizedDescription)")
        }
    }

    func setupCoreMLModel() {
        coreMLMobilenet = Mobilenet()
    }

    override func run(buffer: CMSampleBuffer?) {
        guard let buffer = buffer, let interpreter = self.interpreter else {
            return
        }
        if runMLKit {
            DispatchQueue.global().async { [weak self] in
                let input = ModelInputs()
                do {
                    try input.addInput(buffer.toData(size: 224))
                } catch let error as NSError {
                    print("Failed to add input: \(error.localizedDescription)")
                }


                guard let `self` = self else { return }
                let start = Date()
                interpreter.run(inputs: input, options: self.ioOptions) { [weak self] outputs, error in
                    self?.timeChecker.add(Date().timeIntervalSince(start))
                    self?.frames += 1
                    self?.runQueue.pop()
                    guard error == nil, let `self` = self, let outputs = outputs,
                        let predictions = (try! outputs.output(index: 0) as? NSArray)?[0] as? [UInt8] else { return }
                    let maximum = predictions.max()!
                    DispatchQueue.main.async {
                        self.resultLabel.text = self.labels[predictions.index(of: maximum)!]
                    }
                }
            }
        } else {
            let pixelBuffer = resizePixelBuffer(CMSampleBufferGetImageBuffer(buffer)!, width: 224, height: 224)!
            DispatchQueue.global().async {
                do {
                    let start = Date()

                    let prediction = try self.coreMLMobilenet.prediction(input__0: pixelBuffer)
                    self.timeChecker.add(Date().timeIntervalSince(start))
                    self.frames += 1
                    self.runQueue.pop()
                    let floatPtr = prediction.MobilenetV2__Predictions__Reshape_1__0.dataPointer
                        .bindMemory(to: Double.self, capacity: Constants.mobilenetLabelCount)
                    let arr = Array(UnsafeBufferPointer(start: floatPtr, count: Constants.mobilenetLabelCount))
                    let maximum = arr.max()!
                    DispatchQueue.main.async {
                        self.resultLabel.text = self.labels[arr.index(of: maximum)!]
                    }
                } catch let error as NSError {
                    self.runQueue.pop()
                    print("Failed to predict: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc func toggleModel(_: Any) {
        runMLKit = !runMLKit
    }

    @objc func changeFPS(_: Any) {
        fpsSlider.value = round(fpsSlider.value)
        CaptureController.instance.setMaxFPS(fps: Double(fpsSlider.value * 30))
    }

}

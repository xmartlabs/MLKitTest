//
//  BaseController.swift
//  MLKitTest
//
//  Created by Mathias Claassen on 6/6/18.
//  Copyright © 2018 Xmartlabs. All rights reserved.
//

import AVFoundation
import MetalPerformanceShaders
import UIKit

class BaseController: UIViewController {

    @IBOutlet weak var fpsLabel: UILabel!

    var networkQueue: DispatchQueue
    var resultQueue: DispatchQueue
    var runQueue = RunQueue(maxConcurrent: 2)
    var timeChecker = TimeChecker()

    required init?(coder aDecoder: NSCoder) {
        networkQueue = DispatchQueue(label: "com.xmartlabs.mlkittest.neuralqueue",
                                     qos: .userInitiated,
                                     target: nil)
        resultQueue = DispatchQueue(label: "com.xmartlabs.mlkittest.resultqueue",
                                    qos: .userInitiated,
                                    target: nil)
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.modelSetup()
        CaptureController.instance.capturedFrame = { [weak self] buffer in
            guard let `self` = self, self.runQueue.push() else { return }
            DispatchQueue.global().async { [unowned self] in
                    self.run(buffer: buffer)
            }
        }
        timeChecker.onClean = { [weak self] avg in
            DispatchQueue.main.async {
                self?.fpsLabel.text = "Avg time: \(String(format: "%.4f", avg)) (\(String(format: "%.3f", 1/avg)) FPS)"
            }
        }
        
        // Wait a sec and start the camera
        DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: UInt64(1e9))) {
            CaptureController.instance.startVideoCapture()
        }
    }

    deinit {
        CaptureController.instance.stopVideoCapture()
    }

    func modelSetup() {
        //Please override
    }

    func run(buffer: CMSampleBuffer?) {
        // Please override
    }

}

//
//  CaptureController.swift
//  MLKitTest
//
//  Created by Mathias Claassen on 6/6/18.
//  Copyright © 2018 Xmartlabs. All rights reserved.
//

import AVFoundation

class CaptureController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    static let instance = CaptureController()

    // AVFoundation variables
    var captureSession = AVCaptureSession()
    lazy var videoDevice: AVCaptureDevice! = {
        let x = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInDuoCamera,
                                                               AVCaptureDevice.DeviceType.builtInWideAngleCamera,
                                                               AVCaptureDevice.DeviceType.builtInTelephotoCamera],
                                                 mediaType: AVMediaType.video,
                                                 position: AVCaptureDevice.Position.back).devices
        return x.first
    }()

    var movieOutput: AVCaptureVideoDataOutput!
    var capturedFrame: ((CMSampleBuffer) -> Void)!
    private var initialized = false

    private override init() {}

    func startVideoCapture() {
        if !initialized {
            initialized = true
            let capturePreset = AVCaptureSession.Preset.medium

            guard videoDevice.supportsSessionPreset(capturePreset) else {
                print("Device does not support medium quality")
                return
            }

            let outputSettings: [String: Any] = [String(describing: kCVPixelBufferPixelFormatTypeKey): NSNumber(value: kCVPixelFormatType_32BGRA)]

            captureSession.beginConfiguration()

            // Set video quality
            captureSession.sessionPreset = capturePreset

            //add device inputs (front camera and mic)
            try? captureSession.addInput(AVCaptureDeviceInput(device: videoDevice))

            //add output to get the frames
            movieOutput = AVCaptureVideoDataOutput()
            movieOutput.videoSettings = outputSettings
            movieOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .background))
            movieOutput.alwaysDiscardsLateVideoFrames = true
            captureSession.addOutput(movieOutput)

            //start session
            captureSession.commitConfiguration()
            setMirroring()
            setMaxFPS(fps: 60.0)
        }
        captureSession.startRunning()

    }

    func stopVideoCapture() {
        captureSession.stopRunning()
    }

    func setMirroring() {
        for conn in movieOutput.connections {
            for port in conn.inputPorts {
                if port.mediaType == AVMediaType.video, conn.isVideoMirroringSupported {
                    conn.isVideoMirrored = videoDevice.position == .front
                }
            }
        }
    }

    func setMaxFPS(fps maxFpsDesired: Double = 60.0) {
        var finalFormat: AVCaptureDevice.Format!
        var maxFps: Double = 0
        var width: Int32 = 0
        for vFormat in videoDevice.formats {
            var ranges      = vFormat.videoSupportedFrameRateRanges
            let frameRates  = ranges[0]
            let dims = CMVideoFormatDescriptionGetDimensions(vFormat.formatDescription)
            if (frameRates.maxFrameRate > maxFps || (frameRates.maxFrameRate == maxFps && dims.width < width))
                && frameRates.maxFrameRate <= maxFpsDesired {
                maxFps = frameRates.maxFrameRate
                finalFormat = vFormat
                width = CMVideoFormatDescriptionGetDimensions(finalFormat.formatDescription).width
            }
        }
        if maxFps != 0 {
            let timeValue = Int64(1200.0 / maxFps)
            let timeScale: Int32 = 1200
            try! videoDevice.lockForConfiguration()
            videoDevice.activeFormat = finalFormat
            videoDevice.activeVideoMinFrameDuration = CMTimeMake(timeValue, timeScale)
            videoDevice.activeVideoMaxFrameDuration = CMTimeMake(timeValue, timeScale)
            videoDevice.unlockForConfiguration()
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    var acct = 0
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        inc()
        guard 1 == CMSampleBufferGetNumSamples(sampleBuffer) else {
            return
        }
        guard connection.videoOrientation == .portrait else {
            connection.videoOrientation = .portrait
            return
        }

        capturedFrame(sampleBuffer)
    }

    func inc() {
        acct += 1
        if acct == 60 {
            print(Date().timeIntervalSinceReferenceDate)
            acct = 0
        }
    }

    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        print("Dropped frame")
//        inc()
    }

}

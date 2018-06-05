//
//  CVPixelBuffer.swift
//  MLKitTest
//
//  Created by Mathias Claassen on 6/8/18.
//  Copyright © 2018 Xmartlabs. All rights reserved.
//

import Accelerate
import CoreImage

/**
 Resize a pixelBuffer, optionally remove alpha channel and return byte pointer.
 */
public func resizedData(_ srcPixelBuffer: CVPixelBuffer,
                        cropX: Int,
                        cropY: Int,
                        cropWidth: Int,
                        cropHeight: Int,
                        scaleWidth: Int,
                        scaleHeight: Int,
                        removeAlpha: Bool) -> UnsafeMutableRawPointer? {

    CVPixelBufferLockBaseAddress(srcPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    guard let srcData = CVPixelBufferGetBaseAddress(srcPixelBuffer) else {
        print("Error: could not get pixel buffer base address")
        return nil
    }
    let srcBytesPerRow = CVPixelBufferGetBytesPerRow(srcPixelBuffer)
    let offset = cropY*srcBytesPerRow + cropX*4
    var srcBuffer = vImage_Buffer(data: srcData.advanced(by: offset),
                                  height: vImagePixelCount(cropHeight),
                                  width: vImagePixelCount(cropWidth),
                                  rowBytes: srcBytesPerRow)

    let destBytesPerRow = scaleWidth*4
    guard let destData = malloc(scaleHeight*destBytesPerRow) else {
        print("Error: out of memory")
        return nil
    }
    var destBuffer = vImage_Buffer(data: destData,
                                   height: vImagePixelCount(scaleHeight),
                                   width: vImagePixelCount(scaleWidth),
                                   rowBytes: destBytesPerRow)

    let error = vImageScale_ARGB8888(&srcBuffer, &destBuffer, nil, vImage_Flags(0))
    CVPixelBufferUnlockBaseAddress(srcPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    if error != kvImageNoError {
        print("Error:", error)
        free(destData)
        return nil
    }

    if removeAlpha {
        guard let newBuffer = stripAlpha(buffer: &destBuffer) else {
            return nil
        }
        free(destData)
        destBuffer = newBuffer
    }

    return destBuffer.data
}

/**
 Resizes a CVPixelBuffer to a new width and height.
 */
public func resizedData(_ pixelBuffer: CVPixelBuffer,
                        width: Int, height: Int, removeAlpha: Bool = false) -> UnsafeMutableRawPointer? {
    return resizedData(pixelBuffer, cropX: 0, cropY: 0,
                       cropWidth: CVPixelBufferGetWidth(pixelBuffer),
                       cropHeight: CVPixelBufferGetHeight(pixelBuffer),
                       scaleWidth: width, scaleHeight: height, removeAlpha: removeAlpha)
}

public func stripAlpha(buffer: inout vImage_Buffer) -> vImage_Buffer? {
    guard let destData = malloc(Int(buffer.height*buffer.width*3)) else {
        print("Error: out of memory")
        return nil
    }
    var destBuffer = vImage_Buffer(data: destData,
                                   height: buffer.height,
                                   width: buffer.width,
                                   rowBytes: buffer.rowBytes * 3 / 4)

    let error = vImageConvert_RGBA8888toRGB888(&buffer, &destBuffer, vImage_Flags(0))
    if error != kvImageNoError {
        free(destData)
        return nil
    }
    return destBuffer
}

// The following functions are copied from CoreMLHelpers (https://github.com/hollance/CoreMLHelpers/blob/master/CoreMLHelpers/CVPixelBuffer%2BHelpers.swift)
public func resizePixelBuffer(_ srcPixelBuffer: CVPixelBuffer,
                              cropX: Int,
                              cropY: Int,
                              cropWidth: Int,
                              cropHeight: Int,
                              scaleWidth: Int,
                              scaleHeight: Int) -> CVPixelBuffer? {

    CVPixelBufferLockBaseAddress(srcPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    guard let srcData = CVPixelBufferGetBaseAddress(srcPixelBuffer) else {
        print("Error: could not get pixel buffer base address")
        return nil
    }
    let srcBytesPerRow = CVPixelBufferGetBytesPerRow(srcPixelBuffer)
    let offset = cropY*srcBytesPerRow + cropX*4
    var srcBuffer = vImage_Buffer(data: srcData.advanced(by: offset),
                                  height: vImagePixelCount(cropHeight),
                                  width: vImagePixelCount(cropWidth),
                                  rowBytes: srcBytesPerRow)

    let destBytesPerRow = scaleWidth*4
    guard let destData = malloc(scaleHeight*destBytesPerRow) else {
        print("Error: out of memory")
        return nil
    }
    var destBuffer = vImage_Buffer(data: destData,
                                   height: vImagePixelCount(scaleHeight),
                                   width: vImagePixelCount(scaleWidth),
                                   rowBytes: destBytesPerRow)

    let error = vImageScale_ARGB8888(&srcBuffer, &destBuffer, nil, vImage_Flags(0))
    CVPixelBufferUnlockBaseAddress(srcPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    if error != kvImageNoError {
        print("Error:", error)
        free(destData)
        return nil
    }

    let releaseCallback: CVPixelBufferReleaseBytesCallback = { _, ptr in
        if let ptr = ptr {
            free(UnsafeMutableRawPointer(mutating: ptr))
        }
    }

    let pixelFormat = CVPixelBufferGetPixelFormatType(srcPixelBuffer)
    var dstPixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreateWithBytes(nil, scaleWidth, scaleHeight,
                                              pixelFormat, destData,
                                              destBytesPerRow, releaseCallback,
                                              nil, nil, &dstPixelBuffer)
    if status != kCVReturnSuccess {
        print("Error: could not create new pixel buffer")
        free(destData)
        return nil
    }
    return dstPixelBuffer
}

/**
 Resizes a CVPixelBuffer to a new width and height.
 */
public func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer,
                              width: Int, height: Int) -> CVPixelBuffer? {
    return resizePixelBuffer(pixelBuffer, cropX: 0, cropY: 0,
                             cropWidth: CVPixelBufferGetWidth(pixelBuffer),
                             cropHeight: CVPixelBufferGetHeight(pixelBuffer),
                             scaleWidth: width, scaleHeight: height)
}

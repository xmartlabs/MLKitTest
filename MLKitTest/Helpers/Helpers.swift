//
//  Helpers.swift
//  MLKitTest
//
//  Created by Mathias Claassen on 6/6/18.
//  Copyright © 2018 Xmartlabs. All rights reserved.
//

import AVFoundation
import Accelerate
import CoreImage
import UIKit

class RunQueue {

    private var lock = NSLock()
    var maxConcurrent: Int
    var count = 0

    init(maxConcurrent: Int) {
        self.maxConcurrent = maxConcurrent
    }

    func pop() {
        lock.lock()
        if count > 0 {
            count -= 1
        }
        lock.unlock()
    }

    func push() -> Bool {
        lock.lock()
        if count < maxConcurrent {
            count += 1
            lock.unlock()
            return true
        }
        lock.unlock()
        return false
    }

}

class TimeChecker {

    private var times: [TimeInterval] = []
    var cleanAfterCount = 60
    var onClean: ((TimeInterval) -> Void)?

    func add(_ interval: TimeInterval) {
        times.append(interval)
        if cleanAfterCount > 0, times.count == cleanAfterCount {
            onClean?(average())
        }
    }

    func average(flush: Bool = true) -> TimeInterval {
        let ret = times.reduce(0, +) / Double(times.count)
        if flush {
            times.removeAll()
        }
        return ret
    }
}

func readClassLabels(_ filename: String) -> [String]? {
    guard let path = Bundle.main.path(forResource: filename, ofType: "txt") else {
        return nil
    }

    do {
        let data = try String(contentsOfFile: path, encoding: .utf8)
        let myStrings = data.components(separatedBy: .newlines)
        return myStrings
    } catch {
        print(error)
        return nil
    }
}

extension Array where Element: Comparable {

    func top(_ count: Int) -> [Int] {
        return [Int](self.indices.sorted { self[$0] > self[$1] }.prefix(count))
    }
    
}

extension CMSampleBuffer {

    func toData(size: Int = 256) -> Data {
        let imageBuffer = CMSampleBufferGetImageBuffer(self)!
        let resizedDataPointer = resizedData(imageBuffer, width: size, height: size, removeAlpha: true)!
        let data = Data(bytes: resizedDataPointer, count: size * size * 3)
        free(resizedDataPointer)
        return data
    }
}

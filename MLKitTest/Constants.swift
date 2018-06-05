//
//  Constants.swift
//  MLKitTest
//
//  Created by Mathias Claassen on 6/5/18.
//  Copyright © 2018 Xmartlabs. All rights reserved.
//

import Foundation


struct Constants {
    
    static let labelConfidenceThreshold : Float = 0.3
    static let mobilenetLabelCount = 1001

    struct Models {
        static let cloudMobilenet = "mobilenet"
        static let localMobilenet = "my_local_model"
    }
}

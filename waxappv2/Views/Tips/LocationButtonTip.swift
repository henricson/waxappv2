//
//  LocationButtonTip.swift
//  waxappv2
//
//  Created by Herman Henriksen on 07/01/2026.
//

import TipKit
import SwiftUI


struct LocationButtonTip: Tip {
    var title: Text {
        Text("Get prediction from your location")
    }


    var message: Text? {
        Text("Get the most accurate prediction based on your current location.")
    }

    var image: Image? {
        Image(systemName: "location")
    }
}

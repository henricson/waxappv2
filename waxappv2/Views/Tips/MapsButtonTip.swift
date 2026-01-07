//
//  LocationButtonTip.swift
//  waxappv2
//
//  Created by Herman Henriksen on 07/01/2026.
//

import TipKit
import SwiftUI


struct MapButtonTip: Tip {
    var title: Text {
        Text("Select location yourself")
    }


    var message: Text? {
        Text("Get the most accurate prediction based on a selection on a map.")
    }

    var image: Image? {
        Image(systemName: "map")
    }
}

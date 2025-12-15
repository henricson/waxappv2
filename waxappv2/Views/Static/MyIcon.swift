//
//  MyIcon.swift
//  waxappv2
//
//  Created by Herman Henriksen on 28/11/2025.
//
import SwiftUI

struct KlisterCanGraphic: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.86921*width, y: 0.93577*height))
        path.addLine(to: CGPoint(x: 0.86935*width, y: 0.93576*height))
        path.addLine(to: CGPoint(x: 0.86935*width, y: 0.96875*height))
        path.addLine(to: CGPoint(x: 0.86921*width, y: 0.96875*height))
        path.addCurve(to: CGPoint(x: 0.50251*width, y: height), control1: CGPoint(x: 0.86395*width, y: 0.98609*height), control2: CGPoint(x: 0.70179*width, y: height))
        path.addCurve(to: CGPoint(x: 0.13581*width, y: 0.96875*height), control1: CGPoint(x: 0.30324*width, y: height), control2: CGPoint(x: 0.14107*width, y: 0.98609*height))
        path.addLine(to: CGPoint(x: 0.13568*width, y: 0.96875*height))
        path.addLine(to: CGPoint(x: 0.13568*width, y: 0.93576*height))
        path.addLine(to: CGPoint(x: 0.13581*width, y: 0.93577*height))
        path.addLine(to: CGPoint(x: 0.13576*width, y: 0.93556*height))
        path.addCurve(to: CGPoint(x: 0.50251*width, y: 0.96701*height), control1: CGPoint(x: 0.1398*width, y: 0.95299*height), control2: CGPoint(x: 0.30245*width, y: 0.96701*height))
        path.addCurve(to: CGPoint(x: 0.86927*width, y: 0.93556*height), control1: CGPoint(x: 0.70257*width, y: 0.96701*height), control2: CGPoint(x: 0.86522*width, y: 0.95299*height))
        path.addCurve(to: CGPoint(x: 0.86921*width, y: 0.93577*height), control1: CGPoint(x: 0.86925*width, y: 0.93563*height), control2: CGPoint(x: 0.86924*width, y: 0.9357*height))
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: 0.13568*width, y: 0.90278*height, width: 0.73367*width, height: 0.06424*height))
        path.move(to: CGPoint(x: 0.21106*width, y: 0.86892*height))
        path.addLine(to: CGPoint(x: 0.79899*width, y: 0.86892*height))
        path.addLine(to: CGPoint(x: 0.79899*width, y: 0.93229*height))
        path.addCurve(to: CGPoint(x: 0.50503*width, y: 0.94965*height), control1: CGPoint(x: 0.7721*width, y: 0.94387*height), control2: CGPoint(x: 0.67411*width, y: 0.94965*height))
        path.addCurve(to: CGPoint(x: 0.21106*width, y: 0.93229*height), control1: CGPoint(x: 0.33594*width, y: 0.94965*height), control2: CGPoint(x: 0.23795*width, y: 0.94387*height))
        path.addLine(to: CGPoint(x: 0.21106*width, y: 0.86892*height))
        path.closeSubpath()
        // Begin lid
        path.move(to: CGPoint(x: 0.01539*width, y: 0))
        path.addLine(to: CGPoint(x: 0.98467*width, y: 0))
        path.addCurve(to: CGPoint(x: 0.99974*width, y: 0.00521*height), control1: CGPoint(x: 0.99299*width, y: 0), control2: CGPoint(x: 0.99974*width, y: 0.00233*height))
        path.addCurve(to: CGPoint(x: 0.99974*width, y: 0.0053*height), control1: CGPoint(x: 0.99974*width, y: 0.00524*height), control2: CGPoint(x: 0.99974*width, y: 0.00527*height))
        path.addLine(to: CGPoint(x: 0.95754*width, y: 0.86467*height))
        path.addCurve(to: CGPoint(x: 0.94246*width, y: 0.86979*height), control1: CGPoint(x: 0.9574*width, y: 0.86751*height), control2: CGPoint(x: 0.95069*width, y: 0.86979*height))
        path.addLine(to: CGPoint(x: 0.06753*width, y: 0.86979*height))
        path.addCurve(to: CGPoint(x: 0.05245*width, y: 0.86469*height), control1: CGPoint(x: 0.05932*width, y: 0.86979*height), control2: CGPoint(x: 0.05263*width, y: 0.86753*height))
        path.addLine(to: CGPoint(x: 0.00032*width, y: 0.00532*height))
        path.addCurve(to: CGPoint(x: 0.01508*width, y: 0), control1: CGPoint(x: 0.00015*width, y: 0.00244*height), control2: CGPoint(x: 0.00675*width, y: 0.00006*height))
        path.addCurve(to: CGPoint(x: 0.01539*width, y: 0), control1: CGPoint(x: 0.01518*width, y: 0), control2: CGPoint(x: 0.01529*width, y: 0))
        path.closeSubpath()
        return path
    }
}

#Preview {
    KlisterCanGraphic()
}

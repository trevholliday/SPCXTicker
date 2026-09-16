//
//  RocketRasterizer.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import CoreGraphics
import SwiftUI

/// Rasterizes a vector rocket into cell masks so it can be lit on a `DotGrid` at any rotation.
enum RocketRasterizer {

    /// Lit cells for the rocket body and its exhaust flame, rotated clockwise by `angle` from pointing straight up.
    static func masks(width: Int, height: Int, angle: Angle) -> Masks {
        let body = coverage(width: width, height: height, angle: angle) { context in
            context.addPath(bodyPath)
            context.fillPath(using: .evenOdd)
            context.addPath(finsPath)
            context.fillPath()
        }
        let flame = coverage(width: width, height: height, angle: angle) { context in
            context.addPath(flamePath)
            context.fillPath()
        }
        return Masks(width: width, height: height, body: body.map { $0 >= threshold }, flame: flame.map { $0 >= threshold })
    }
}

// MARK: - Masks

extension RocketRasterizer {
    struct Masks: Equatable {
        let width: Int
        let height: Int
        let body: [Bool]
        let flame: [Bool]
    }
}

// MARK: - Geometry

private extension RocketRasterizer {
    static let supersample = 6
    static let threshold = 0.4

    static var bodyPath: CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 11))
        path.addQuadCurve(to: CGPoint(x: 3, y: 4), control: CGPoint(x: 3, y: 9))
        path.addLine(to: CGPoint(x: 3, y: -6))
        path.addLine(to: CGPoint(x: -3, y: -6))
        path.addLine(to: CGPoint(x: -3, y: 4))
        path.addQuadCurve(to: CGPoint(x: 0, y: 11), control: CGPoint(x: -3, y: 9))
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: -1.4, y: 2.1, width: 2.8, height: 2.8))
        return path
    }

    static var finsPath: CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -3, y: -1))
        path.addLine(to: CGPoint(x: -6.5, y: -7))
        path.addLine(to: CGPoint(x: -3, y: -6))
        path.closeSubpath()
        path.move(to: CGPoint(x: 3, y: -1))
        path.addLine(to: CGPoint(x: 6.5, y: -7))
        path.addLine(to: CGPoint(x: 3, y: -6))
        path.closeSubpath()
        return path
    }

    static var flamePath: CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -2.2, y: -6.5))
        path.addLine(to: CGPoint(x: 0, y: -11.5))
        path.addLine(to: CGPoint(x: 2.2, y: -6.5))
        path.closeSubpath()
        return path
    }

    static func coverage(width: Int, height: Int, angle: Angle, draw: (CGContext) -> Void) -> [Double] {
        let pixelWidth = width * supersample
        let pixelHeight = height * supersample
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: pixelWidth,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return Array(repeating: 0, count: width * height)
        }

        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.setFillColor(gray: 1, alpha: 1)
        context.setShouldAntialias(true)
        context.translateBy(x: CGFloat(pixelWidth) / 2, y: CGFloat(pixelHeight) / 2)
        context.rotate(by: -CGFloat(angle.radians))
        context.scaleBy(x: CGFloat(supersample), y: CGFloat(supersample))
        draw(context)

        guard let data = context.data else { return Array(repeating: 0, count: width * height) }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var result = Array(repeating: 0.0, count: width * height)
        let samples = Double(supersample * supersample * 255)
        for cellY in 0..<height {
            for cellX in 0..<width {
                var sum = 0
                for subY in 0..<supersample {
                    let row = (cellY * supersample + subY) * pixelWidth
                    for subX in 0..<supersample {
                        sum += Int(pixels[row + cellX * supersample + subX])
                    }
                }
                result[cellY * width + cellX] = Double(sum) / samples
            }
        }
        return result
    }
}

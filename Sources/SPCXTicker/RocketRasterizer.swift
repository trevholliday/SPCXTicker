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

    /// Lit cells for the rocket, its exhaust clouds, and crash damage for a flight state at `time` seconds.
    static func masks(width: Int, height: Int, flight: Flight, time: TimeInterval = 0) -> Masks {
        let frame = Int((time * flickerRate).rounded(.down))
        let shift = shift(for: flight, height: height)
        let body = coverage(width: width, height: height, angle: flight.angle, shift: shift) { context in
            context.addPath(bodyPath(isCrashed: flight.isCrashed))
            context.fillPath(using: .evenOdd)
            context.addPath(finsPath(damage: flight.damage))
            context.fillPath()
            context.setFillColor(gray: 0, alpha: 1)
            for dent in dents where flight.damage >= dent.threshold {
                context.fillEllipse(in: dent.rect)
            }
        }
        let flame = coverage(width: width, height: height, angle: flight.angle, shift: shift) { context in
            if let flamePath = flamePath(flight: flight, frame: frame) {
                context.addPath(flamePath)
                context.fillPath()
            }
            drawFire(in: context, flight: flight, frame: frame)
        }
        let clouds = coverage(width: width, height: height, angle: flight.angle, shift: shift) { context in
            drawClouds(in: context, flight: flight, time: time)
        }
        return Masks(
            width: width,
            height: height,
            body: body.map { $0 >= threshold },
            flame: flame.map { $0 >= threshold },
            clouds: clouds.map { $0 >= cloudThreshold ? min($0 / cloudFullLevel, 1) : 0 },
            debris: debris(width: width, height: height, isCrashed: flight.isCrashed)
        )
    }
}

// MARK: - Flight

extension RocketRasterizer {
    struct Flight: Equatable {
        let angle: Angle
        let thrust: Double
        let damage: Double

        static let parked = Flight(angle: .zero, thrust: 0, damage: 0)
        static let fullScalePercent = 100.0
        static let calmPercent = 2.0

        var isCrashed: Bool { damage >= 0.97 }
    }
}

extension RocketRasterizer.Flight {
    init(changePercent: Double) {
        let magnitude = min(log1p(abs(changePercent)) / log1p(Self.fullScalePercent), 1)
        let level = changePercent < 0 ? -magnitude : magnitude
        let drop = max(-changePercent - Self.calmPercent, 0) / (Self.fullScalePercent - Self.calmPercent)
        angle = .degrees(90 - 90 * level)
        thrust = max(level, 0)
        damage = min(drop.squareRoot(), 1)
    }
}

// MARK: - Masks

extension RocketRasterizer {
    struct Masks: Equatable {
        let width: Int
        let height: Int
        let body: [Bool]
        let flame: [Bool]
        let clouds: [Double]
        let debris: [Bool]
    }
}

// MARK: - Geometry

private extension RocketRasterizer {
    static let supersample = 6
    static let threshold = 0.4
    static let cloudThreshold = 0.16
    static let cloudFullLevel = 0.7
    static let flickerRate = 12.0
    static let nozzleY = -6.5
    static let crumpledNoseY = 7.6

    static let dents: [(rect: CGRect, threshold: Double)] = [
        (CGRect(x: 0.8, y: -4.5, width: 2.0, height: 2.0), 0.2),
        (CGRect(x: -2.8, y: 5.6, width: 1.8, height: 1.8), 0.4),
        (CGRect(x: 1.3, y: 0.1, width: 1.8, height: 1.8), 0.55),
        (CGRect(x: -3.1, y: -2.6, width: 2.2, height: 2.2), 0.7),
        (CGRect(x: -0.4, y: -6.2, width: 2.0, height: 2.0), 0.85),
    ]

    static let rubble: [(x: Int, y: Int)] = [(-9, 1), (-6, 1), (-5, 2), (-3, 1), (3, 1), (5, 1), (7, 2), (8, 1)]

    static func shift(for flight: Flight, height: Int) -> Double {
        if flight.isCrashed {
            return Double(height) / 2 - crumpledNoseY - 1.2
        }
        return 4 * max(flight.thrust, flight.damage)
    }

    static func bodyPath(isCrashed: Bool) -> CGPath {
        let path = CGMutablePath()
        if isCrashed {
            path.move(to: CGPoint(x: 3, y: -6))
            path.addLine(to: CGPoint(x: 3, y: 4))
            path.addLine(to: CGPoint(x: 2.2, y: 6.8))
            path.addLine(to: CGPoint(x: 0.8, y: 5.8))
            path.addLine(to: CGPoint(x: -0.6, y: crumpledNoseY))
            path.addLine(to: CGPoint(x: -2.4, y: 6.2))
            path.addLine(to: CGPoint(x: -3, y: 4))
            path.addLine(to: CGPoint(x: -3, y: -6))
        } else {
            path.move(to: CGPoint(x: 0, y: 11))
            path.addQuadCurve(to: CGPoint(x: 3, y: 4), control: CGPoint(x: 3, y: 9))
            path.addLine(to: CGPoint(x: 3, y: -6))
            path.addLine(to: CGPoint(x: -3, y: -6))
            path.addLine(to: CGPoint(x: -3, y: 4))
            path.addQuadCurve(to: CGPoint(x: 0, y: 11), control: CGPoint(x: -3, y: 9))
        }
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: -1.4, y: 2.1, width: 2.8, height: 2.8))
        return path
    }

    static func finsPath(damage: Double) -> CGPath {
        let path = CGMutablePath()
        if damage >= 0.8 {
            path.addLines(between: [CGPoint(x: -3, y: -3.5), CGPoint(x: -4.6, y: -5.2), CGPoint(x: -3, y: -6)])
        } else {
            path.addLines(between: [CGPoint(x: -3, y: -1), CGPoint(x: -6.5, y: -7), CGPoint(x: -3, y: -6)])
        }
        path.closeSubpath()
        if damage >= 0.45 {
            path.addLines(between: [CGPoint(x: 3, y: -1.5), CGPoint(x: 5.6, y: -3.2), CGPoint(x: 4.2, y: -4.6), CGPoint(x: 3, y: -6)])
        } else {
            path.addLines(between: [CGPoint(x: 3, y: -1), CGPoint(x: 6.5, y: -7), CGPoint(x: 3, y: -6)])
        }
        path.closeSubpath()
        return path
    }

    static func flamePath(flight: Flight, frame: Int) -> CGPath? {
        let length: Double
        if flight.damage > 0 {
            guard !flight.isCrashed, noise(frame, 2) >= flight.damage * 0.7 else { return nil }
            length = 1.5 + 3.5 * (1 - flight.damage) + (noise(frame, 1) - 0.5)
        } else {
            length = 5 + 2 * flight.thrust + (noise(frame, 1) - 0.5) * (1 + 2 * flight.thrust)
        }
        let halfWidth = 2.2 + 0.6 * flight.thrust
        let path = CGMutablePath()
        path.addLines(between: [
            CGPoint(x: -halfWidth, y: nozzleY),
            CGPoint(x: 0, y: nozzleY - length),
            CGPoint(x: halfWidth, y: nozzleY),
        ])
        path.closeSubpath()
        return path
    }

    static func drawFire(in context: CGContext, flight: Flight, frame: Int) {
        guard flight.damage >= 0.6 else { return }
        for (index, dent) in dents.enumerated() where index.isMultiple(of: 2) && flight.damage >= dent.threshold {
            let radius = 0.5 + 0.8 * noise(frame, index + 10)
            context.fillEllipse(in: CGRect(x: dent.rect.midX - radius, y: dent.rect.midY - radius, width: radius * 2, height: radius * 2))
        }
        if flight.isCrashed {
            let radius = 1 + 1.2 * noise(frame, 20)
            context.fillEllipse(in: CGRect(x: -radius, y: crumpledNoseY - radius, width: radius * 2, height: radius * 2))
        }
    }

    static func drawClouds(in context: CGContext, flight: Flight, time: TimeInterval) {
        let strength = max(flight.thrust, flight.damage)
        guard strength > 0 else { return }
        let isSmoke = flight.damage > 0
        let count = 3 + Int(strength * 6)
        let length = 4 + (isSmoke ? 14 : 9) * strength
        let spread = 0.5 + (isSmoke ? 4.5 : 8) * strength
        let cycle = time * (isSmoke ? 0.6 : 1.5)
        let puffs = (0..<count).map { index -> (age: Double, x: Double, radius: Double) in
            let phase = cycle + Double(index) / Double(count)
            let age = phase - phase.rounded(.down)
            let drift = noise(Int(phase.rounded(.down)), index + 30) * 2 - 1
            return (age, drift * (0.4 + age * spread), 0.8 + age * (1 + 3 * strength))
        }
        for puff in puffs.sorted(by: { $0.age > $1.age }) {
            let centerY = nozzleY - 1 - puff.age * length
            context.setFillColor(gray: 1 - 0.8 * puff.age, alpha: 1)
            context.fillEllipse(in: CGRect(x: puff.x - puff.radius, y: centerY - puff.radius, width: puff.radius * 2, height: puff.radius * 2))
        }
    }

    static func debris(width: Int, height: Int, isCrashed: Bool) -> [Bool] {
        var cells = Array(repeating: false, count: width * height)
        guard isCrashed else { return cells }
        for x in 0..<width {
            cells[(height - 1) * width + x] = true
        }
        for piece in rubble where (0..<width).contains(width / 2 + piece.x) {
            cells[(height - 1 - piece.y) * width + width / 2 + piece.x] = true
        }
        return cells
    }

    static func noise(_ a: Int, _ b: Int) -> Double {
        var hash = UInt64(bitPattern: Int64(a &* 73_856_093 ^ b &* 19_349_663))
        hash ^= hash >> 33
        hash &*= 0xFF51_AFD7_ED55_8CCD
        hash ^= hash >> 33
        return Double(hash % 10_000) / 10_000
    }

    static func coverage(width: Int, height: Int, angle: Angle, shift: Double, draw: (CGContext) -> Void) -> [Double] {
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
        context.translateBy(x: 0, y: shift)
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

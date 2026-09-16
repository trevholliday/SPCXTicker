//
//  LogoArt.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import CoreGraphics
import ImageIO
import SwiftUI

/// A company logo reduced to LED cells, each an RGB triple in 0...1 or `nil` when off.
struct LogoArt: Equatable, Sendable {

    let width: Int
    let height: Int
    let cells: [SIMD3<Double>?]

    /// Number of lit cells; used to reject logos that reduce to almost nothing.
    var litCount: Int { cells.reduce(0) { $0 + ($1 == nil ? 0 : 1) } }

    /// Bounding box of the lit cells, or `nil` when nothing is lit.
    var litBounds: (width: Int, height: Int)? {
        var minX = width, maxX = -1, minY = height, maxY = -1
        for (index, cell) in cells.enumerated() where cell != nil {
            let x = index % width
            let y = index / width
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
        guard maxX >= 0 else { return nil }
        return (maxX - minX + 1, maxY - minY + 1)
    }

    /// Lights the logo into a grid with its top-left corner at the given cell, scaling brightness by `intensity`.
    func draw(into grid: inout DotGrid, x: Int, y: Int, intensity: Double = 1) {
        for (index, cell) in cells.enumerated() {
            guard let cell else { continue }
            let color = Color(red: cell.x * intensity, green: cell.y * intensity, blue: cell.z * intensity)
            grid.set(x: x + index % width, y: y + index / width, color: color)
        }
    }
}

// MARK: - Rasterizing

extension LogoArt {

    /// Decodes PNG data, crops it to the logo's own bounds, and reduces it to fill the given cell size; `nil` if it doesn't read as a logo.
    static func make(from data: Data, width: Int, height: Int) -> LogoArt? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let analysisScale = min(1, Double(analysisSize) / Double(max(image.width, image.height)))
        let analysisWidth = max(1, Int((Double(image.width) * analysisScale).rounded()))
        let analysisHeight = max(1, Int((Double(image.height) * analysisScale).rounded()))
        guard let analysis = downsample(image, width: analysisWidth, height: analysisHeight),
              let isLit = classifier(for: analysis, width: analysisWidth, height: analysisHeight),
              let box = litBounds(of: analysis, width: analysisWidth, isLit: isLit) else { return nil }

        let cropRect = CGRect(
            x: Double(box.minX) / analysisScale,
            y: Double(box.minY) / analysisScale,
            width: Double(box.maxX - box.minX + 1) / analysisScale,
            height: Double(box.maxY - box.minY + 1) / analysisScale
        ).intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let cropped = image.cropping(to: cropRect) else { return nil }

        let scale = min(Double(width) / Double(cropped.width), Double(height) / Double(cropped.height))
        let fitWidth = max(1, min(width, Int((Double(cropped.width) * scale).rounded())))
        let fitHeight = max(1, min(height, Int((Double(cropped.height) * scale).rounded())))
        guard let samples = downsample(cropped, width: fitWidth, height: fitHeight) else { return nil }

        let offsetX = (width - fitWidth) / 2
        let offsetY = (height - fitHeight) / 2
        var cells = [SIMD3<Double>?](repeating: nil, count: width * height)
        for (index, sample) in samples.enumerated() where isLit(sample) {
            let x = offsetX + index % fitWidth
            let y = offsetY + index / fitWidth
            cells[y * width + x] = boost(sample.color)
        }

        let art = LogoArt(width: width, height: height, cells: cells)
        guard art.litCount >= minimumLitCells, let bounds = art.litBounds,
              bounds.width >= minimumExtent, bounds.height >= minimumExtent else { return nil }
        return art
    }
}

// MARK: - Private

private extension LogoArt {
    struct Sample {
        let color: SIMD3<Double>
        let alpha: Double
    }

    static let analysisSize = 96
    static let alphaThreshold = 0.45
    static let opaqueFillFraction = 0.9
    static let contrastMargin = 0.18
    static let minimumLitCells = 40
    static let minimumExtent = 8

    static func classifier(for samples: [Sample], width: Int, height: Int) -> ((Sample) -> Bool)? {
        let opaque = samples.filter { $0.alpha >= alphaThreshold }
        guard !opaque.isEmpty else { return nil }
        guard Double(opaque.count) >= Double(samples.count) * opaqueFillFraction else {
            return { $0.alpha >= alphaThreshold }
        }
        let border = borderIndices(width: width, height: height).map { luminance(samples[$0].color) }
        let backgroundLuminance = border.reduce(0, +) / Double(border.count)
        if backgroundLuminance < 0.5 {
            return { $0.alpha >= alphaThreshold && luminance($0.color) > backgroundLuminance + contrastMargin }
        }
        return { $0.alpha >= alphaThreshold && (luminance($0.color) < backgroundLuminance - contrastMargin || saturation($0.color) > 0.3) }
    }

    static func litBounds(of samples: [Sample], width: Int, isLit: (Sample) -> Bool) -> (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for (index, sample) in samples.enumerated() where isLit(sample) {
            let x = index % width
            let y = index / width
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
        guard maxX >= 0 else { return nil }
        return (minX, minY, maxX, maxY)
    }

    static func borderIndices(width: Int, height: Int) -> [Int] {
        var indices: [Int] = []
        for x in 0..<width {
            indices.append(x)
            indices.append((height - 1) * width + x)
        }
        for y in 1..<(height - 1) {
            indices.append(y * width)
            indices.append(y * width + width - 1)
        }
        return indices
    }

    static func saturation(_ color: SIMD3<Double>) -> Double {
        let maxComponent = color.max()
        return maxComponent == 0 ? 0 : (maxComponent - color.min()) / maxComponent
    }

    static func downsample(_ image: CGImage, width: Int, height: Int) -> [Sample]? {
        let rect = CGRect(x: 0, y: 0, width: width, height: height)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: rect)

        guard let data = context.data else { return nil }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var samples: [Sample] = []
        samples.reserveCapacity(width * height)
        for index in 0..<(width * height) {
            let offset = index * 4
            let alpha = Double(pixels[offset + 3]) / 255
            guard alpha > 0 else {
                samples.append(Sample(color: .zero, alpha: 0))
                continue
            }
            let color = SIMD3(
                Double(pixels[offset]) / 255 / alpha,
                Double(pixels[offset + 1]) / 255 / alpha,
                Double(pixels[offset + 2]) / 255 / alpha
            )
            samples.append(Sample(color: color.clamped(lowerBound: .zero, upperBound: SIMD3(repeating: 1)), alpha: alpha))
        }
        return samples
    }

    static func luminance(_ color: SIMD3<Double>) -> Double {
        0.2126 * color.x + 0.7152 * color.y + 0.0722 * color.z
    }

    static func boost(_ color: SIMD3<Double>) -> SIMD3<Double> {
        let maxComponent = color.max()
        let minComponent = color.min()
        let saturation = saturation(color)
        guard saturation > 0.2, luminance(color) > 0.12 else {
            return SIMD3(repeating: 0.9)
        }
        let boostedSaturation = min(1, saturation * 1.35)
        let scaled = (color - SIMD3(repeating: minComponent)) / max(maxComponent - minComponent, 0.0001)
        return SIMD3(repeating: 1 - boostedSaturation) + scaled * boostedSaturation
    }
}

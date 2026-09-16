//
//  TickerView.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import SwiftUI

/// LED-matrix ticker: symbol, percent change, and price on the left, a rocket on the right.
struct TickerView: View {

    let quote: Quote?

    private let symbol = "SPCX"
    private let pitch: CGFloat = 7
    private let gridWidth = 72
    private let gridHeight = 32

    private var grid: DotGrid {
        var grid = DotGrid(width: gridWidth, height: gridHeight)
        grid.drawText("$" + symbol, x: 2, y: 2, color: Palette.symbol)

        if let quote {
            let trend = quote.isUp ? Palette.up : Palette.down
            grid.drawText(quote.percentText, x: 2, y: 12, color: trend)
            grid.drawText(quote.priceText, x: 2, y: 22, color: trend)
            drawRocket(in: &grid, angle: quote.isUp ? .degrees(45) : .degrees(180), color: trend)
        } else {
            grid.drawText("LOADING", x: 2, y: 12, color: Palette.idle)
            drawRocket(in: &grid, angle: .zero, color: Palette.idle)
        }
        return grid
    }

    var body: some View {
        let grid = grid
        Canvas { context, size in
            let dotSize = pitch * 0.72
            let inset = (pitch - dotSize) / 2
            for y in 0..<grid.height {
                for x in 0..<grid.width {
                    let rect = CGRect(x: CGFloat(x) * pitch + inset, y: CGFloat(y) * pitch + inset, width: dotSize, height: dotSize)
                    let color = grid.color(x: x, y: y) ?? Palette.off
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .frame(width: CGFloat(gridWidth) * pitch, height: CGFloat(gridHeight) * pitch)
        .padding(pitch)
        .background(Color.black)
    }
}

// MARK: - Palette

private extension TickerView {
    enum Palette {
        static let symbol = Color(red: 0.55, green: 0.55, blue: 1.0)
        static let up = Color(red: 0.2, green: 1.0, blue: 0.35)
        static let down = Color(red: 1.0, green: 0.2, blue: 0.2)
        static let flame = Color(red: 1.0, green: 0.6, blue: 0.1)
        static let idle = Color(white: 0.6)
        static let off = Color(white: 0.09)
    }
}

// MARK: - Private

private extension TickerView {
    func drawRocket(in grid: inout DotGrid, angle: Angle, color: Color) {
        let width = 24
        let height = 28
        let masks = RocketRasterizer.masks(width: width, height: height, angle: angle)
        let x = gridWidth - width - 2
        let y = (gridHeight - height) / 2
        grid.drawMask(masks.body, width: width, x: x, y: y, color: color)
        grid.drawMask(masks.flame, width: width, x: x, y: y, color: Palette.flame)
    }
}

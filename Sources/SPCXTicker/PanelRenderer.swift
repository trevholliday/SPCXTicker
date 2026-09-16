//
//  PanelRenderer.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import SwiftUI

/// Draws one ticker (symbol, change, price, rocket) into a fixed 72x32 `DotGrid`.
enum PanelRenderer {

    static let width = 72
    static let baseHeight = 32
    static let valueRowHeight = 10

    /// Panel height, taller when a market-value row is shown.
    static func height(showsValueRow: Bool) -> Int {
        baseHeight + (showsValueRow ? valueRowHeight : 0)
    }

    /// Renders a panel for a symbol in the given state; `shares` fills the value row when the panel has one.
    static func render(symbol: String, state: PanelState, shares: Double = 0, showsValueRow: Bool = false) -> DotGrid {
        let height = height(showsValueRow: showsValueRow)
        var grid = DotGrid(width: width, height: height)
        grid.drawText(fit("$" + symbol), x: textX, y: 2, color: Palette.symbol)

        switch state {
        case .quote(let quote):
            let trend = quote.isUp ? Palette.up : Palette.down
            grid.drawText(fit(quote.percentText, fallback: quote.compactPercentText), x: textX, y: 12, color: trend)
            grid.drawText(fit(quote.priceText, fallback: quote.compactPriceText), x: textX, y: 22, color: trend)
            if showsValueRow, shares > 0 {
                grid.drawText(fit(candidates: quote.valueTexts(shares: shares)), x: textX, y: 32, color: Palette.value)
            }
            drawRocket(in: &grid, angle: quote.isUp ? .degrees(45) : .degrees(180), color: trend)
            if let pollTrend = quote.pollTrend {
                drawPollArrow(in: &grid, trend: pollTrend)
            }
        case .loading:
            grid.drawText("LOADING", x: textX, y: 12, color: Palette.idle)
            drawRocket(in: &grid, angle: .zero, color: Palette.idle)
        case .failed:
            grid.drawText("NO DATA", x: textX, y: 12, color: Palette.idle)
            drawRocket(in: &grid, angle: .zero, color: Palette.idle)
        }
        return grid
    }
}

// MARK: - PanelState

extension PanelRenderer {
    enum PanelState: Equatable {
        case loading
        case failed
        case quote(Quote)
    }
}

// MARK: - Palette

enum Palette {
    static let symbol = Color(red: 0.55, green: 0.55, blue: 1.0)
    static let up = Color(red: 0.2, green: 1.0, blue: 0.35)
    static let down = Color(red: 1.0, green: 0.2, blue: 0.2)
    static let flame = Color(red: 1.0, green: 0.6, blue: 0.1)
    static let idle = Color(white: 0.6)
    static let value = Color(red: 0.35, green: 0.85, blue: 1.0)
    static let off = Color(white: 0.09)
}

// MARK: - Private

private extension PanelRenderer {
    static let textX = 2
    static let rocketWidth = 24
    static let rocketHeight = 28
    static let textColumns = width - rocketWidth - 2 - textX - 1

    static func fit(_ text: String, fallback: String? = nil) -> String {
        fit(candidates: [text, fallback].compactMap { $0 })
    }

    static func fit(candidates: [String]) -> String {
        if let text = candidates.first(where: { DotFont.width(of: $0) <= textColumns }) { return text }
        let maxCharacters = (textColumns + 1) / DotFont.advance
        return String((candidates.last ?? "").prefix(maxCharacters))
    }

    static let upArrow: [UInt8] = [0b00100, 0b01110, 0b11111, 0b00100, 0b00100]

    static func drawPollArrow(in grid: inout DotGrid, trend: Quote.PollTrend) {
        let rows = trend == .up ? upArrow : upArrow.reversed()
        let color = trend == .up ? Palette.up : Palette.down
        let x = width - 5 - 1
        let y = grid.height - rows.count - 1
        for (row, mask) in rows.enumerated() {
            for column in 0..<5 where mask & (0b10000 >> column) != 0 {
                grid.set(x: x + column, y: y + row, color: color)
            }
        }
    }

    static func drawRocket(in grid: inout DotGrid, angle: Angle, color: Color) {
        let masks = RocketRasterizer.masks(width: rocketWidth, height: rocketHeight, angle: angle)
        let x = width - rocketWidth - 2
        let y = (grid.height - rocketHeight) / 2
        grid.drawMask(masks.body, width: rocketWidth, x: x, y: y, color: color)
        grid.drawMask(masks.flame, width: rocketWidth, x: x, y: y, color: Palette.flame)
    }
}

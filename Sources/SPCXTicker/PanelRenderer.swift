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
    static let height = 32

    /// Renders a panel for a symbol in the given state.
    static func render(symbol: String, state: PanelState) -> DotGrid {
        var grid = DotGrid(width: width, height: height)
        grid.drawText(fit("$" + symbol), x: textX, y: 2, color: Palette.symbol)

        switch state {
        case .quote(let quote):
            let trend = quote.isUp ? Palette.up : Palette.down
            grid.drawText(fit(quote.percentText, fallback: quote.compactPercentText), x: textX, y: 12, color: trend)
            grid.drawText(fit(quote.priceText, fallback: quote.compactPriceText), x: textX, y: 22, color: trend)
            drawRocket(in: &grid, angle: quote.isUp ? .degrees(45) : .degrees(180), color: trend)
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
    static let off = Color(white: 0.09)
}

// MARK: - Private

private extension PanelRenderer {
    static let textX = 2
    static let rocketWidth = 24
    static let rocketHeight = 28
    static let textColumns = width - rocketWidth - 2 - textX - 1

    static func fit(_ text: String, fallback: String? = nil) -> String {
        if DotFont.width(of: text) <= textColumns { return text }
        if let fallback, DotFont.width(of: fallback) <= textColumns { return fallback }
        let maxCharacters = (textColumns + 1) / DotFont.advance
        return String((fallback ?? text).prefix(maxCharacters))
    }

    static func drawRocket(in grid: inout DotGrid, angle: Angle, color: Color) {
        let masks = RocketRasterizer.masks(width: rocketWidth, height: rocketHeight, angle: angle)
        let x = width - rocketWidth - 2
        let y = (height - rocketHeight) / 2
        grid.drawMask(masks.body, width: rocketWidth, x: x, y: y, color: color)
        grid.drawMask(masks.flame, width: rocketWidth, x: x, y: y, color: Palette.flame)
    }
}

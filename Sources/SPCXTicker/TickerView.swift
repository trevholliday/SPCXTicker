//
//  TickerView.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import SwiftUI

/// LED-matrix viewport over a looping strip of ticker panels, shifted left by `offset` columns.
struct TickerView: View {

    let symbols: [String]
    let states: [String: PanelRenderer.PanelState]
    let shares: [String: Double]
    let offset: Int

    static let pitch: CGFloat = 7

    private var strip: DotGrid {
        guard symbols.count > 1 else {
            return panel(for: symbols.first ?? TickerSettings.defaultSymbols[0])
        }
        var strip = DotGrid(width: symbols.count * ScrollController.panelStride, height: PanelRenderer.height)
        for (index, symbol) in symbols.enumerated() {
            strip.draw(panel(for: symbol), x: index * ScrollController.panelStride, y: 0)
        }
        return strip
    }

    var body: some View {
        let strip = strip
        let pitch = Self.pitch
        Canvas { context, _ in
            let dotSize = pitch * 0.72
            let inset = (pitch - dotSize) / 2
            for y in 0..<PanelRenderer.height {
                for x in 0..<PanelRenderer.width {
                    let column = (x + offset) % strip.width
                    let rect = CGRect(x: CGFloat(x) * pitch + inset, y: CGFloat(y) * pitch + inset, width: dotSize, height: dotSize)
                    let color = strip.color(x: column, y: y) ?? Palette.off
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .frame(width: CGFloat(PanelRenderer.width) * pitch, height: CGFloat(PanelRenderer.height) * pitch)
        .padding(pitch)
        .background(Color.black)
    }
}

// MARK: - Private

private extension TickerView {
    func panel(for symbol: String) -> DotGrid {
        PanelRenderer.render(symbol: symbol, state: states[symbol] ?? .loading, shares: shares[symbol] ?? 0)
    }
}

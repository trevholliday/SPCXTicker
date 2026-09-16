//
//  DotGrid.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import SwiftUI

/// A fixed-size matrix of LED cells; `nil` cells are off.
struct DotGrid: Equatable {

    let width: Int
    let height: Int
    private(set) var cells: [Color?]

    // MARK: - Init

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        cells = Array(repeating: nil, count: width * height)
    }

    /// Color of the cell at the given position, or `nil` when off or out of bounds.
    func color(x: Int, y: Int) -> Color? {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }
        return cells[y * width + x]
    }

    /// Lights a single cell, ignoring positions outside the grid.
    mutating func set(x: Int, y: Int, color: Color) {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return }
        cells[y * width + x] = color
    }

    /// Draws a string in `DotFont` with its top-left corner at the given cell.
    mutating func drawText(_ text: String, x: Int, y: Int, color: Color) {
        var cursor = x
        for character in text {
            let rows = DotFont.glyph(for: character)
            for (row, mask) in rows.enumerated() {
                for column in 0..<DotFont.glyphWidth where mask & (0b10000 >> column) != 0 {
                    set(x: cursor + column, y: y + row, color: color)
                }
            }
            cursor += DotFont.advance
        }
    }

    /// Copies every lit cell of another grid with its top-left corner at the given cell.
    mutating func draw(_ other: DotGrid, x: Int, y: Int) {
        for (index, color) in other.cells.enumerated() {
            guard let color else { continue }
            set(x: x + index % other.width, y: y + index / other.width, color: color)
        }
    }

    /// Copies lit cells from a boolean mask with its top-left corner at the given cell.
    mutating func drawMask(_ mask: [Bool], width maskWidth: Int, x: Int, y: Int, color: Color) {
        for (index, lit) in mask.enumerated() where lit {
            set(x: x + index % maskWidth, y: y + index / maskWidth, color: color)
        }
    }
}

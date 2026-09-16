//
//  ScrollController.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import Foundation
import Observation

/// Advances a column offset through a looping strip: dwell on a panel, then scroll left one step at a time.
@Observable
@MainActor
final class ScrollController {

    static let panelStride = PanelRenderer.width + 8
    static let step = 5

    private(set) var offset = 0

    private let dwell: Duration
    private let stepInterval: Duration

    // MARK: - Init

    init(dwell: Duration = .seconds(15), stepInterval: Duration = .milliseconds(80)) {
        self.dwell = dwell
        self.stepInterval = stepInterval
    }

    /// Loops forever for the given panel count; a single panel never scrolls.
    func run(panelCount: Int) async {
        offset = 0
        guard panelCount > 1 else { return }
        let stripWidth = panelCount * Self.panelStride
        let stepsPerPanel = Self.panelStride / Self.step
        while !Task.isCancelled {
            try? await Task.sleep(for: dwell)
            for _ in 0..<stepsPerPanel {
                guard !Task.isCancelled else { return }
                offset = (offset + Self.step) % stripWidth
                try? await Task.sleep(for: stepInterval)
            }
        }
    }
}

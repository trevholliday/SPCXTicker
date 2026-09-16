//
//  Quote.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import Foundation

/// A single price snapshot with its change against the previous close.
struct Quote: Equatable {

    let symbol: String
    let price: Double
    let previousClose: Double

    var change: Double { price - previousClose }

    var changePercent: Double {
        guard previousClose != 0 else { return 0 }
        return change / previousClose * 100
    }

    var isUp: Bool { change >= 0 }

    var priceText: String {
        "$" + String(format: "%.2f", price)
    }

    var percentText: String {
        (isUp ? "+" : "-") + String(format: "%.2f", abs(changePercent)) + "%"
    }
}

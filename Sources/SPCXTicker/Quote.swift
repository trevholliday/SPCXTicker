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
    var lastPollPrice: Double?

    var change: Double { price - previousClose }

    var pollTrend: PollTrend? {
        guard let lastPollPrice, lastPollPrice != price else { return nil }
        return price > lastPollPrice ? .up : .down
    }

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

    var compactPriceText: String {
        "$" + String(format: "%.0f", price)
    }

    var compactPercentText: String {
        (isUp ? "+" : "-") + String(format: "%.1f", abs(changePercent)) + "%"
    }

    /// Returns this quote carrying the poll-to-poll direction inherited from the previous quote.
    func succeeding(_ previous: Quote?) -> Quote {
        var quote = self
        guard let previous else { return quote }
        quote.lastPollPrice = previous.price == price ? previous.lastPollPrice : previous.price
        return quote
    }
}

// MARK: - PollTrend

extension Quote {
    enum PollTrend {
        case up
        case down
    }
}

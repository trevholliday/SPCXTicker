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
    var sessionStart: Date?
    var sessionEnd: Date?
    var lastPollPrice: Double?

    var change: Double { price - previousClose }

    /// True while the exchange's regular trading session is in progress.
    func isMarketOpen(at date: Date = Date()) -> Bool {
        guard let sessionStart, let sessionEnd else { return true }
        return date >= sessionStart && date < sessionEnd
    }

    /// The next regular session start after `date`, assuming the same time each day.
    func nextSessionStart(after date: Date = Date()) -> Date? {
        guard var next = sessionStart else { return nil }
        while next <= date {
            next = next.addingTimeInterval(24 * 60 * 60)
        }
        return next
    }

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

    /// Market value of a share count, from most to least precise so the renderer can pick what fits.
    func valueTexts(shares: Double) -> [String] {
        let value = price * shares
        let grouped = NumberFormatter()
        grouped.numberStyle = .decimal
        grouped.minimumFractionDigits = 2
        grouped.maximumFractionDigits = 2
        let whole = NumberFormatter()
        whole.numberStyle = .decimal
        whole.maximumFractionDigits = 0
        var texts = [
            "$" + (grouped.string(from: value as NSNumber) ?? String(format: "%.2f", value)),
            "$" + (whole.string(from: value as NSNumber) ?? String(format: "%.0f", value)),
        ]
        if value >= 1_000_000 {
            texts.append("$" + String(format: "%.2fM", value / 1_000_000))
            texts.append("$" + String(format: "%.1fM", value / 1_000_000))
        } else if value >= 1_000 {
            texts.append("$" + String(format: "%.1fK", value / 1_000))
        }
        return texts
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

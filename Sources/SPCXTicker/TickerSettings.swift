//
//  TickerSettings.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import Foundation

/// Persists the user's ticker list as comma-separated text in `UserDefaults`.
enum TickerSettings {

    static let key = "tickerSymbols"
    static let sharesKey = "tickerShares"
    static let defaultSymbols = ["SPCX"]

    /// Symbols currently saved, falling back to the default list.
    static func load() -> [String] {
        parse(UserDefaults.standard.string(forKey: key) ?? "")
    }

    /// Decodes a symbol-to-share-count map from its JSON text form.
    static func decodeShares(_ json: String) -> [String: Double] {
        guard let data = json.data(using: .utf8),
              let shares = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
        return shares
    }

    /// Encodes a symbol-to-share-count map as JSON text, dropping empty or zero entries.
    static func encodeShares(_ shares: [String: Double]) -> String {
        let cleaned = shares.filter { $0.value > 0 }
        guard let data = try? JSONEncoder().encode(cleaned) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    /// Splits free-form text into uppercase, de-duplicated symbols; empty input yields the default list.
    static func parse(_ text: String) -> [String] {
        var seen = Set<String>()
        let symbols = text
            .components(separatedBy: CharacterSet(charactersIn: ", \n\t"))
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased().replacingOccurrences(of: "$", with: "") }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        return symbols.isEmpty ? defaultSymbols : symbols
    }
}

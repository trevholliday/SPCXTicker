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
    static let defaultSymbols = ["SPCX"]

    /// Symbols currently saved, falling back to the default list.
    static func load() -> [String] {
        parse(UserDefaults.standard.string(forKey: key) ?? "")
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

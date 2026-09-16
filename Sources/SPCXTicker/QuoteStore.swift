//
//  QuoteStore.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import Foundation
import Observation

/// Polls Yahoo Finance for every configured symbol and publishes the results to the UI.
@Observable
@MainActor
final class QuoteStore {

    private(set) var symbols: [String]
    private(set) var quotes: [String: Quote] = [:]
    private(set) var failures: Set<String> = []

    private let refreshInterval: Duration
    private let session: URLSession

    // MARK: - Init

    init(symbols: [String], refreshInterval: Duration = .seconds(15)) {
        self.symbols = symbols
        self.refreshInterval = refreshInterval
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 SPCXTicker"]
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    /// Fetches immediately, then keeps refreshing until the task is cancelled.
    func start() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: refreshInterval)
        }
    }

    /// Replaces the symbol list, drops stale results, and fetches the new symbols right away.
    func setSymbols(_ newSymbols: [String]) {
        guard newSymbols != symbols else { return }
        symbols = newSymbols
        quotes = quotes.filter { newSymbols.contains($0.key) }
        failures = failures.intersection(newSymbols)
        Task { await refresh() }
    }

    /// Fetches every symbol concurrently and merges the results.
    func refresh() async {
        let requested = symbols
        let session = session
        await withTaskGroup(of: (String, Quote?).self) { group in
            for symbol in requested {
                group.addTask { (symbol, try? await Self.fetch(symbol: symbol, session: session)) }
            }
            for await (symbol, quote) in group where symbols.contains(symbol) {
                if let quote {
                    quotes[symbol] = quote
                    failures.remove(symbol)
                } else if quotes[symbol] == nil {
                    failures.insert(symbol)
                }
            }
        }
    }
}

// MARK: - ChartResponse

private extension QuoteStore {
    struct ChartResponse: Decodable {
        struct Chart: Decodable {
            struct Result: Decodable {
                struct Meta: Decodable {
                    let symbol: String
                    let regularMarketPrice: Double
                    let chartPreviousClose: Double?
                    let previousClose: Double?
                }

                let meta: Meta
            }

            let result: [Result]?
        }

        let chart: Chart
    }

    enum FetchError: Error {
        case badURL
        case badStatus(Int)
        case emptyResult
    }
}

// MARK: - Private

private extension QuoteStore {
    nonisolated static func fetch(symbol: String, session: URLSession) async throws -> Quote {
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)")
        components?.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "range", value: "1d"),
            URLQueryItem(name: "_", value: String(Int(Date().timeIntervalSince1970 * 1000))),
        ]
        guard let url = components?.url else { throw FetchError.badURL }

        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FetchError.badStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChartResponse.self, from: data)
        guard let meta = decoded.chart.result?.first?.meta else { throw FetchError.emptyResult }
        let previous = meta.chartPreviousClose ?? meta.previousClose ?? meta.regularMarketPrice
        return Quote(symbol: symbol, price: meta.regularMarketPrice, previousClose: previous)
    }
}

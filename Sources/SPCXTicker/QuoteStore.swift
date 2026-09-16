//
//  QuoteStore.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import Foundation
import Observation

/// Polls Yahoo Finance for the latest quote and publishes it to the UI.
@Observable
@MainActor
final class QuoteStore {

    private(set) var quote: Quote?
    private(set) var lastError: Error?

    private let symbol: String
    private let refreshInterval: Duration
    private let session: URLSession

    // MARK: - Init

    init(symbol: String, refreshInterval: Duration = .seconds(60)) {
        self.symbol = symbol
        self.refreshInterval = refreshInterval
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 SPCXTicker"]
        session = URLSession(configuration: configuration)
    }

    /// Fetches immediately, then keeps refreshing until the task is cancelled.
    func start() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: refreshInterval)
        }
    }

    /// Fetches a single quote and updates `quote` or `lastError`.
    func refresh() async {
        do {
            quote = try await fetch()
            lastError = nil
        } catch {
            lastError = error
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
    func fetch() async throws -> Quote {
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)")
        components?.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "range", value: "1d"),
        ]
        guard let url = components?.url else { throw FetchError.badURL }

        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FetchError.badStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChartResponse.self, from: data)
        guard let meta = decoded.chart.result?.first?.meta else { throw FetchError.emptyResult }
        let previous = meta.chartPreviousClose ?? meta.previousClose ?? meta.regularMarketPrice
        return Quote(symbol: meta.symbol, price: meta.regularMarketPrice, previousClose: previous)
    }
}

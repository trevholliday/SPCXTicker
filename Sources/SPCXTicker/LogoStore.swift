//
//  LogoStore.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import Foundation
import Observation

/// Downloads company logos by ticker, caches the PNGs on disk, and publishes their LED renderings.
@Observable
@MainActor
final class LogoStore {

    private(set) var logos: [String: LogoArt] = [:]

    private let width: Int
    private let height: Int
    private let session: URLSession
    private let cacheDirectory: URL
    private var attempted: Set<String> = []

    // MARK: - Init

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 SPCXTicker"]
        session = URLSession(configuration: configuration)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        cacheDirectory = support.appendingPathComponent("SPCXTicker/Logos", isDirectory: true)
    }

    /// Ensures every symbol has been looked up once; symbols with no usable logo are left out of `logos`.
    func load(symbols: [String]) {
        for symbol in symbols where !attempted.contains(symbol) {
            attempted.insert(symbol)
            Task { await fetch(symbol: symbol) }
        }
    }
}

// MARK: - Private

private extension LogoStore {
    func fetch(symbol: String) async {
        let file = cacheDirectory.appendingPathComponent("\(symbol).png")
        var data = try? Data(contentsOf: file)
        if data == nil, let downloaded = await download(symbol: symbol) {
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            try? downloaded.write(to: file)
            data = downloaded
        }
        guard let data else { return }
        let width = width
        let height = height
        let art = await Task.detached(priority: .utility) { LogoArt.make(from: data, width: width, height: height) }.value
        if let art {
            logos[symbol] = art
        }
    }

    func download(symbol: String) async -> Data? {
        guard let url = URL(string: "https://financialmodelingprep.com/image-stock/\(symbol).png") else { return nil }
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("image/") == true else { return nil }
        return data
    }
}

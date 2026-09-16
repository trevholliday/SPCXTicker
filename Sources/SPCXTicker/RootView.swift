//
//  RootView.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import SwiftUI

/// Hosts the ticker display, drives polling and scrolling, and exposes the editor via context menu.
struct RootView: View {

    let store: QuoteStore

    @AppStorage(TickerSettings.key) private var symbolsText = TickerSettings.defaultSymbols.joined(separator: ", ")
    @AppStorage(TickerSettings.sharesKey) private var sharesJSON = "{}"
    @State private var scroll = ScrollController()
    @State private var isEditing = false

    private var symbols: [String] { TickerSettings.parse(symbolsText) }

    private var states: [String: PanelRenderer.PanelState] {
        var states: [String: PanelRenderer.PanelState] = [:]
        for symbol in store.symbols {
            if let quote = store.quotes[symbol] {
                states[symbol] = .quote(quote)
            } else if store.failures.contains(symbol) {
                states[symbol] = .failed
            }
        }
        return states
    }

    var body: some View {
        TickerView(symbols: store.symbols, states: states, shares: TickerSettings.decodeShares(sharesJSON), offset: scroll.offset)
            .contextMenu {
                Button("Edit Tickers…") { isEditing = true }
                Button("Refresh Now") { Task { await store.refresh() } }
                Divider()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .sheet(isPresented: $isEditing) {
                TickerEditorView(symbolsText: $symbolsText, sharesJSON: $sharesJSON)
            }
            .task { await store.start() }
            .task(id: store.symbols.count) { await scroll.run(panelCount: store.symbols.count) }
            .onChange(of: symbols, initial: true) { _, newSymbols in
                store.setSymbols(newSymbols)
            }
    }
}

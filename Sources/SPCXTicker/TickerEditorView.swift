//
//  TickerEditorView.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import SwiftUI

/// Sheet for editing the ticker list and the number of shares held per ticker.
struct TickerEditorView: View {

    @Binding var symbolsText: String
    @Binding var sharesJSON: String

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var sharesDraft: [String: String] = [:]
    @FocusState private var isFocused: Bool

    private var parsedSymbols: [String] { TickerSettings.parse(draft) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tickers")
                .font(.headline)
            Text("Separate symbols with commas. One ticker stays fixed; two or more scroll.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("SPCX, TSLA, AAPL", text: $draft)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit(save)

            Text("Shares held")
                .font(.headline)
                .padding(.top, 4)
            Text("Optional. Adds a market value row under the price.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Grid(alignment: .leading, verticalSpacing: 6) {
                ForEach(parsedSymbols, id: \.self) { symbol in
                    GridRow {
                        Text("$" + symbol)
                            .font(.system(.body, design: .monospaced))
                        TextField("0", text: sharesBinding(for: symbol))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .onSubmit(save)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            draft = symbolsText
            sharesDraft = TickerSettings.decodeShares(sharesJSON).mapValues { Self.format($0) }
            isFocused = true
        }
    }
}

// MARK: - Private

private extension TickerEditorView {
    static func format(_ shares: Double) -> String {
        shares == shares.rounded() ? String(Int(shares)) : String(shares)
    }

    func sharesBinding(for symbol: String) -> Binding<String> {
        Binding(
            get: { sharesDraft[symbol] ?? "" },
            set: { sharesDraft[symbol] = $0 }
        )
    }

    func save() {
        let symbols = parsedSymbols
        symbolsText = symbols.joined(separator: ", ")
        var shares: [String: Double] = [:]
        for symbol in symbols {
            let text = (sharesDraft[symbol] ?? "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
            if let count = Double(text), count > 0 {
                shares[symbol] = count
            }
        }
        sharesJSON = TickerSettings.encodeShares(shares)
        dismiss()
    }
}

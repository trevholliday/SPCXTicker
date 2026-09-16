//
//  TickerEditorView.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import SwiftUI

/// Sheet for editing the comma-separated ticker list.
struct TickerEditorView: View {

    @Binding var symbolsText: String

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
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
            Text(parsedSymbols.map { "$" + $0 }.joined(separator: "  "))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            draft = symbolsText
            isFocused = true
        }
    }
}

// MARK: - Private

private extension TickerEditorView {
    func save() {
        symbolsText = parsedSymbols.joined(separator: ", ")
        dismiss()
    }
}

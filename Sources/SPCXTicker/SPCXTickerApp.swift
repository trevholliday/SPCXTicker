//
//  SPCXTickerApp.swift
//  SPCXTicker
//
//  Created by Trevor Holliday on 09/16/2026.
//

import AppKit
import SwiftUI

@main
struct SPCXTickerApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = QuoteStore(symbols: TickerSettings.load())

    var body: some Scene {
        WindowGroup("SPCX") {
            RootView(store: store)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}

// MARK: - AppDelegate

/// Turns the bare executable into a floating, always-on-top widget.
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            configure(window)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private extension AppDelegate {
    func configure(_ window: NSWindow) {
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .black
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.makeKeyAndOrderFront(nil)
    }
}

// OpenCDPExampleApp.swift
// OpenCDP iOS SDK — Example App Entry Point

import SwiftUI
import OpenCDP

@main
struct OpenCDPExampleApp: App {

    init() {
        // ─── Initialize the SDK ──────────────────────────────────────────────
        // Call this once at app launch before any other SDK methods.
        let config = OpenCDPConfig(
            cdpApiKey: ProcessInfo.processInfo.environment["CDP_API_KEY"] ?? "your-api-key",
            debug: true,
            autoTrackScreens: true,
            trackApplicationLifecycleEvents: true,
            autoTrackDeviceAttributes: true
        )
        OpenCDP.shared.initialize(config: config)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

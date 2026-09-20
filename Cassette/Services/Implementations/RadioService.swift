// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.
// See LICENSE file in the project root for full license information.

import Foundation
import SwiftSonic
import OSLog

actor RadioService: RadioServiceProtocol {
    private let serverService: any ServerServiceProtocol
    private var cachedClient: SwiftSonicClient?
    private var cachedServerId: UUID?
    private var stationsCache: [InternetRadioStation]?

    init(serverService: any ServerServiceProtocol) {
        self.serverService = serverService
    }

    // MARK: - Client

    private func client() async throws -> SwiftSonicClient {
        let activeId = await MainActor.run { serverService.state.activeServer?.id }
        if let cached = cachedClient, cachedServerId == activeId, activeId != nil {
            return cached
        }
        let fresh = try await serverService.makeSwiftSonicClient()
        cachedClient = fresh
        cachedServerId = activeId
        return fresh
    }

    // MARK: - Read

    func listStations(forceRefresh: Bool = false) async throws -> [InternetRadioStation] {
        if !forceRefresh, let cached = stationsCache { return cached }
        let stations = try await client().getInternetRadioStations()
        stationsCache = stations
        Logger.radio.debug("Fetched \(stations.count) radio station(s).")
        return stations
    }

    func cachedStations() async -> [InternetRadioStation]? {
        stationsCache
    }

    func installNookStarterStations() async throws -> [InternetRadioStation] {
        let client = try await client()
        let existing = try await client.getInternetRadioStations()
        let existingNames = Set(existing.map { $0.name.lowercased() })

        let presets: [(name: String, stream: String, home: String)] = [
            ("Nook Study", "https://ice5.somafm.com/groovesalad-128-mp3", "https://somafm.com/groovesalad/"),
            ("Nook Café", "https://ice5.somafm.com/sonicuniverse-128-mp3", "https://somafm.com/sonicuniverse/"),
            ("Nook Rain", "https://ice5.somafm.com/dronezone-128-mp3", "https://somafm.com/dronezone/"),
            ("Nook Late Night", "https://ice5.somafm.com/beatblender-128-mp3", "https://somafm.com/beatblender/")
        ]

        for preset in presets where !existingNames.contains(preset.name.lowercased()) {
            guard let streamURL = URL(string: preset.stream) else { continue }
            let homepageURL = URL(string: preset.home)
            try await client.createInternetRadioStation(
                streamURL: streamURL,
                name: preset.name,
                homepageURL: homepageURL
            )
        }

        let refreshed = try await client.getInternetRadioStations()
        stationsCache = refreshed
        Logger.radio.info("Nook starter stations installed/refreshed: \(refreshed.count) total radio station(s).")
        return refreshed
    }

    func clearCache() async {
        stationsCache = nil
        Logger.radio.debug("Radio station cache cleared.")
    }
}

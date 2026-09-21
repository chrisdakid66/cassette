// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import Foundation

enum ChrasssetteHomeBannerStore {
    static let didChangeNotification = Notification.Name("chrasssette.homeBanner.didChange")

    private static var baseDirectory: URL? {
        let manager = FileManager.default
        guard let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = support
            .appendingPathComponent("Chrasssette", isDirectory: true)
            .appendingPathComponent("HomeBanners", isDirectory: true)

        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func fileURL(for profileID: String) -> URL? {
        guard let baseDirectory else { return nil }
        let safeID = profileID
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return baseDirectory.appendingPathComponent("home-banner-\(safeID).image")
    }

    static func save(_ data: Data, profileID: String) throws {
        guard let url = fileURL(for: profileID) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
        NotificationCenter.default.post(name: didChangeNotification, object: profileID)
    }

    static func loadData(profileID: String) -> Data? {
        guard let url = fileURL(for: profileID) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func remove(profileID: String) throws {
        guard let url = fileURL(for: profileID) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        NotificationCenter.default.post(name: didChangeNotification, object: profileID)
    }
}

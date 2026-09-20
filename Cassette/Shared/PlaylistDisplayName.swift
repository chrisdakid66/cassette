// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import Foundation

extension String {
    /// Keeps server-side generated-playlist identifiers intact while presenting
    /// clean, brand-free names in Chrasssette.
    var chrasssetteDisplayName: String {
        let prefixes = [
            "Cassette · ",
            "Cassette • ",
            "Cassette - ",
            "Cassette – ",
            "Chrasssette · ",
            "Chrasssette • ",
            "Chrasssette - ",
            "Chrasssette – "
        ]

        for prefix in prefixes where hasPrefix(prefix) {
            return String(dropFirst(prefix.count))
        }
        return self
    }
}

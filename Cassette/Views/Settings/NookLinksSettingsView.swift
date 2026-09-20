// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import SwiftUI

struct NookLinksSettingsView: View {
    @AppStorage("chrasssette.nook.jellyfinURL") private var jellyfinURL = ""
    @AppStorage("chrasssette.nook.cashAppURL") private var cashAppURL = ""

    var body: some View {
        Form {
            Section("Jellyfin") {
                TextField("https://your-jellyfin.example", text: $jellyfinURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                Text("Used for the Music Videos shortcut. Full in-app Jellyfin browsing can build on this connection next.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Tip Jar") {
                TextField("https://cash.app/$cashtag", text: $cashAppURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                Text("Optional. Leave blank to hide the fireplace tip button.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Nook Links")
        .navigationBarTitleDisplayMode(.inline)
    }
}

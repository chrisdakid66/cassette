// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import SwiftUI

struct NookLinksSettingsView: View {
    @AppStorage("chrasssette.nook.jellyfinURL") private var jellyfinURL = ""
    @AppStorage("chrasssette.nook.cashAppURL") private var cashAppURL = ""
    @AppStorage("chrasssette.nook.decor.one") private var decorOne = "sparkles"
    @AppStorage("chrasssette.nook.decor.two") private var decorTwo = "music.note"
    @AppStorage("chrasssette.nook.decor.three") private var decorThree = "gamecontroller.fill"

    private let decorChoices = [
        "sparkles",
        "music.note",
        "gamecontroller.fill",
        "books.vertical.fill",
        "moon.stars.fill",
        "headphones",
        "mic.fill",
        "cup.and.saucer.fill",
        "cat.fill",
        "record.circle"
    ]

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

            Section("Room Decor") {
                decorPicker("Left frame", selection: $decorOne)
                decorPicker("Center frame", selection: $decorTwo)
                decorPicker("Lower frame", selection: $decorThree)

                Text("These symbols appear as framed wall decor in the Podcast corner.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Nook Links")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func decorPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(decorChoices, id: \.self) { symbol in
                Label(symbol.replacingOccurrences(of: ".fill", with: ""), systemImage: symbol)
                    .tag(symbol)
            }
        }
        .pickerStyle(.menu)
    }
}

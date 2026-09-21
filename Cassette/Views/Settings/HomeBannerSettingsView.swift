// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

struct HomeBannerSettingsView: View {
    @AppStorage("chrasssette.profile.activeID") private var activeProfileID = "default"

    @State private var showImporter = false
    @State private var bannerData: Data?
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section {
                bannerPreview

                Button {
                    showImporter = true
                } label: {
                    Label("Choose Banner File", systemImage: "photo.on.rectangle.angled")
                }

                if bannerData != nil {
                    Button(role: .destructive) {
                        removeBanner()
                    } label: {
                        Label("Use Default Banner", systemImage: "arrow.uturn.backward")
                    }
                }
            } header: {
                Text("Home Banner")
            } footer: {
                Text("Applies to the current Chrasssette profile. Wide images work best; Discord/Steam-style banners around 16:9 are a great fit. Animated GIF playback can come later.")
            }

            Section("Profile Scope") {
                LabeledContent("Profile", value: activeProfileID)
                Text("Banner storage is already keyed by profile so future profile switching can keep separate cover art for each user.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Home Banner")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            importBanner(result)
        }
        .onAppear(perform: reload)
        .onChange(of: activeProfileID) { _, _ in reload() }
    }

    @ViewBuilder
    private var bannerPreview: some View {
        #if canImport(UIKit)
        if let bannerData, let image = UIImage(data: bannerData) {
            ZStack(alignment: .bottomLeading) {
                Color.black

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.62)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                Text("Home preview")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .padding(12)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(540.0 / 302.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            defaultPreview
        }
        #else
        defaultPreview
        #endif
    }

    private var defaultPreview: some View {
        ZStack(alignment: .bottomLeading) {
            Image("ChrasssetteHeader")
                .resizable()
                .scaledToFill()

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.60)],
                startPoint: .center,
                endPoint: .bottom
            )

            Text("Default Chrasssette banner")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .padding(12)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(540.0 / 302.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func reload() {
        bannerData = ChrasssetteHomeBannerStore.loadData(profileID: activeProfileID)
    }

    private func importBanner(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url)
            #if canImport(UIKit)
            guard UIImage(data: data) != nil else {
                statusMessage = "That file could not be decoded as an image."
                return
            }
            #endif

            try ChrasssetteHomeBannerStore.save(data, profileID: activeProfileID)
            bannerData = data
            statusMessage = "Banner updated for this profile."
        } catch {
            statusMessage = "Couldn’t import that banner: \(error.localizedDescription)"
        }
    }

    private func removeBanner() {
        do {
            try ChrasssetteHomeBannerStore.remove(profileID: activeProfileID)
            bannerData = nil
            statusMessage = "Default Chrasssette banner restored."
        } catch {
            statusMessage = "Couldn’t remove the custom banner: \(error.localizedDescription)"
        }
    }
}

// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import SwiftUI
import SwiftSonic
import OSLog

private enum NookRoomScene: Int, CaseIterable, Identifiable {
    case books
    case fireplace
    case podcasts

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .books: return "Books"
        case .fireplace: return "Fireside"
        case .podcasts: return "Podcasts"
        }
    }

    var symbol: String {
        switch self {
        case .books: return "books.vertical.fill"
        case .fireplace: return "flame.fill"
        case .podcasts: return "mic.fill"
        }
    }
}

struct NookView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.openURL) private var openURL

    @AppStorage("chrasssette.nook.jellyfinURL") private var jellyfinURL = ""
    @AppStorage("chrasssette.nook.cashAppURL") private var cashAppURL = "https://cash.app/$PadreIgnant"

    @State private var audiobookAlbums: [AlbumID3] = []
    @State private var podcastAlbums: [AlbumID3] = []
    @State private var podcastChannels: [PodcastChannel] = []
    @State private var newestEpisodes: [PodcastEpisode] = []
    @State private var radioStations: [InternetRadioStation] = []

    @State private var isLoadingAlbums = false
    @State private var isLoadingPodcasts = false
    @State private var isLoadingRadio = false
    @State private var isInstallingStarterStations = false

    @StateObject private var weather = NookWeatherModel()
    @State private var showNookLinks = false
    @State private var showExpandedRoom = false
    @State private var afterDark = false
    @State private var selectedRadioName = "Nook Study"

    private var selectedRadioStation: InternetRadioStation? {
        radioStations.first { $0.name.caseInsensitiveCompare(selectedRadioName) == .orderedSame }
        ?? radioStations.first { $0.name.localizedCaseInsensitiveContains("study") }
        ?? radioStations.first { $0.name.localizedCaseInsensitiveContains("lofi") }
        ?? radioStations.first { $0.name.localizedCaseInsensitiveContains("lo-fi") }
        ?? radioStations.first
    }

    private var selectedRadioIsPlaying: Bool {
        guard let selectedRadioStation,
              container?.playerState.currentRadio?.id == selectedRadioStation.id
        else { return false }
        return container?.playerState.playbackState == .playing
    }

    private var hasNookStarterStations: Bool {
        radioStations.contains { $0.name.hasPrefix("Nook ") }
    }

    var body: some View {
        ZStack {
            AnimatedAmbientBackground(warm: true)

            if afterDark {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.42),
                        CassetteColors.chrisflixDeepPurple.opacity(0.20),
                        Color.black.opacity(0.62)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: CassetteSpacing.xl) {
                    nookHeader
                    minimizedNook

                    if isLoadingAlbums || isLoadingPodcasts || isLoadingRadio {
                        HStack {
                            Spacer()
                            LongCatLoader(label: "Warming the Nook…")
                            Spacer()
                        }
                        .padding(.vertical, 18)
                    }

                    musicVideosSection
                }
                .padding(.horizontal, CassetteSpacing.l)
                .padding(.top, CassetteSpacing.m)
                .padding(.bottom, CassetteSpacing.xl)
            }
            .allowsHitTesting(!showExpandedRoom)
            .scaleEffect(showExpandedRoom ? 1.035 : 1)
            .blur(radius: showExpandedRoom ? 5 : 0)

            if showExpandedRoom {
                NookImmersiveRoomView(
                    audiobookAlbums: audiobookAlbums,
                    podcastAlbums: podcastAlbums,
                    podcastChannels: podcastChannels,
                    newestEpisodes: newestEpisodes,
                    radioStations: radioStations,
                    selectedRadioName: $selectedRadioName,
                    afterDark: $afterDark,
                    weather: weather,
                    isInstallingStarterStations: isInstallingStarterStations,
                    hasStarterStations: hasNookStarterStations,
                    onClose: {
                        withAnimation(.spring(response: 0.44, dampingFraction: 0.90)) {
                            showExpandedRoom = false
                        }
                    },
                    onPlayRadio: playRadio,
                    onInstallStarterStations: installStarterRadioStations,
                    onTipJarTap: openTipJar,
                    onToggleAfterDark: toggleAfterDark
                )
                .transition(
                    .scale(scale: 0.76, anchor: .center)
                    .combined(with: .opacity)
                )
                .zIndex(20)
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.88), value: showExpandedRoom)
        .toolbar(showExpandedRoom ? .hidden : .automatic, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .miniPlayerBottomMargin()
        .task(id: container?.serverState.libraryLoadKey) {
            async let albums: Void = loadAlbums()
            async let podcasts: Void = loadPodcasts()
            async let radios: Void = loadRadioStations()
            _ = await (albums, podcasts, radios)
        }
        .task {
            weather.refreshIfStale()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 600_000_000_000)
                guard !Task.isCancelled else { break }
                weather.refreshIfStale()
            }
        }
        .sheet(isPresented: $showNookLinks) {
            NavigationStack {
                NookLinksSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showNookLinks = false }
                        }
                    }
            }
        }

    }

    private var nookHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                afterDark ? CassetteColors.chrisflixPurple : Color.orange,
                                afterDark ? Color(red: 0.50, green: 0.28, blue: 1.0) : Color(red: 1.0, green: 0.48, blue: 0.16)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: (afterDark ? CassetteColors.chrisflixPurple : Color.orange).opacity(0.55), radius: 8)

                Text(afterDark ? "Nook After Dark" : "Nook")
                    .font(.system(size: afterDark ? 36 : 42, weight: .black, design: .rounded))
                    .chrasssetteNeonTitle(
                        accent: afterDark ? CassetteColors.chrisflixPurple : Color.orange,
                        glow: afterDark ? 0.92 : 0.34
                    )
            }

            Text(afterDark ? "The fire went violet. You found it." : "Lo-fi radio, long listens, and cozy corners")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.66))
        }
        .padding(.top, CassetteSpacing.s)
        .animation(.easeInOut(duration: 0.28), value: afterDark)
    }

    private var minimizedNook: some View {
        ZStack(alignment: .bottom) {
            NookFireplaceScene(
                afterDark: afterDark,
                isRadioPlaying: selectedRadioIsPlaying,
                hasRadioStation: selectedRadioStation != nil,
                onRadioTap: handleMinimizedRadioTap,
                onTipJarTap: openTipJar,
                onSecretToggle: toggleAfterDark
            )
            .frame(maxWidth: .infinity)
            .frame(height: 300)

            weatherCard
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .padding(12)
                .frame(maxHeight: .infinity, alignment: .top)

            Button {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
                    showExpandedRoom = true
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.bold())
                    Text("Enter the Nook")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.48), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(
                            (afterDark ? CassetteColors.chrisflixPurple : Color.orange).opacity(0.34),
                            lineWidth: 0.8
                        )
                }
                .shadow(color: .black.opacity(0.30), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
    }

    private var weatherCard: some View {
        Button {
            weather.refresh(force: true)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: weather.snapshot?.symbol ?? "location.fill")
                        .foregroundStyle(afterDark ? CassetteColors.chrisflixPurple : .orange)
                    if let snap = weather.snapshot {
                        Text("\(snap.temperature)\(snap.unit)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                }

                Text(weather.snapshot?.condition ?? weather.statusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.black.opacity(0.44), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder((afterDark ? CassetteColors.chrisflixPurple : Color.orange).opacity(0.24), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
    }

    private var musicVideosSection: some View {
        VStack(alignment: .leading, spacing: CassetteSpacing.s) {
            HStack {
                Text("Music Videos")
                    .font(.cassetteSectionTitle)
                    .chrasssetteNeonTitle(
                        accent: afterDark ? CassetteColors.chrisflixPurple : Color.orange,
                        glow: afterDark ? 0.72 : 0.18
                    )
                Spacer()
                Image(systemName: "play.rectangle.fill")
                    .foregroundStyle(.white.opacity(0.45))
            }

            Button {
                if let url = normalizedURL(jellyfinURL) {
                    openURL(url)
                } else {
                    showNookLinks = true
                }
            } label: {
                HStack(spacing: CassetteSpacing.m) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        CassetteColors.chrisflixDeepPurple.opacity(0.82),
                                        Color.black.opacity(0.66)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 82, height: 58)

                        Image(systemName: jellyfinURL.isEmpty ? "play.rectangle.on.rectangle" : "play.rectangle.fill")
                            .font(.title2)
                            .foregroundStyle(CassetteColors.chrisflixPurple)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(jellyfinURL.isEmpty ? "Connect Jellyfin" : "Open Music Videos")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(jellyfinURL.isEmpty
                             ? "Point Nook at your Jellyfin server to start the video side of Chrasssette."
                             : "Open your Jellyfin server. Native video shelves are the next step.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.56))
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: jellyfinURL.isEmpty ? "gearshape.fill" : "arrow.up.right")
                        .foregroundStyle(.white.opacity(0.62))
                }
                .padding(CassetteSpacing.m)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(CassetteColors.chrisflixPurple.opacity(0.16), lineWidth: 0.8)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func handleMinimizedRadioTap() {
        guard let station = selectedRadioStation else {
            showExpandedRoom = true
            return
        }
        playRadio(station)
    }

    private func playRadio(_ station: InternetRadioStation) {
        guard let container else { return }

        selectedRadioName = station.name
        Task {
            do {
                if container.playerState.currentRadio?.id == station.id {
                    if container.playerState.playbackState == .playing {
                        await container.playerService.pause()
                    } else {
                        await container.playerService.resume()
                    }
                } else {
                    try await container.playerService.playRadio(station)
                }
            } catch {
                container.toastService.showError("Unable to play this Nook station.")
                Logger.player.error("[NOOK-RADIO] play failed: \(error, privacy: .public)")
            }
        }
    }

    private func installStarterRadioStations() {
        guard let service = container?.radioService, !isInstallingStarterStations else { return }
        isInstallingStarterStations = true

        Task {
            do {
                let installed = try await service.installNookStarterStations()
                await MainActor.run {
                    radioStations = installed
                    isInstallingStarterStations = false
                    selectedRadioName = "Nook Study"
                    container?.toastService.show("Nook radio stations added.", style: .success)
                }
            } catch {
                await MainActor.run {
                    isInstallingStarterStations = false
                    container?.toastService.showError("Couldn’t add the starter stations. The active server account may need admin access.")
                }
                Logger.radio.error("[NOOK-RADIO] starter install failed: \(error, privacy: .public)")
            }
        }
    }

    private func openTipJar() {
        if let url = normalizedURL(cashAppURL) {
            openURL(url)
        } else {
            showNookLinks = true
        }
    }

    private func toggleAfterDark() {
        HapticFeedback.medium.trigger()
        withAnimation(.easeInOut(duration: 0.34)) {
            afterDark.toggle()
        }
    }

    private func normalizedURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = URL(string: trimmed), direct.scheme != nil {
            return direct
        }
        return URL(string: "https://" + trimmed)
    }

    @MainActor
    private func loadAlbums() async {
        guard let library = container?.libraryService else { return }
        isLoadingAlbums = true
        defer { isLoadingAlbums = false }

        let albums = (try? await library.allAlbums()) ?? []
        audiobookAlbums = albums.filter { album in
            let genre = (album.genre ?? "").lowercased()
            return genre.contains("audiobook") ||
                genre.contains("audio book") ||
                genre.contains("spoken word")
        }
        podcastAlbums = albums.filter { ($0.genre ?? "").lowercased().contains("podcast") }
    }

    @MainActor
    private func loadPodcasts() async {
        guard let library = container?.libraryService else { return }
        isLoadingPodcasts = true
        defer { isLoadingPodcasts = false }

        async let channels = try? library.podcasts()
        async let newest = try? library.newestPodcasts(count: 12)
        podcastChannels = await channels ?? []
        newestEpisodes = await newest ?? []
    }

    @MainActor
    private func loadRadioStations() async {
        guard let service = container?.radioService else { return }
        isLoadingRadio = true
        defer { isLoadingRadio = false }
        radioStations = (try? await service.listStations(forceRefresh: false)) ?? []
    }
}

private struct NookExpandedRoomView: View {
    @Environment(\.dismiss) private var dismiss

    let audiobookAlbums: [AlbumID3]
    let podcastAlbums: [AlbumID3]
    let podcastChannels: [PodcastChannel]
    let newestEpisodes: [PodcastEpisode]
    let radioStations: [InternetRadioStation]

    @Binding var selectedRadioName: String
    @Binding var afterDark: Bool
    @ObservedObject var weather: NookWeatherModel

    let cashAppURL: String
    let isInstallingStarterStations: Bool
    let hasStarterStations: Bool

    let onClose: () -> Void
    let onPlayRadio: (InternetRadioStation) -> Void
    let onInstallStarterStations: () -> Void
    let onTipJarTap: () -> Void
    let onToggleAfterDark: () -> Void

    @State private var selectedScene: NookRoomScene = .fireplace

    private var nookStations: [InternetRadioStation] {
        let preferredOrder = ["Nook Study", "Nook Café", "Nook Rain", "Nook Late Night"]
        let matches = radioStations.filter { $0.name.hasPrefix("Nook ") }
        return matches.sorted {
            (preferredOrder.firstIndex(of: $0.name) ?? 999) < (preferredOrder.firstIndex(of: $1.name) ?? 999)
        }
    }

    private var selectedStation: InternetRadioStation? {
        radioStations.first { $0.name.caseInsensitiveCompare(selectedRadioName) == .orderedSame }
    }

    private var isSelectedPlaying: Bool {
        // Visual state is intentionally conservative in expanded mode; the mini player remains
        // the source of truth for exact playback state.
        selectedStation != nil
    }

    var body: some View {
        ZStack {
            AnimatedAmbientBackground(warm: true)

            if afterDark {
                Color.black.opacity(0.34).ignoresSafeArea()
            }

            VStack(spacing: 0) {
                expandedTopBar

                TabView(selection: $selectedScene) {
                    audiobookRoom
                        .tag(NookRoomScene.books)
                    fireplaceRoom
                        .tag(NookRoomScene.fireplace)
                    podcastRoom
                        .tag(NookRoomScene.podcasts)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                scenePicker
                    .padding(.bottom, 18)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var expandedTopBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(afterDark ? "Nook After Dark" : "The Nook")
                    .font(.title2.bold())
                Text(selectedScene.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onClose()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.bold())
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.42), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, CassetteSpacing.l)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var scenePicker: some View {
        HStack(spacing: 8) {
            ForEach(NookRoomScene.allCases) { scene in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedScene = scene
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: scene.symbol)
                        if selectedScene == scene {
                            Text(scene.title)
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .foregroundStyle(selectedScene == scene ? .white : .white.opacity(0.58))
                    .padding(.horizontal, selectedScene == scene ? 13 : 11)
                    .padding(.vertical, 9)
                    .background(
                        selectedScene == scene
                            ? (afterDark ? CassetteColors.chrisflixPurple.opacity(0.34) : Color.orange.opacity(0.24))
                            : Color.white.opacity(0.05),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.black.opacity(0.34), in: Capsule())
    }

    private var fireplaceRoom: some View {
        GeometryReader { geo in
            VStack(spacing: 16) {
                ZStack(alignment: .topTrailing) {
                    NookFireplaceScene(
                        afterDark: afterDark,
                        isRadioPlaying: isSelectedPlaying,
                        hasRadioStation: selectedStation != nil,
                        onRadioTap: {
                            if let station = selectedStation {
                                onPlayRadio(station)
                            }
                        },
                        onTipJarTap: onTipJarTap,
                        onSecretToggle: onToggleAfterDark
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: min(geo.size.height * 0.70, 590))

                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: weather.snapshot?.symbol ?? "location.fill")
                            if let snap = weather.snapshot {
                                Text("\(snap.temperature)\(snap.unit)")
                            } else {
                                Text(weather.statusText)
                            }
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.46), in: Capsule())

                        if !hasStarterStations {
                            Button(action: onInstallStarterStations) {
                                HStack(spacing: 6) {
                                    if isInstallingStarterStations {
                                        ProgressView().controlSize(.mini).tint(.white)
                                    } else {
                                        Image(systemName: "radio.fill")
                                    }
                                    Text("Add starter stations")
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(CassetteColors.chrisflixPurple.opacity(0.52), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(isInstallingStarterStations)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                }

                if !nookStations.isEmpty {
                    radioPresetPicker
                } else {
                    Text("Add the four starter stations to unlock Study, Café, Rain, and Late Night.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.56))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, CassetteSpacing.l)
        }
    }

    private var radioPresetPicker: some View {
        HStack(spacing: 8) {
            ForEach(nookStations, id: \.id) { station in
                Button {
                    selectedRadioName = station.name
                    onPlayRadio(station)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: radioSymbol(for: station.name))
                            .font(.body)
                        Text(displayRadioName(station.name))
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(selectedRadioName == station.name ? .white : .white.opacity(0.62))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        selectedRadioName == station.name
                            ? (afterDark ? CassetteColors.chrisflixPurple.opacity(0.34) : Color.orange.opacity(0.24))
                            : Color.white.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var audiobookRoom: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.07, blue: 0.09),
                        Color(red: 0.055, green: 0.035, blue: 0.06),
                        .black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 18) {
                    HStack(alignment: .bottom) {
                        Image(systemName: "lamp.desk.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange.opacity(0.84))
                            .shadow(color: .orange.opacity(0.42), radius: 18)
                        Spacer()
                        Text("Audiobook Corner")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    bookshelfScene
                        .frame(height: min(geo.size.height * 0.66, 500))

                    Text(audiobookAlbums.isEmpty
                         ? "Tag an album Audiobook, Audio Book, or Spoken Word and it will land on these shelves."
                         : "Tap a cover on the shelf to open your audiobook.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.54))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(CassetteSpacing.l)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, CassetteSpacing.l)
            .padding(.vertical, 10)
        }
    }

    private var bookshelfScene: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { shelf in
                HStack(alignment: .bottom, spacing: 8) {
                    let start = shelf * 4
                    ForEach(0..<4, id: \.self) { slot in
                        let index = start + slot
                        if audiobookAlbums.indices.contains(index) {
                            let album = audiobookAlbums[index]
                            NavigationLink {
                                AlbumDetailView(album: album)
                            } label: {
                                CoverArtView(id: album.coverArt ?? album.id, size: 220)
                                    .frame(width: 62, height: 92)
                                    .cassetteCoverStyle(cornerRadius: 6)
                            }
                            .buttonStyle(.plain)
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .fill([
                                    Color(red: 0.50, green: 0.20, blue: 0.15),
                                    Color.orange.opacity(0.58),
                                    CassetteColors.chrisflixPurple.opacity(0.52),
                                    Color(red: 0.19, green: 0.33, blue: 0.30)
                                ][slot])
                                .frame(width: 32 + CGFloat(slot % 2) * 5, height: 70 + CGFloat((slot + shelf) % 3) * 13)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .background(Color.black.opacity(0.16))

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.26, green: 0.14, blue: 0.10))
                    .frame(height: 13)
            }
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [Color(red: 0.20, green: 0.105, blue: 0.075), Color(red: 0.10, green: 0.06, blue: 0.055)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.14), lineWidth: 1)
        }
    }

    private var podcastRoom: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.055, blue: 0.10),
                        Color(red: 0.045, green: 0.03, blue: 0.055),
                        .black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 18) {
                    HStack {
                        Text("Podcast Table")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "waveform")
                            .foregroundStyle(CassetteColors.chrisflixPurple)
                    }

                    Spacer()

                    ZStack(alignment: .top) {
                        Ellipse()
                            .fill(Color.black.opacity(0.28))
                            .frame(width: 290, height: 90)
                            .offset(y: 86)

                        RoundedRectangle(cornerRadius: 42, style: .continuous)
                            .fill(Color(red: 0.24, green: 0.14, blue: 0.10))
                            .frame(width: 310, height: 145)
                            .shadow(color: .black.opacity(0.40), radius: 18, y: 12)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 66, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .shadow(color: CassetteColors.chrisflixPurple.opacity(0.50), radius: 18)
                            .offset(x: -72, y: -38)

                        ZStack {
                            Circle()
                                .fill(Color(red: 0.82, green: 0.78, blue: 0.69))
                                .frame(width: 68, height: 68)
                            Circle()
                                .strokeBorder(Color.black.opacity(0.25), lineWidth: 4)
                                .frame(width: 52, height: 52)
                            Image(systemName: "cup.and.saucer.fill")
                                .foregroundStyle(Color(red: 0.28, green: 0.16, blue: 0.12))
                        }
                        .offset(x: 82, y: 36)
                    }
                    .frame(height: min(geo.size.height * 0.40, 300))

                    podcastShelf

                    Spacer()
                }
                .padding(CassetteSpacing.l)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, CassetteSpacing.l)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var podcastShelf: some View {
        if !newestEpisodes.isEmpty {
            VStack(spacing: 8) {
                ForEach(Array(newestEpisodes.prefix(3)), id: \.id) { episode in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(episode.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(channelTitle(for: episode.channelId))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.52))
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(CassetteColors.chrisflixPurple)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        } else if !podcastChannels.isEmpty {
            HStack {
                Image(systemName: "mic.circle.fill")
                    .font(.title2)
                    .foregroundStyle(CassetteColors.chrisflixPurple)
                Text("\(podcastChannels.count) podcast channel\(podcastChannels.count == 1 ? "" : "s") ready in the Nook")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                Spacer()
            }
            .padding(12)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            Text("Add a server podcast feed or tag an album Podcast and it will show up on the coffee table.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.54))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private func channelTitle(for channelId: String) -> String {
        podcastChannels.first(where: { $0.id == channelId })?.title ?? "Podcast"
    }

    private func displayRadioName(_ name: String) -> String {
        name.replacingOccurrences(of: "Nook ", with: "")
    }

    private func radioSymbol(for name: String) -> String {
        let lowered = name.lowercased()
        if lowered.contains("café") || lowered.contains("cafe") { return "cup.and.saucer.fill" }
        if lowered.contains("rain") { return "cloud.rain.fill" }
        if lowered.contains("late") { return "moon.stars.fill" }
        return "books.vertical.fill"
    }
}

private struct NookFireplaceScene: View {
    let afterDark: Bool
    let isRadioPlaying: Bool
    let hasRadioStation: Bool
    let onRadioTap: () -> Void
    let onTipJarTap: () -> Void
    let onSecretToggle: () -> Void

    @State private var flicker = false
    @State private var swipeCount = 0
    @State private var lastSwipe = Date.distantPast

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: afterDark
                            ? [
                                Color(red: 0.045, green: 0.025, blue: 0.085),
                                Color(red: 0.075, green: 0.025, blue: 0.11),
                                .black
                            ]
                            : [
                                Color(red: 0.12, green: 0.06, blue: 0.12),
                                Color(red: 0.065, green: 0.038, blue: 0.07),
                                .black
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            rainyWindow
                .offset(x: -92, y: -65)


            fireplace
                .offset(y: 29)

            // Both props sit directly on the mantel now.
            tipJar
                .offset(x: -58, y: -24)

            radio
                .offset(x: 58, y: -24)

            if afterDark {
                sleepingCat
                    .offset(x: -83, y: 93)
                    .transition(.scale.combined(with: .opacity))
            }

            Circle()
                .fill((afterDark ? CassetteColors.chrisflixPurple : Color.orange).opacity(flicker ? 0.16 : 0.09))
                .frame(width: 220, height: 220)
                .blur(radius: 34)
                .offset(y: 70)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder((afterDark ? CassetteColors.chrisflixPurple : Color.orange).opacity(0.16), lineWidth: 0.8)
        }
        .shadow(color: (afterDark ? CassetteColors.chrisflixPurple : Color.orange).opacity(0.11), radius: 24, y: 9)
        .onLongPressGesture(minimumDuration: 1.35) {
            onSecretToggle()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 45)
                .onEnded { value in
                    guard abs(value.translation.width) > 65 else { return }
                    let now = Date()
                    if now.timeIntervalSince(lastSwipe) > 2.2 {
                        swipeCount = 0
                    }
                    swipeCount += 1
                    lastSwipe = now
                    if swipeCount >= 3 {
                        swipeCount = 0
                        onSecretToggle()
                    }
                }
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) {
                flicker = true
            }
        }
        .animation(.easeInOut(duration: 0.30), value: afterDark)
    }

    private var rainyWindow: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        CassetteColors.chrisflixDeepPurple.opacity(afterDark ? 0.66 : 0.44),
                        Color.black.opacity(0.88)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 112, height: 82)
            .overlay {
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 2, height: 24)
                            .rotationEffect(.degrees(18))
                    }
                }
            }
    }

    private var bookshelf: some View {
        VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                [Color.orange, CassetteColors.chrisflixPurple, Color(red: 0.45, green: 0.20, blue: 0.20)][(row + index) % 3]
                                    .opacity(0.42)
                            )
                            .frame(width: 5, height: CGFloat(13 + ((row + index) % 3) * 4))
                    }
                }
            }
        }
        .frame(width: 64, height: 66)
        .background(Color.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 8))
    }

    private var fireplace: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(red: 0.20, green: 0.13, blue: 0.15))
                .frame(width: 72, height: 53)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.28, green: 0.17, blue: 0.15))
                .frame(width: 172, height: 15)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.17, green: 0.10, blue: 0.11))
                    .frame(width: 158, height: 117)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.94))
                    .frame(width: 108, height: 84)
                    .overlay(alignment: .bottom) {
                        HStack(spacing: -9) {
                            flame(scale: flicker ? 0.86 : 1.0, color: fireColorOne)
                            flame(scale: flicker ? 1.14 : 0.93, color: fireColorTwo)
                            flame(scale: flicker ? 0.96 : 1.09, color: fireColorThree)
                        }
                        .padding(.bottom, 8)
                        .shadow(
                            color: (afterDark ? CassetteColors.chrisflixPurple : Color.orange)
                                .opacity(flicker ? 0.80 : 0.48),
                            radius: flicker ? 18 : 11
                        )
                    }
            }
        }
    }

    private var radio: some View {
        Button(action: onRadioTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 0.29, green: 0.18, blue: 0.13))
                    .frame(width: 70, height: 42)
                    .shadow(color: .black.opacity(0.28), radius: 3, y: 2)

                Capsule()
                    .fill(Color.black.opacity(0.25))
                    .frame(width: 58, height: 4)
                    .offset(y: 20)

                Circle()
                    .strokeBorder((afterDark ? CassetteColors.chrisflixPurple : Color.orange).opacity(0.78), lineWidth: 2)
                    .frame(width: 21, height: 21)
                    .offset(x: -15)

                VStack(spacing: 4) {
                    Image(systemName: isRadioPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 8, weight: .bold))
                    HStack(spacing: 3) {
                        Circle().frame(width: 3, height: 3)
                        Circle().opacity(0.52).frame(width: 3, height: 3)
                    }
                }
                .foregroundStyle(afterDark ? CassetteColors.chrisflixPurple : .orange)
                .offset(x: 18)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRadioPlaying ? "Pause Nook Radio" : "Play Nook Radio")
    }

    private var tipJar: some View {
        Button(action: onTipJarTap) {
            ZStack {
                // glass body
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.085))
                    .frame(width: 50, height: 46)
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    }

                // glass shine
                Capsule()
                    .fill(Color.white.opacity(0.24))
                    .frame(width: 4, height: 29)
                    .offset(x: -15, y: -1)

                // coins / heart
                VStack(spacing: -2) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(afterDark ? CassetteColors.chrisflixPurple : .orange)
                    HStack(spacing: 2) {
                        Circle().fill(Color.yellow.opacity(0.68)).frame(width: 6, height: 6)
                        Circle().fill(Color.orange.opacity(0.68)).frame(width: 6, height: 6)
                    }
                }
                .offset(y: 5)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.24, green: 0.16, blue: 0.12))
                    .frame(width: 40, height: 7)
                    .offset(y: -25)
            }
            .shadow(color: (afterDark ? CassetteColors.chrisflixPurple : Color.orange).opacity(0.15), radius: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tip Jar")
    }

    private var sleepingCat: some View {
        ZStack {
            // curled body
            Ellipse()
                .fill(Color(red: 0.34, green: 0.35, blue: 0.41))
                .frame(width: 74, height: 42)

            Path { path in
                path.move(to: CGPoint(x: 5, y: 28))
                path.addCurve(
                    to: CGPoint(x: 45, y: 10),
                    control1: CGPoint(x: 8, y: 8),
                    control2: CGPoint(x: 35, y: 4)
                )
            }
            .stroke(
                Color(red: 0.45, green: 0.46, blue: 0.54),
                style: StrokeStyle(lineWidth: 7, lineCap: .round)
            )
            .frame(width: 52, height: 34)
            .offset(x: -14, y: 3)

            // head
            ZStack {
                Circle()
                    .fill(Color(red: 0.43, green: 0.44, blue: 0.51))
                    .frame(width: 30, height: 30)

                HStack(spacing: 9) {
                    Capsule().fill(Color.black.opacity(0.70)).frame(width: 5, height: 1.5)
                    Capsule().fill(Color.black.opacity(0.70)).frame(width: 5, height: 1.5)
                }
                .offset(y: 2)

                Image(systemName: "triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.43, green: 0.44, blue: 0.51))
                    .rotationEffect(.degrees(-14))
                    .offset(x: -8, y: -16)

                Image(systemName: "triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.43, green: 0.44, blue: 0.51))
                    .rotationEffect(.degrees(14))
                    .offset(x: 8, y: -16)
            }
            .offset(x: 25, y: -7)

            Image(systemName: "zzz")
                .font(.caption.bold())
                .foregroundStyle(CassetteColors.chrisflixPurple.opacity(0.82))
                .offset(x: 49, y: -30)
        }
        .accessibilityHidden(true)
    }

    private var fireColorOne: Color {
        afterDark ? Color(red: 0.35, green: 0.12, blue: 0.92) : Color(red: 1.0, green: 0.34, blue: 0.08)
    }

    private var fireColorTwo: Color {
        afterDark ? CassetteColors.chrisflixPurple : .orange
    }

    private var fireColorThree: Color {
        afterDark ? Color(red: 0.72, green: 0.36, blue: 1.0) : Color(red: 1.0, green: 0.68, blue: 0.18)
    }

    private func flame(scale: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [afterDark ? Color.white.opacity(0.88) : Color.yellow.opacity(0.94), color],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 24, height: 55)
            .scaleEffect(scale, anchor: .bottom)
            .rotationEffect(.degrees(scale > 1 ? 5 : -5))
    }
}

private struct NookPodcastChannelView: View {
    @Environment(\.appContainer) private var container
    let channel: PodcastChannel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CassetteSpacing.l) {
                HStack(alignment: .top, spacing: CassetteSpacing.l) {
                    if let cover = channel.coverArt {
                        CoverArtView(id: cover, size: 360)
                            .frame(width: 132, height: 132)
                            .cassetteCoverStyle(cornerRadius: 18)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(CassetteColors.chrisflixDeepPurple.opacity(0.6))
                            Image(systemName: "mic.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .frame(width: 132, height: 132)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(channel.title)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("\(channel.episode.count) episode\(channel.episode.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    Spacer()
                }

                if let description = channel.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                VStack(spacing: 0) {
                    ForEach(channel.episode, id: \.id) { episode in
                        Button {
                            play(episode)
                        } label: {
                            HStack(spacing: CassetteSpacing.m) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(episode.title)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)

                                    HStack(spacing: 6) {
                                        if let date = episode.publishDate {
                                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                        }
                                        if let duration = episode.duration, duration > 0 {
                                            Text("•")
                                            Text(formatDuration(duration))
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                                }

                                Spacer()

                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(CassetteColors.chrisflixPurple)
                            }
                            .padding(.vertical, CassetteSpacing.m)
                        }
                        .buttonStyle(.plain)

                        if episode.id != channel.episode.last?.id {
                            Divider().overlay(.white.opacity(0.08))
                        }
                    }
                }
            }
            .padding(CassetteSpacing.l)
            .padding(.bottom, CassetteSpacing.xl)
        }
        .background(
            LinearGradient(
                colors: [CassetteColors.chrisflixPurpleBlack, .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(channel.title)
        .navigationBarTitleDisplayMode(.inline)
        .miniPlayerBottomMargin()
    }

    private func formatDuration(_ seconds: Int) -> String {
        let safe = max(seconds, 0)
        let hours = safe / 3600
        let minutes = (safe % 3600) / 60
        let secs = safe % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private func play(_ episode: PodcastEpisode) {
        guard let container else { return }
        let song = DisplayableSong(
            id: episode.streamId ?? episode.id,
            title: episode.title,
            artist: channel.title,
            albumId: nil,
            albumName: channel.title,
            artistId: nil,
            genre: "Podcast",
            duration: TimeInterval(episode.duration ?? 0),
            trackNumber: nil,
            isDownloaded: false,
            coverArtId: episode.coverArt ?? channel.coverArt,
            audioFormat: episode.suffix?.uppercased(),
            replayGainTrackGain: nil,
            replayGainTrackPeak: nil,
            replayGainAlbumGain: nil,
            replayGainAlbumPeak: nil,
            replayGainBaseGain: nil,
            replayGainFallbackGain: nil
        )

        Task {
            do {
                try await container.playerService.play(tracks: [song], startIndex: 0)
            } catch {
                Logger.player.error("Podcast playback failed: \(error, privacy: .public)")
            }
        }
    }
}

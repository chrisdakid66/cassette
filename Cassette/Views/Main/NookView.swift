// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import SwiftUI
import SwiftSonic
import OSLog

struct NookView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.openURL) private var openURL

    @AppStorage("chrasssette.nook.jellyfinURL") private var jellyfinURL = ""
    @AppStorage("chrasssette.nook.cashAppURL") private var cashAppURL = ""

    @State private var audiobookAlbums: [AlbumID3] = []
    @State private var podcastAlbums: [AlbumID3] = []
    @State private var podcastChannels: [PodcastChannel] = []
    @State private var newestEpisodes: [PodcastEpisode] = []
    @State private var radioStations: [InternetRadioStation] = []

    @State private var isLoadingAlbums = false
    @State private var isLoadingPodcasts = false
    @State private var isLoadingRadio = false
    @State private var loadError: String?

    @StateObject private var weather = NookWeatherModel()
    @State private var showRadioPicker = false
    @State private var showNookLinks = false
    @State private var afterDark = false

    private let cardWidth: CGFloat = 150

    private var isInitialLoading: Bool {
        (isLoadingAlbums || isLoadingPodcasts) &&
        audiobookAlbums.isEmpty &&
        podcastAlbums.isEmpty &&
        podcastChannels.isEmpty &&
        newestEpisodes.isEmpty
    }

    private var preferredLofiStation: InternetRadioStation? {
        let needles = ["lofi", "lo-fi", "study", "chill"]
        return radioStations.first { station in
            let name = station.name.lowercased()
            return needles.contains { name.contains($0) }
        }
    }

    private var isPreferredRadioPlaying: Bool {
        guard let preferredLofiStation,
              container?.playerState.currentRadio?.id == preferredLofiStation.id
        else { return false }
        return container?.playerState.playbackState == .playing
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
                    cozyHero

                    if isInitialLoading {
                        HStack {
                            Spacer()
                            LongCatLoader(label: "Warming the Nook…")
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    } else {
                        if !newestEpisodes.isEmpty {
                            latestEpisodesSection
                        }

                        audiobookSection
                        podcastSection
                        musicVideosSection
                    }

                    if let loadError {
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.48))
                            .padding(.bottom, CassetteSpacing.l)
                    }
                }
                .padding(.horizontal, CassetteSpacing.l)
                .padding(.top, CassetteSpacing.m)
                .padding(.bottom, CassetteSpacing.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .miniPlayerBottomMargin()
        .task(id: container?.serverState.libraryLoadKey) {
            async let albums: Void = loadAlbums()
            async let podcasts: Void = loadPodcasts()
            async let radios: Void = loadRadioStations()
            _ = await (albums, podcasts, radios)
            updateEmptyMessage()
        }
        .task {
            weather.refresh()
        }
        .sheet(isPresented: $showRadioPicker) {
            NavigationStack {
                RadioListView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showRadioPicker = false }
                        }
                    }
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
                    .foregroundStyle(.white)
            }

            Text(afterDark ? "The fire went violet. You found it." : "Lo-fi radio, long listens, and cozy corners")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.66))
        }
        .padding(.top, CassetteSpacing.s)
        .animation(.easeInOut(duration: 0.28), value: afterDark)
    }

    private var cozyHero: some View {
        ZStack(alignment: .top) {
            NookFireplaceScene(
                afterDark: afterDark,
                isRadioPlaying: isPreferredRadioPlaying,
                hasLofiStation: preferredLofiStation != nil,
                onRadioTap: handleRadioTap,
                onSecretToggle: toggleAfterDark
            )
            .frame(maxWidth: .infinity)
            .frame(height: 286)

            HStack(alignment: .top, spacing: CassetteSpacing.s) {
                fireplaceTipButton
                Spacer()
                weatherCard
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
    }

    private var fireplaceTipButton: some View {
        Button {
            if let url = normalizedURL(cashAppURL) {
                openURL(url)
            } else {
                showNookLinks = true
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.caption)
                Text(cashAppURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Tip Jar" : "Tip the server")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.black.opacity(0.42), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.orange.opacity(0.30), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
    }

    private var weatherCard: some View {
        Button {
            weather.refresh()
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

    private var latestEpisodesSection: some View {
        VStack(alignment: .leading, spacing: CassetteSpacing.s) {
            Text("Latest Episodes")
                .font(.cassetteSectionTitle)
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                ForEach(Array(newestEpisodes.prefix(5)), id: \.id) { episode in
                    Button {
                        playPodcastEpisode(episode, channelTitle: channelTitle(for: episode.channelId))
                    } label: {
                        HStack(spacing: CassetteSpacing.m) {
                            nookArtwork(id: episode.coverArt, size: 54)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(episode.title)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .lineLimit(2)

                                HStack(spacing: 6) {
                                    Text(channelTitle(for: episode.channelId))
                                    if let date = episode.publishDate {
                                        Text("•")
                                        Text(date.formatted(date: .abbreviated, time: .omitted))
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.58))
                                .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "play.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(CassetteColors.chrisflixPurple)
                        }
                        .padding(.vertical, CassetteSpacing.s)
                    }
                    .buttonStyle(.plain)

                    if episode.id != newestEpisodes.prefix(5).last?.id {
                        Divider().overlay(.white.opacity(0.08))
                    }
                }
            }
            .padding(.horizontal, CassetteSpacing.m)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var audiobookSection: some View {
        VStack(alignment: .leading, spacing: CassetteSpacing.s) {
            HStack {
                Text("Audiobooks")
                    .font(.cassetteSectionTitle)
                    .foregroundStyle(.white)
                Spacer()
                if isLoadingAlbums {
                    ProgressView().controlSize(.small).tint(.white.opacity(0.6))
                } else {
                    Image(systemName: "books.vertical.fill")
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            if audiobookAlbums.isEmpty {
                nookEmptyCard(
                    title: "No audiobooks found yet",
                    subtitle: "Albums tagged Audiobook, Audio Book, or Spoken Word will appear here.",
                    systemImage: "book.closed"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: CassetteSpacing.m) {
                        ForEach(audiobookAlbums) { album in
                            NavigationLink {
                                AlbumDetailView(album: album)
                            } label: {
                                nookAlbumCard(album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var podcastSection: some View {
        VStack(alignment: .leading, spacing: CassetteSpacing.s) {
            HStack {
                Text("Podcasts")
                    .font(.cassetteSectionTitle)
                    .foregroundStyle(.white)
                Spacer()
                if isLoadingPodcasts {
                    ProgressView().controlSize(.small).tint(.white.opacity(0.6))
                } else {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            if !podcastChannels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: CassetteSpacing.m) {
                        ForEach(podcastChannels, id: \.id) { channel in
                            NavigationLink {
                                NookPodcastChannelView(channel: channel)
                            } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    nookArtwork(id: channel.coverArt, size: cardWidth)
                                    Text(channel.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                        .frame(width: cardWidth, alignment: .leading)
                                    Text("\(channel.episode.count) episode\(channel.episode.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else if !podcastAlbums.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: CassetteSpacing.m) {
                        ForEach(podcastAlbums) { album in
                            NavigationLink {
                                AlbumDetailView(album: album)
                            } label: {
                                nookAlbumCard(album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                nookEmptyCard(
                    title: "No podcasts found yet",
                    subtitle: "Server podcasts or albums tagged Podcast will appear here.",
                    systemImage: "mic"
                )
            }
        }
    }

    private var musicVideosSection: some View {
        VStack(alignment: .leading, spacing: CassetteSpacing.s) {
            HStack {
                Text("Music Videos")
                    .font(.cassetteSectionTitle)
                    .foregroundStyle(.white)
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

    private func nookAlbumCard(_ album: AlbumID3) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            CoverArtView(id: album.coverArt ?? album.id, size: 320)
                .frame(width: cardWidth, height: cardWidth)
                .cassetteCoverStyle(cornerRadius: CassetteCornerRadius.standard)

            Text(album.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: cardWidth, alignment: .leading)

            Text(album.artist ?? album.genre ?? "")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .frame(width: cardWidth, alignment: .leading)
        }
    }

    @ViewBuilder
    private func nookArtwork(id: String?, size: CGFloat) -> some View {
        if let id, !id.isEmpty {
            CoverArtView(id: id, size: Int(size * 2))
                .frame(width: size, height: size)
                .cassetteCoverStyle(cornerRadius: 12)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CassetteColors.chrisflixDeepPurple.opacity(0.55))
                Image(systemName: "headphones")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(width: size, height: size)
        }
    }

    private func nookEmptyCard(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: CassetteSpacing.m) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(CassetteColors.chrisflixPurple)
                .frame(width: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 0)
        }
        .padding(CassetteSpacing.m)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func channelTitle(for channelId: String) -> String {
        podcastChannels.first(where: { $0.id == channelId })?.title ?? "Podcast"
    }

    private func handleRadioTap() {
        guard let container else { return }

        guard let station = preferredLofiStation else {
            showRadioPicker = true
            return
        }

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
                container.toastService.showError("Unable to play Lo-fi Radio.")
                Logger.player.error("[NOOK-RADIO] play failed: \(error, privacy: .public)")
            }
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

    private func playPodcastEpisode(_ episode: PodcastEpisode, channelTitle: String) {
        guard let container else { return }
        let song = DisplayableSong(
            id: episode.streamId ?? episode.id,
            title: episode.title,
            artist: channelTitle,
            albumId: nil,
            albumName: channelTitle,
            artistId: nil,
            genre: "Podcast",
            duration: TimeInterval(episode.duration ?? 0),
            trackNumber: nil,
            isDownloaded: false,
            coverArtId: episode.coverArt,
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

        podcastAlbums = albums.filter { album in
            (album.genre ?? "").lowercased().contains("podcast")
        }
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

    @MainActor
    private func updateEmptyMessage() {
        if audiobookAlbums.isEmpty && podcastAlbums.isEmpty && podcastChannels.isEmpty {
            loadError = "The Nook is ready. Add audiobook/podcast tags or a server podcast feed and they’ll appear here."
        } else {
            loadError = nil
        }
    }
}

private struct NookFireplaceScene: View {
    let afterDark: Bool
    let isRadioPlaying: Bool
    let hasLofiStation: Bool
    let onRadioTap: () -> Void
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
                .offset(x: -92, y: -63)

            bookshelf
                .offset(x: 99, y: -50)

            fireplace
                .offset(y: 28)

            radio
                .offset(x: 55, y: -43)

            if afterDark {
                sleepingCat
                    .offset(x: -86, y: 90)
                    .transition(.scale.combined(with: .opacity))
            }

            Circle()
                .fill((afterDark ? CassetteColors.chrisflixPurple : Color.orange).opacity(flicker ? 0.16 : 0.09))
                .frame(width: 220, height: 220)
                .blur(radius: 34)
                .offset(y: 70)
                .allowsHitTesting(false)

            VStack {
                Spacer()
                Text(hasLofiStation
                     ? (isRadioPlaying ? "♪ Lo-fi radio is playing" : "Tap the mantel radio")
                     : "Tap the radio to choose a station")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.52))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.28), in: Capsule())
                    .padding(.bottom, 10)
            }
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
        .accessibilityLabel(isRadioPlaying ? "Pause Lo-fi Radio" : "Play Lo-fi Radio")
    }

    private var sleepingCat: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.38, green: 0.39, blue: 0.46))
                .frame(width: 68, height: 31)
                .rotationEffect(.degrees(-8))
            Circle()
                .fill(Color(red: 0.44, green: 0.45, blue: 0.52))
                .frame(width: 29, height: 29)
                .offset(x: 25, y: -6)
            Image(systemName: "moon.zzz.fill")
                .font(.caption2)
                .foregroundStyle(CassetteColors.chrisflixPurple.opacity(0.82))
                .offset(x: 49, y: -25)
        }
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

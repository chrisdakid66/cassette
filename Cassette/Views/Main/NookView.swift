// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import SwiftUI
import SwiftSonic
import OSLog

struct NookView: View {
    @Environment(\.appContainer) private var container

    @State private var audiobookAlbums: [AlbumID3] = []
    @State private var podcastAlbums: [AlbumID3] = []
    @State private var podcastChannels: [PodcastChannel] = []
    @State private var newestEpisodes: [PodcastEpisode] = []
    @State private var isLoading = false
    @State private var loadError: String?

    private let cardWidth: CGFloat = 150

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    CassetteColors.chrisflixDeepPurple.opacity(0.72),
                    CassetteColors.chrisflixPurpleBlack,
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: CassetteSpacing.xl) {
                    nookHeader

                    if isLoading && audiobookAlbums.isEmpty && podcastChannels.isEmpty && podcastAlbums.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView("Opening the Nook…")
                                .tint(CassetteColors.chrisflixPurple)
                            Spacer()
                        }
                        .padding(.vertical, 80)
                    } else {
                        if !newestEpisodes.isEmpty {
                            latestEpisodesSection
                        }

                        audiobookSection
                        podcastSection
                    }

                    if let loadError {
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
            await load()
        }
    }

    private var nookHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(CassetteColors.chrisflixPurple)

                Text("Nook")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text("Audiobooks & podcasts")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.62))
        }
        .padding(.top, CassetteSpacing.s)
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
                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(.white.opacity(0.45))
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
                Image(systemName: "mic.fill")
                    .foregroundStyle(.white.opacity(0.45))
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
    private func load() async {
        guard let library = container?.libraryService else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        async let albumsTask = try? library.allAlbums()
        async let channelsTask = try? library.podcasts()
        async let newestTask = try? library.newestPodcasts(count: 12)

        let albums = await albumsTask ?? []
        podcastChannels = await channelsTask ?? []
        newestEpisodes = await newestTask ?? []

        audiobookAlbums = albums.filter { album in
            let genre = (album.genre ?? "").lowercased()
            return genre.contains("audiobook") ||
                genre.contains("audio book") ||
                genre.contains("spoken word")
        }

        podcastAlbums = albums.filter { album in
            (album.genre ?? "").lowercased().contains("podcast")
        }

        if audiobookAlbums.isEmpty && podcastAlbums.isEmpty && podcastChannels.isEmpty {
            loadError = "The Nook is ready. Add audiobook/podcast tags or a server podcast feed and they’ll appear here."
        }
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
                                            Text(Duration.seconds(duration).formatted(.time(pattern: .hourMinuteSecond)))
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

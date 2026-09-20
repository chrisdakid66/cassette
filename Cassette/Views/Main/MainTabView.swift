// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.
// See LICENSE file in the project root for full license information.

import SwiftUI

struct MainTabView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var searchPath = NavigationPath()
    @State private var homePath = NavigationPath()
    @State private var selectedTab: AppTab = .home
    @State private var showingFullPlayer = false
    @Namespace private var playerZoom
    private let fullPlayerZoomID = "full-player"

    private enum AppTab: Hashable { case home, search, library, nook }

    private var hasTrack: Bool {
        container?.playerState.currentTrack != nil || container?.playerState.isLiveStream == true
    }

    var body: some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            tabs
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory {
                    if hasTrack {
                        MiniPlayerAccessoryView(showingFullPlayer: $showingFullPlayer)
                            .environment(\.colorScheme, colorScheme)
                            .cassetteMatchedTransitionSource(id: fullPlayerZoomID, in: playerZoom)
                    }
                }
                .fullScreenCover(isPresented: $showingFullPlayer) {
                    FullPlayerView()
                        .cassetteZoomTransition(sourceID: fullPlayerZoomID, in: playerZoom)
                }
        } else {
            // iOS 18: no tabViewBottomAccessory API. Float the mini player above the
            // tab bar via a bottom safe-area inset, supplying the material background
            // the accessory container would otherwise provide (glass falls back to
            // .ultraThinMaterial pre-26). The zoom transition stays — it's iOS 18+.
            tabs
                .safeAreaInset(edge: .bottom) {
                    if hasTrack {
                        MiniPlayerAccessoryView(showingFullPlayer: $showingFullPlayer)
                            .environment(\.colorScheme, colorScheme)
                            .cassetteMatchedTransitionSource(id: fullPlayerZoomID, in: playerZoom)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CassetteCornerRadius.large))
                            .clipShape(RoundedRectangle(cornerRadius: CassetteCornerRadius.large))
                            .overlay {
                                RoundedRectangle(cornerRadius: CassetteCornerRadius.large)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                            }
                            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                            .padding(.horizontal, CassetteSpacing.s)
                            // Lift clear of the tab bar (safeAreaInset draws over it), plus a small gap.
                            .padding(.bottom, CassetteSpacing.legacyTabBarHeight + CassetteSpacing.xs)
                    }
                }
                .fullScreenCover(isPresented: $showingFullPlayer) {
                    FullPlayerView()
                        .cassetteZoomTransition(sourceID: fullPlayerZoomID, in: playerZoom)
                }
        }
        #else
        tabs
            .safeAreaInset(edge: .bottom) {
                if hasTrack { MiniPlayerAccessoryView(showingFullPlayer: $showingFullPlayer) }
            }
            .sheet(isPresented: $showingFullPlayer) {
                FullPlayerView()
            }
        #endif
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                NavigationStack(path: $homePath) {
                    HomeView()
                }
            }

            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
                NavigationStack(path: $searchPath) {
                    SearchView(searchQuery: $searchText, path: $searchPath)
                        .navigationTitle("Search")
                }
                .searchable(text: $searchText, prompt: "Artists, albums, songs\u{2026}")
            }

            Tab("Library", systemImage: "music.note.list", value: AppTab.library) {
                NavigationStack {
                    ChrasssetteLibraryView()
                }
            }

            Tab("Nook", systemImage: "flame.fill", value: AppTab.nook) {
                NavigationStack {
                    NookView()
                }
            }
        }
        .accentColor(.cassetteAccent)

        .task(id: container?.serverState.isOnline) {
            guard container?.serverState.isOnline == true else { return }
            try? await container?.favoritesService.syncFromServer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cassetteNavigateToArtist)) { note in
            guard let id   = note.userInfo?["artistId"]   as? String,
                  let name = note.userInfo?["artistName"] as? String else { return }
            let coverArtId = note.userInfo?["coverArtId"] as? String
            showingFullPlayer = false
            selectedTab = .home
            homePath.append(HomeDestination.artistById(id: id, name: name, coverArtId: coverArtId))
        }
        .onReceive(NotificationCenter.default.publisher(for: .cassetteNavigateToPlaylist)) { note in
            guard let id   = note.userInfo?["playlistId"] as? String,
                  let name = note.userInfo?["name"]       as? String else { return }
            let coverArtId = note.userInfo?["coverArtId"] as? String
            showingFullPlayer = false
            selectedTab = .home
            homePath.append(HomeDestination.playlistById(id: id, name: name, coverArtId: coverArtId))
        }
    }
}


private struct ChrasssetteLibraryView: View {
    @Namespace private var playlistZoomNamespace

    var body: some View {
        ZStack {
            CassetteColors.chrisflixBackgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: CassetteSpacing.s) {
                    Text("Your Library")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, CassetteSpacing.m)

                    libraryLink("Playlists", systemImage: "music.note.list") {
                        PlaylistListView(zoomNamespace: playlistZoomNamespace)
                    }
                    libraryLink("Albums", systemImage: "square.stack.fill") {
                        AlbumsListView()
                    }
                    libraryLink("Artists", systemImage: "music.mic") {
                        ArtistListView()
                    }
                    libraryLink("Songs", systemImage: "music.note") {
                        SongsListView()
                    }
                    libraryLink("Favorites", systemImage: "star.fill") {
                        FavoritesView()
                    }
                    libraryLink("Downloads", systemImage: "arrow.down.circle.fill") {
                        DownloadedView()
                    }
                }
                .padding(.horizontal, CassetteSpacing.l)
                .padding(.top, CassetteSpacing.l)
                .padding(.bottom, CassetteSpacing.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func libraryLink<Destination: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: CassetteSpacing.m) {
                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 44)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, CassetteSpacing.s)
            .padding(.vertical, CassetteSpacing.m)
        }
        .buttonStyle(.plain)
    }
}

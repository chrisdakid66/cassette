// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import SwiftUI
import SwiftSonic

struct RecentlyAddedAlbumsView: View {
    let albums: [AlbumID3]

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 190), spacing: CassetteSpacing.m)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: CassetteSpacing.l) {
                ForEach(albums) { album in
                    NavigationLink(value: HomeDestination.album(album)) {
                        VStack(alignment: .leading, spacing: CassetteSpacing.xs) {
                            GeometryReader { geo in
                                CoverArtView(id: album.coverArt ?? album.id, size: Int(geo.size.width * 2))
                                    .frame(width: geo.size.width, height: geo.size.width)
                                    .cassetteCoverStyle(cornerRadius: CassetteCornerRadius.standard)
                            }
                            .aspectRatio(1, contentMode: .fit)

                            Text(album.name)
                                .font(.cassetteCaption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if let artist = album.artist {
                                Text(artist)
                                    .font(.cassetteCaption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(CassetteSpacing.l)
            .padding(.bottom, CassetteSpacing.xl)
        }
        .background(CassetteColors.chrisflixPurpleBlack.opacity(0.22).ignoresSafeArea())
        .navigationTitle("Recently Added")
        .navigationBarTitleDisplayMode(.large)
        .miniPlayerBottomMargin()
    }
}

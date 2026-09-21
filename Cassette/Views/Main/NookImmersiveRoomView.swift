// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import SwiftUI
import SwiftSonic

struct NookImmersiveRoomView: View {
    private enum Scene: Int, CaseIterable, Identifiable {
        case books
        case fireside
        case podcasts

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .books: return "Audiobook Corner"
            case .fireside: return "Fireside"
            case .podcasts: return "Podcast Table"
            }
        }

        var symbol: String {
            switch self {
            case .books: return "books.vertical.fill"
            case .fireside: return "flame.fill"
            case .podcasts: return "mic.fill"
            }
        }
    }

    let audiobookAlbums: [AlbumID3]
    let podcastAlbums: [AlbumID3]
    let podcastChannels: [PodcastChannel]
    let newestEpisodes: [PodcastEpisode]
    let radioStations: [InternetRadioStation]

    @Binding var selectedRadioName: String
    @Binding var afterDark: Bool
    @ObservedObject var weather: NookWeatherModel

    let isInstallingStarterStations: Bool
    let hasStarterStations: Bool

    let onClose: () -> Void
    let onPlayRadio: (InternetRadioStation) -> Void
    let onInstallStarterStations: () -> Void
    let onTipJarTap: () -> Void
    let onToggleAfterDark: () -> Void

    @State private var selectedScene: Scene = .fireside
    @State private var bookshelfCloseUp = false
    @State private var showDecorPlaceholder = false
    @State private var decorPlaceholderTitle = "Wall Decor"

    @AppStorage("chrasssette.nook.decor.one") private var decorOne = "sparkles"
    @AppStorage("chrasssette.nook.decor.two") private var decorTwo = "music.note"
    @AppStorage("chrasssette.nook.decor.three") private var decorThree = "gamecontroller.fill"

    private var nookStations: [InternetRadioStation] {
        let order = ["Nook Study", "Nook Café", "Nook Rain", "Nook Late Night"]
        return radioStations
            .filter { $0.name.hasPrefix("Nook ") }
            .sorted {
                (order.firstIndex(of: $0.name) ?? 999) < (order.firstIndex(of: $1.name) ?? 999)
            }
    }

    private var selectedStation: InternetRadioStation? {
        radioStations.first { $0.name.caseInsensitiveCompare(selectedRadioName) == .orderedSame }
            ?? nookStations.first
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                roomBackdrop

                TabView(selection: $selectedScene) {
                    bookshelfRoom(size: geo.size)
                        .tag(Scene.books)

                    firesideRoom(size: geo.size)
                        .tag(Scene.fireside)

                    podcastRoom(size: geo.size)
                        .tag(Scene.podcasts)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                topBar
                    .padding(.top, geo.safeAreaInsets.top + 8)
                    .padding(.horizontal, 24)
                    .frame(maxHeight: .infinity, alignment: .top)

                scenePicker
                    .padding(.horizontal, 24)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 12)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showDecorPlaceholder) {
            NavigationStack {
                NookDecorPlaceholderView(title: decorPlaceholderTitle)
            }
        }
    }

    private var roomBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: afterDark
                    ? [
                        Color(red: 0.055, green: 0.02, blue: 0.09),
                        Color(red: 0.03, green: 0.015, blue: 0.05),
                        .black
                    ]
                    : [
                        Color(red: 0.13, green: 0.065, blue: 0.085),
                        Color(red: 0.07, green: 0.04, blue: 0.055),
                        .black
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    (afterDark ? CassetteColors.chrisflixPurple : Color.orange).opacity(0.09),
                    Color.black.opacity(0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.075, blue: 0.07),
                                Color.black.opacity(0.96)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 210)
            }
        }
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            HStack(spacing: 10) {
                Image(systemName: selectedScene.symbol)
                    .font(.title3.bold())
                    .foregroundStyle(neonAccent)
                    .shadow(color: neonAccent.opacity(afterDark ? 0.92 : 0.35), radius: afterDark ? 12 : 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(afterDark ? "Nook After Dark" : "The Nook")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .chrasssetteNeonTitle(
                            accent: afterDark ? CassetteColors.chrisflixPurple : Color.orange,
                            glow: afterDark ? 0.94 : 0.30
                        )

                    Text(selectedScene.title)
                        .font(.caption.weight(.bold))
                        .chrasssetteNeonTitle(
                            accent: afterDark ? CassetteColors.chrisflixPurple : Color.orange,
                            glow: afterDark ? 0.72 : 0.22
                        )
                }
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.bold())
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.42), in: Circle())
                    .overlay {
                        Circle().strokeBorder(neonAccent.opacity(0.20), lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var scenePicker: some View {
        HStack(spacing: 8) {
            ForEach(Scene.allCases) { scene in
                Button {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        selectedScene = scene
                        if scene != .books { bookshelfCloseUp = false }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: scene.symbol)
                        if selectedScene == scene {
                            Text(scene == .fireside ? "Fireside" : (scene == .books ? "Books" : "Podcasts"))
                                .font(.caption.weight(.bold))
                        }
                    }
                    .foregroundStyle(selectedScene == scene ? .white : .white.opacity(0.56))
                    .padding(.horizontal, selectedScene == scene ? 14 : 12)
                    .padding(.vertical, 10)
                    .background(
                        selectedScene == scene
                            ? neonAccent.opacity(afterDark ? 0.34 : 0.25)
                            : Color.black.opacity(0.34),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(selectedScene == scene ? neonAccent.opacity(0.28) : .white.opacity(0.04), lineWidth: 0.8)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.black.opacity(0.34), in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
    }

    private func firesideRoom(size: CGSize) -> some View {
        ZStack {
            roomPerspective(size: size, cornerX: size.width * 0.27)
            roomGlow(x: size.width * 0.50, y: size.height * 0.52, radius: 250)

            windowView
                .frame(width: min(size.width * 0.32, 180), height: min(size.height * 0.21, 170))
                .position(x: size.width * 0.20, y: size.height * 0.33)

            wallWeatherPanel
                .position(x: size.width * 0.86, y: size.height * 0.18)

            fireplaceAssembly
                .frame(width: min(size.width * 0.68, 420), height: min(size.height * 0.51, 480))
                .position(x: size.width * 0.50, y: size.height * 0.59)

            // Shared mantel ledge grounds the interactive props in the room.
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.34, green: 0.20, blue: 0.16),
                            Color(red: 0.19, green: 0.105, blue: 0.09)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: min(size.width * 0.48, 280), height: 18)
                .shadow(color: .black.opacity(0.34), radius: 5, y: 4)
                .position(x: size.width * 0.50, y: size.height * 0.49)

            tipJar
                .position(x: size.width * 0.40, y: size.height * 0.465)

            mantelRadio
                .position(x: size.width * 0.60, y: size.height * 0.465)

            // The fire itself is a direct interaction target in expanded mode.
            Button(action: onToggleAfterDark) {
                Color.clear
                    .frame(width: min(size.width * 0.27, 170), height: min(size.height * 0.19, 170))
                    .contentShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .position(x: size.width * 0.50, y: size.height * 0.675)
            .accessibilityLabel(afterDark ? "Restore fireside lighting" : "Dim the Nook")

            if afterDark {
                sleepingCat
                    .position(x: size.width * 0.29, y: size.height * 0.76)
                    .transition(.scale.combined(with: .opacity))
            }

            if !hasStarterStations {
                starterStationButton
                    .position(x: size.width * 0.50, y: size.height * 0.865)
            } else {
                radioPresetConsole
                    .frame(width: min(size.width - 54, 470))
                    .position(x: size.width * 0.50, y: size.height * 0.875)
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 1.35, perform: onToggleAfterDark)
    }

    private func bookshelfRoom(size: CGSize) -> some View {
        ZStack {
            roomPerspective(size: size, cornerX: size.width * 0.36)
            roomGlow(x: size.width * 0.24, y: size.height * 0.48, radius: 230)

            if bookshelfCloseUp {
                closeUpBookshelf
                    .padding(.horizontal, 18)
                    .padding(.top, 112)
                    .padding(.bottom, 92)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))

                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        bookshelfCloseUp = false
                    }
                } label: {
                    Label("Room view", systemImage: "arrow.down.right.and.arrow.up.left")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.40), in: Capsule())
                }
                .buttonStyle(.plain)
                .position(x: size.width * 0.80, y: size.height * 0.18)
            } else {
                // Keep the distant shelf as actual room furniture instead of a floating card.
                distantBookshelf
                    .frame(width: min(size.width * 0.52, 325), height: min(size.height * 0.58, 500))
                    .rotation3DEffect(
                        .degrees(-7),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .leading,
                        perspective: 0.72
                    )
                    .position(x: size.width * 0.27, y: size.height * 0.59)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) {
                            bookshelfCloseUp = true
                        }
                    }

            }
        }
    }

    private func podcastRoom(size: CGSize) -> some View {
        ZStack {
            roomPerspective(size: size, cornerX: size.width * 0.35)
            roomGlow(x: size.width * 0.58, y: size.height * 0.46, radius: 210)

            decorFrame(systemImage: decorOne, title: "Left Wall")
                .frame(width: min(size.width * 0.22, 126), height: 84)
                .rotation3DEffect(.degrees(7), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.72)
                .position(x: size.width * 0.16, y: size.height * 0.31)

            decorFrame(systemImage: decorTwo, title: "Center Wall")
                .frame(width: min(size.width * 0.22, 126), height: 84)
                .position(x: size.width * 0.43, y: size.height * 0.31)

            decorFrame(systemImage: decorThree, title: "Lower Wall")
                .frame(width: min(size.width * 0.20, 118), height: 80)
                .rotation3DEffect(.degrees(7), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.72)
                .position(x: size.width * 0.17, y: size.height * 0.43)

            // Frontal room perspective: wall decor behind, table edge and legs facing the viewer.
            podcastWallArt
                .frame(width: min(size.width * 0.34, 190), height: 120)
                .position(x: size.width * 0.76, y: size.height * 0.35)

            frontProfileTable
                .frame(width: min(size.width * 0.80, 520), height: min(size.height * 0.36, 310))
                .position(x: size.width * 0.50, y: size.height * 0.63)

            standingMicrophone
                .position(x: size.width * 0.39, y: size.height * 0.585)

            coffeeMug
                .position(x: size.width * 0.64, y: size.height * 0.575)

            podcastStatus
                .frame(width: min(size.width - 60, 460))
                .position(x: size.width * 0.50, y: size.height * 0.82)
        }
    }

    private func roomPerspective(size: CGSize, cornerX: CGFloat) -> some View {
        let leftCorner = max(size.width * 0.22, min(cornerX, size.width * 0.38))
        let rightCorner = size.width * 0.76
        let floorY = size.height * 0.84

        return ZStack {
            // Left wall — cool plum.
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: leftCorner, y: 0))
                path.addLine(to: CGPoint(x: leftCorner, y: floorY))
                path.addLine(to: CGPoint(x: 0, y: size.height * 0.91))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.08, blue: 0.20),
                        Color(red: 0.095, green: 0.045, blue: 0.13)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Center wall — warmer aubergine so the corner reads without guide lines.
            Path { path in
                path.move(to: CGPoint(x: leftCorner, y: 0))
                path.addLine(to: CGPoint(x: rightCorner, y: 0))
                path.addLine(to: CGPoint(x: rightCorner, y: floorY))
                path.addLine(to: CGPoint(x: leftCorner, y: floorY))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.075, blue: 0.15),
                        Color(red: 0.105, green: 0.045, blue: 0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Right wall — blue-violet/indigo.
            Path { path in
                path.move(to: CGPoint(x: rightCorner, y: 0))
                path.addLine(to: CGPoint(x: size.width, y: 0))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.91))
                path.addLine(to: CGPoint(x: rightCorner, y: floorY))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.075, green: 0.075, blue: 0.18),
                        Color(red: 0.04, green: 0.035, blue: 0.10)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            )

            // Dark floor — no visible construction-line strokes.
            Path { path in
                path.move(to: CGPoint(x: 0, y: size.height * 0.91))
                path.addLine(to: CGPoint(x: leftCorner, y: floorY))
                path.addLine(to: CGPoint(x: rightCorner, y: floorY))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.91))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.055, green: 0.035, blue: 0.075),
                        Color.black.opacity(0.96)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .allowsHitTesting(false)
    }

    private func decorFrame(systemImage: String, title: String) -> some View {
        Button {
            decorPlaceholderTitle = title
            showDecorPlaceholder = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.28))
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(neonAccent.opacity(0.24), lineWidth: 1)
                    .padding(6)
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(neonAccent.opacity(0.78))
                    .shadow(color: neonAccent.opacity(0.24), radius: 8)
            }
            .shadow(color: .black.opacity(0.28), radius: 7, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) placeholder")
    }

    private var neonAccent: Color {
        afterDark ? CassetteColors.chrisflixPurple : Color.orange
    }

    private func roomGlow(x: CGFloat, y: CGFloat, radius: CGFloat) -> some View {
        Circle()
            .fill(neonAccent.opacity(afterDark ? 0.16 : 0.10))
            .frame(width: radius * 2, height: radius * 2)
            .blur(radius: 70)
            .position(x: x, y: y)
            .allowsHitTesting(false)
    }

    private var windowView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.20, green: 0.12, blue: 0.105))

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            CassetteColors.chrisflixDeepPurple.opacity(afterDark ? 0.68 : 0.48),
                            Color.black.opacity(0.94)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(8)
                .overlay {
                    HStack(spacing: 18) {
                        ForEach(0..<4, id: \.self) { _ in
                            Capsule()
                                .fill(Color.white.opacity(0.13))
                                .frame(width: 2, height: 34)
                                .rotationEffect(.degrees(18))
                        }
                    }
                }

            Rectangle()
                .fill(Color(red: 0.31, green: 0.18, blue: 0.14))
                .frame(height: 10)
                .offset(y: 48)
        }
        .shadow(color: .black.opacity(0.32), radius: 8, y: 5)
    }

    private var wallWeatherPanel: some View {
        Button {
            weather.refresh(force: true)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Image(systemName: weather.snapshot?.symbol ?? "location.fill")
                        .foregroundStyle(neonAccent)
                    if let snap = weather.snapshot {
                        Text("\(snap.temperature)\(snap.unit)")
                            .font(.headline.bold())
                    }
                }

                Text(weather.snapshot?.condition ?? weather.statusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(minWidth: 104, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.58),
                        Color(red: 0.13, green: 0.075, blue: 0.085).opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(neonAccent.opacity(0.24), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.28), radius: 6, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Refresh Nook weather")
    }

    private var fireplaceAssembly: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.21, green: 0.13, blue: 0.14))
                    .frame(width: w * 0.34, height: h * 0.18)

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.29, green: 0.17, blue: 0.14))
                    .frame(width: w * 0.94, height: 18)

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 0.17, green: 0.10, blue: 0.11))
                        .frame(width: w * 0.86, height: h * 0.64)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.94))
                        .frame(width: w * 0.56, height: h * 0.46)
                        .overlay(alignment: .bottom) {
                            HStack(spacing: -13) {
                                flame(height: h * 0.28, color: afterDark ? Color(red: 0.42, green: 0.15, blue: 0.96) : .orange)
                                flame(height: h * 0.33, color: afterDark ? CassetteColors.chrisflixPurple : Color(red: 1.0, green: 0.42, blue: 0.08))
                                flame(height: h * 0.26, color: afterDark ? Color(red: 0.75, green: 0.40, blue: 1.0) : Color(red: 1.0, green: 0.72, blue: 0.18))
                            }
                            .padding(.bottom, 10)
                            .shadow(color: neonAccent.opacity(0.76), radius: 22)
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func flame(height: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [afterDark ? .white.opacity(0.88) : .yellow.opacity(0.94), color],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: max(22, height * 0.36), height: height)
    }

    private var mantelRadio: some View {
        Button {
            if let selectedStation { onPlayRadio(selectedStation) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(red: 0.30, green: 0.18, blue: 0.13))
                    .frame(width: 78, height: 46)

                Circle()
                    .strokeBorder(neonAccent.opacity(0.88), lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .offset(x: -18)

                Image(systemName: "play.fill")
                    .font(.caption.bold())
                    .foregroundStyle(neonAccent)
                    .offset(x: 20)

                Capsule()
                    .fill(Color.black.opacity(0.30))
                    .frame(width: 65, height: 4)
                    .offset(y: 23)
            }
        }
        .buttonStyle(.plain)
    }

    private var tipJar: some View {
        Button(action: onTipJarTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.085))
                    .frame(width: 54, height: 52)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white.opacity(0.30), lineWidth: 1)
                    }

                Capsule()
                    .fill(.white.opacity(0.22))
                    .frame(width: 4, height: 32)
                    .offset(x: -16)

                Image(systemName: "heart.fill")
                    .font(.caption.bold())
                    .foregroundStyle(neonAccent)
                    .offset(y: 4)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.25, green: 0.16, blue: 0.12))
                    .frame(width: 43, height: 7)
                    .offset(y: -29)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tip Jar")
    }

    private var sleepingCat: some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.34, green: 0.35, blue: 0.41))
                .frame(width: 84, height: 48)

            // Tail is intentionally an open curved stroke — no full circle artifact.
            Path { path in
                path.move(to: CGPoint(x: 8, y: 29))
                path.addCurve(
                    to: CGPoint(x: 47, y: 11),
                    control1: CGPoint(x: 10, y: 8),
                    control2: CGPoint(x: 38, y: 4)
                )
            }
            .stroke(Color(red: 0.47, green: 0.48, blue: 0.56), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .frame(width: 54, height: 34)
            .offset(x: -16, y: 3)

            ZStack {
                Circle()
                    .fill(Color(red: 0.43, green: 0.44, blue: 0.51))
                    .frame(width: 32, height: 32)

                HStack(spacing: 9) {
                    Capsule().fill(Color.black.opacity(0.70)).frame(width: 6, height: 1.5)
                    Capsule().fill(Color.black.opacity(0.70)).frame(width: 6, height: 1.5)
                }

                Image(systemName: "triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.43, green: 0.44, blue: 0.51))
                    .offset(x: -8, y: -17)

                Image(systemName: "triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.43, green: 0.44, blue: 0.51))
                    .offset(x: 8, y: -17)
            }
            .offset(x: 28, y: -8)

            Text("zzz")
                .font(.caption2.bold())
                .foregroundStyle(CassetteColors.chrisflixPurple.opacity(0.86))
                .offset(x: 52, y: -33)
        }
        .accessibilityHidden(true)
    }

    private var weatherChip: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: weather.snapshot?.symbol ?? "location.fill")
                    .foregroundStyle(neonAccent)
                if let snap = weather.snapshot {
                    Text("\(snap.temperature)\(snap.unit)")
                        .font(.subheadline.bold())
                }
            }
            Text(weather.snapshot?.condition ?? weather.statusText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(.black.opacity(0.43), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(neonAccent.opacity(0.22), lineWidth: 0.8)
        }
    }

    private var starterStationButton: some View {
        Button(action: onInstallStarterStations) {
            HStack(spacing: 7) {
                if isInstallingStarterStations {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: "radio.fill")
                }
                Text("Add starter stations")
            }
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(neonAccent.opacity(0.32), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isInstallingStarterStations)
    }

    private var radioPresetStrip: some View {
        HStack(spacing: 6) {
            ForEach(nookStations, id: \.id) { station in
                Button {
                    selectedRadioName = station.name
                    onPlayRadio(station)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: radioSymbol(station.name))
                        Text(station.name.replacingOccurrences(of: "Nook ", with: ""))
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(selectedRadioName == station.name ? .white : .white.opacity(0.56))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedRadioName == station.name ? neonAccent.opacity(0.28) : Color.black.opacity(0.24),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var radioPresetConsole: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(red: 0.31, green: 0.18, blue: 0.13))
                .frame(height: 9)

            radioPresetStrip
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.17, green: 0.10, blue: 0.09),
                            Color.black.opacity(0.76)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
        .shadow(color: .black.opacity(0.34), radius: 8, y: 5)
    }

    private var podcastWallArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.12, green: 0.07, blue: 0.13))

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(neonAccent.opacity(0.26), lineWidth: 1.2)
                .padding(7)

            Image(systemName: "waveform")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(neonAccent.opacity(0.64))
                .shadow(color: neonAccent.opacity(0.22), radius: 10)
        }
        .shadow(color: .black.opacity(0.30), radius: 8, y: 5)
    }

    private func radioSymbol(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("café") || n.contains("cafe") { return "cup.and.saucer.fill" }
        if n.contains("rain") { return "cloud.rain.fill" }
        if n.contains("late") { return "moon.stars.fill" }
        return "books.vertical.fill"
    }

    private var distantBookshelf: some View {
        shelfGrid(closeUp: false)
            .padding(12)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.12, blue: 0.085),
                        Color(red: 0.095, green: 0.055, blue: 0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.orange.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.38), radius: 20, y: 10)
    }

    private var closeUpBookshelf: some View {
        ZStack(alignment: .topLeading) {
            shelfGrid(closeUp: true)
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.12, blue: 0.085),
                            Color(red: 0.08, green: 0.045, blue: 0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(neonAccent)
                Text("Audiobook Corner")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .shadow(color: afterDark ? CassetteColors.chrisflixPurple.opacity(0.76) : .clear, radius: 9)
            }
            .padding(18)
        }
        .overlay {
            Rectangle().strokeBorder(.orange.opacity(0.13), lineWidth: 1)
        }
    }

    private func shelfGrid(closeUp: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { shelf in
                HStack(alignment: .bottom, spacing: closeUp ? 10 : 7) {
                    ForEach(0..<4, id: \.self) { slot in
                        let index = shelf * 4 + slot
                        if audiobookAlbums.indices.contains(index) {
                            let album = audiobookAlbums[index]
                            NavigationLink {
                                AlbumDetailView(album: album)
                            } label: {
                                CoverArtView(id: album.coverArt ?? album.id, size: closeUp ? 300 : 220)
                                    .frame(
                                        width: closeUp ? 76 : 56,
                                        height: closeUp ? 112 : 82
                                    )
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
                                .frame(
                                    width: closeUp ? 42 : 31,
                                    height: closeUp ? CGFloat(98 + ((slot + shelf) % 3) * 14) : CGFloat(68 + ((slot + shelf) % 3) * 11)
                                )
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, closeUp ? 20 : 14)
                .padding(.top, closeUp ? 16 : 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                Rectangle()
                    .fill(Color(red: 0.27, green: 0.145, blue: 0.095))
                    .frame(height: closeUp ? 16 : 12)
            }
        }
    }

    private var frontProfileTable: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Perspective tabletop with visible thickness and a softer front edge.
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height * 0.30
                    path.move(to: CGPoint(x: w * 0.13, y: h * 0.10))
                    path.addLine(to: CGPoint(x: w * 0.87, y: h * 0.10))
                    path.addLine(to: CGPoint(x: w * 0.97, y: h * 0.88))
                    path.addLine(to: CGPoint(x: w * 0.03, y: h * 0.88))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.40, green: 0.22, blue: 0.16),
                            Color(red: 0.26, green: 0.13, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.42), radius: 16, y: 10)

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.25, green: 0.13, blue: 0.11),
                                Color(red: 0.14, green: 0.07, blue: 0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: geo.size.width * 0.90, height: geo.size.height * 0.10)
                    .offset(y: geo.size.height * 0.255)

                HStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.27, green: 0.14, blue: 0.12),
                                    Color(red: 0.11, green: 0.06, blue: 0.075)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 42)
                        .rotationEffect(.degrees(1.8))

                    Spacer()

                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.27, green: 0.14, blue: 0.12),
                                    Color(red: 0.11, green: 0.06, blue: 0.075)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 42)
                        .rotationEffect(.degrees(-1.8))
                }
                .padding(.horizontal, geo.size.width * 0.15)
                .padding(.top, geo.size.height * 0.31)
                .frame(height: geo.size.height * 0.95)
            }
        }
    }

    private var standingMicrophone: some View {
        VStack(spacing: -2) {
            Image(systemName: "mic.fill")
                .font(.system(size: 62, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .shadow(color: CassetteColors.chrisflixPurple.opacity(0.52), radius: 18)

            Capsule()
                .fill(.white.opacity(0.54))
                .frame(width: 6, height: 82)

            Capsule()
                .fill(.white.opacity(0.40))
                .frame(width: 62, height: 6)
                .shadow(color: .black.opacity(0.44), radius: 5, y: 4)
        }
    }

    private var coffeeMug: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.30))
                .frame(width: 74, height: 16)
                .offset(y: 24)

            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.87, blue: 0.76),
                            Color(red: 0.70, green: 0.62, blue: 0.50)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 54, height: 46)

            Circle()
                .strokeBorder(Color(red: 0.83, green: 0.77, blue: 0.66), lineWidth: 7)
                .frame(width: 26, height: 26)
                .offset(x: 30)

            Image(systemName: "cup.and.saucer.fill")
                .font(.caption)
                .foregroundStyle(Color(red: 0.30, green: 0.18, blue: 0.13))
        }
    }

    @ViewBuilder
    private var podcastStatus: some View {
        if !newestEpisodes.isEmpty {
            VStack(spacing: 6) {
                ForEach(Array(newestEpisodes.prefix(2)), id: \.id) { episode in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(episode.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(channelTitle(episode.channelId))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.50))
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "waveform")
                            .foregroundStyle(neonAccent)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 11))
                }
            }
        } else {
            Text("Add a server podcast feed or tag an album Podcast and it will appear here.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
        }
    }

    private func channelTitle(_ channelId: String) -> String {
        podcastChannels.first(where: { $0.id == channelId })?.title ?? "Podcast"
    }
}

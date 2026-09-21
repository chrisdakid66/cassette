// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import SwiftUI

struct AnimatedAmbientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var warm: Bool = false

    @State private var phase = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                LinearGradient(
                    colors: warm
                        ? [
                            Color(red: 0.13, green: 0.055, blue: 0.12),
                            CassetteColors.chrisflixPurpleBlack,
                            .black
                        ]
                        : [
                            CassetteColors.chrisflixDeepPurple.opacity(0.80),
                            CassetteColors.chrisflixPurpleBlack,
                            .black
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(
                        (warm ? Color.orange : CassetteColors.chrisflixPurple)
                            .opacity(warm ? 0.22 : 0.28)
                    )
                    .frame(width: geo.size.width * 0.90)
                    .blur(radius: 74)
                    .offset(
                        x: phase ? geo.size.width * 0.28 : -geo.size.width * 0.34,
                        y: phase ? geo.size.height * 0.34 : -geo.size.height * 0.12
                    )

                Circle()
                    .fill(
                        (warm ? Color(red: 0.55, green: 0.17, blue: 0.18) : Color(red: 0.15, green: 0.44, blue: 0.92))
                            .opacity(warm ? 0.16 : 0.19)
                    )
                    .frame(width: geo.size.width * 0.72)
                    .blur(radius: 88)
                    .offset(
                        x: phase ? -geo.size.width * 0.31 : geo.size.width * 0.34,
                        y: phase ? geo.size.height * 0.00 : geo.size.height * 0.58
                    )

                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                (warm ? Color.orange : Color(red: 0.63, green: 0.27, blue: 1.0)).opacity(0.18),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * 1.4, height: 86)
                    .blur(radius: 28)
                    .rotationEffect(.degrees(phase ? 24 : -18))
                    .offset(y: phase ? geo.size.height * 0.16 : geo.size.height * 0.62)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 12.5).repeatForever(autoreverses: true)) {
                    phase = true
                }
            }
            .onChange(of: reduceMotion) { _, newValue in
                if newValue {
                    phase = false
                } else {
                    withAnimation(.easeInOut(duration: 12.5).repeatForever(autoreverses: true)) {
                        phase = true
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

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
                            .opacity(warm ? 0.15 : 0.20)
                    )
                    .frame(width: geo.size.width * 0.90)
                    .blur(radius: 74)
                    .offset(
                        x: phase ? geo.size.width * 0.20 : -geo.size.width * 0.28,
                        y: phase ? geo.size.height * 0.28 : -geo.size.height * 0.08
                    )

                Circle()
                    .fill(
                        (warm ? Color(red: 0.55, green: 0.17, blue: 0.18) : Color(red: 0.15, green: 0.44, blue: 0.92))
                            .opacity(warm ? 0.11 : 0.13)
                    )
                    .frame(width: geo.size.width * 0.72)
                    .blur(radius: 88)
                    .offset(
                        x: phase ? -geo.size.width * 0.24 : geo.size.width * 0.28,
                        y: phase ? geo.size.height * 0.02 : geo.size.height * 0.50
                    )

                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                (warm ? Color.orange : Color(red: 0.63, green: 0.27, blue: 1.0)).opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * 1.4, height: 86)
                    .blur(radius: 28)
                    .rotationEffect(.degrees(phase ? 18 : -14))
                    .offset(y: phase ? geo.size.height * 0.20 : geo.size.height * 0.56)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) {
                    phase = true
                }
            }
            .onChange(of: reduceMotion) { _, newValue in
                if newValue {
                    phase = false
                } else {
                    withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) {
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

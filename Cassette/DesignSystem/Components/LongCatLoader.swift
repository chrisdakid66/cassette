// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import SwiftUI

/// Chrasssette's cozy loading indicator: a long cat curling around the spinner path.
struct LongCatLoader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spinning = false

    var label: String = "Opening the Nook…"

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .trim(from: 0.06, to: 0.83)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.43, green: 0.72, blue: 0.98),
                                CassetteColors.chrisflixPurple,
                                Color.orange.opacity(0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 11, lineCap: .round)
                    )
                    .frame(width: 58, height: 58)

                catHead
                    .offset(x: 24, y: -17)

                Capsule()
                    .fill(Color(red: 0.43, green: 0.72, blue: 0.98))
                    .frame(width: 18, height: 8)
                    .rotationEffect(.degrees(-34))
                    .offset(x: -25, y: 18)
            }
            .frame(width: 76, height: 76)
            .rotationEffect(.degrees(spinning ? 360 : 0))

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.55).repeatForever(autoreverses: false)) {
                spinning = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var catHead: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.50, green: 0.78, blue: 0.98))
                .frame(width: 23, height: 23)

            HStack(spacing: 7) {
                Circle().fill(.black.opacity(0.78)).frame(width: 2.7, height: 2.7)
                Circle().fill(.black.opacity(0.78)).frame(width: 2.7, height: 2.7)
            }
            .offset(y: 1)

            Path { path in
                path.move(to: CGPoint(x: 1, y: 11))
                path.addLine(to: CGPoint(x: 6, y: 1))
                path.addLine(to: CGPoint(x: 10, y: 11))
                path.closeSubpath()
            }
            .fill(Color(red: 0.50, green: 0.78, blue: 0.98))
            .frame(width: 11, height: 11)
            .offset(x: -6, y: -13)

            Path { path in
                path.move(to: CGPoint(x: 1, y: 11))
                path.addLine(to: CGPoint(x: 6, y: 1))
                path.addLine(to: CGPoint(x: 10, y: 11))
                path.closeSubpath()
            }
            .fill(Color(red: 0.50, green: 0.78, blue: 0.98))
            .frame(width: 11, height: 11)
            .offset(x: 6, y: -13)
        }
    }
}

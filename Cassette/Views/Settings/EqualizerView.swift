// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import SwiftUI

struct EqualizerView: View {
    @Environment(\.appContainer) private var container

    private let frequencyLabels = ["60 Hz", "150 Hz", "400 Hz", "1 kHz", "2.4 kHz", "15 kHz"]

    var body: some View {
        let selected = container?.equalizerSettings.preset ?? .flat

        ScrollView {
            VStack(spacing: 0) {
                EqualizerCurvePreview(gains: selected.gains)
                    .frame(height: 250)
                    .padding(.horizontal, CassetteSpacing.l)
                    .padding(.top, CassetteSpacing.l)

                HStack {
                    ForEach(frequencyLabels, id: \.self) { label in
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, CassetteSpacing.m)
                .padding(.bottom, CassetteSpacing.l)

                VStack(spacing: 0) {
                    ForEach(EqualizerPreset.allCases) { preset in
                        Button {
                            guard let container else { return }
                            container.equalizerSettings.preset = preset
                            Task { await container.playerService.equalizerSettingsDidChange() }
                        } label: {
                            HStack {
                                Text(preset.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if preset == selected {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(CassetteColors.chrisflixPurple)
                                }
                            }
                            .font(.title3)
                            .padding(.horizontal, CassetteSpacing.l)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if preset != EqualizerPreset.allCases.last {
                            Divider()
                                .padding(.leading, CassetteSpacing.l)
                        }
                    }
                }
                .background(.black.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, CassetteSpacing.m)
                .padding(.bottom, CassetteSpacing.xl)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    CassetteColors.chrisflixPurpleBlack.opacity(0.65),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Equalizer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EqualizerCurvePreview: View {
    let gains: [Float]

    private let minGain: Float = -12
    private let maxGain: Float = 12

    var body: some View {
        GeometryReader { geo in
            let points = makePoints(size: geo.size)

            ZStack {
                ForEach(0..<6, id: \.self) { index in
                    Rectangle()
                        .fill(.white.opacity(0.045))
                        .frame(width: 1)
                        .position(
                            x: xPosition(index: index, width: geo.size.width),
                            y: geo.size.height / 2
                        )
                        .frame(height: geo.size.height)
                }

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: geo.size.height))
                    path.addLine(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    if let last = points.last {
                        path.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                    }
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            CassetteColors.chrisflixPurple.opacity(0.44),
                            CassetteColors.chrisflixDeepPurple.opacity(0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    CassetteColors.chrisflixPurple,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )

                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(.white)
                        .frame(width: 18, height: 18)
                        .shadow(color: CassetteColors.chrisflixPurple.opacity(0.35), radius: 5)
                        .position(point)
                }
            }
        }
    }

    private func makePoints(size: CGSize) -> [CGPoint] {
        let count = max(gains.count, 1)
        return gains.enumerated().map { index, gain in
            let x = xPosition(index: index, width: size.width)
            let clamped = min(max(gain, minGain), maxGain)
            let normalized = CGFloat((clamped - minGain) / (maxGain - minGain))
            let y = size.height - (normalized * size.height)
            return CGPoint(x: x, y: y)
        }
    }

    private func xPosition(index: Int, width: CGFloat) -> CGFloat {
        let count = max(gains.count - 1, 1)
        return CGFloat(index) / CGFloat(count) * width
    }
}

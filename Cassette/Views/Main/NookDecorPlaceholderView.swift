// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import SwiftUI

struct NookDecorPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    CassetteColors.chrisflixPurpleBlack,
                    CassetteColors.chrisflixDeepPurple.opacity(0.55),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(CassetteColors.chrisflixPurple)
                    .shadow(color: CassetteColors.chrisflixPurple.opacity(0.55), radius: 12)

                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Placeholder page")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

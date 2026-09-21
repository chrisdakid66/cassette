// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import SwiftUI

extension View {
    /// Chrasssette's soft neon title treatment. Intended for page/scene titles,
    /// not body copy, so the glow stays special instead of turning into visual noise.
    func chrasssetteNeonTitle(
        accent: Color = CassetteColors.chrisflixPurple,
        glow: Double = 0.58
    ) -> some View {
        self
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.white,
                        accent.opacity(0.94),
                        accent
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: accent.opacity(glow), radius: 9)
            .shadow(color: accent.opacity(glow * 0.45), radius: 18)
    }
}

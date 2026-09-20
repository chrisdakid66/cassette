// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.
// See LICENSE file in the project root for full license information.

import AVFoundation
import AudioStreaming
import OSLog

actor ReplayGainService {
    /// ReplayGain and the user EQ intentionally share one AVAudioUnitEQ node:
    /// ReplayGain owns globalGain while Chrasssette EQ owns the six filter bands.
    private let eqNode = AVAudioUnitEQ(numberOfBands: 6)
    private var isAttached = false
    private var replayGainDB: Float = 0
    private var equalizerHeadroomDB: Float = 0

    private static let equalizerFrequencies: [Float] = [60, 150, 400, 1_000, 2_400, 15_000]

    init() {
        for (index, band) in eqNode.bands.enumerated() {
            band.frequency = Self.equalizerFrequencies[index]
            band.bandwidth = 1.0
            band.gain = 0
            band.bypass = false

            switch index {
            case 0:
                band.filterType = .lowShelf
            case eqNode.bands.count - 1:
                band.filterType = .highShelf
            default:
                band.filterType = .parametric
            }
        }
    }

    func attach(to player: AudioPlayer) {
        guard !isAttached else { return }
        player.attach(node: eqNode)
        isAttached = true
    }

    /// Applies gain for the given track using a pre-captured settings snapshot.
    func apply(track: DisplayableSong, config: ReplayGainConfig) {
        replayGainDB = Self.computeGain(
            enabled: config.enabled,
            mode: config.mode,
            preAmp: config.preAmp,
            preventClipping: config.preventClipping,
            trackGain: track.replayGainTrackGain,
            trackPeak: track.replayGainTrackPeak,
            albumGain: track.replayGainAlbumGain,
            albumPeak: track.replayGainAlbumPeak,
            baseGain: track.replayGainBaseGain,
            fallbackGain: track.replayGainFallbackGain
        )
        applyCombinedGlobalGain()
    }

    /// Re-applies gain to the current track (nil track resets ReplayGain to 0 dB).
    func apply(currentTrack: DisplayableSong?, config: ReplayGainConfig) {
        guard let track = currentTrack else {
            replayGainDB = 0
            applyCombinedGlobalGain()
            return
        }
        apply(track: track, config: config)
    }

    /// Applies the currently selected Chrasssette EQ curve without interrupting playback.
    func applyEqualizer(config: EqualizerConfig) {
        for (index, band) in eqNode.bands.enumerated() {
            let gain = config.gains.indices.contains(index) ? config.gains[index] : 0
            band.gain = gain.clamped(to: -12...12)
            band.bypass = false
        }

        // Any positive boost can push a full-scale signal above 0 dBFS.
        // Pull global gain down by the strongest boosted band as simple, predictable headroom.
        let maxBoost = max(0, config.gains.max() ?? 0)
        equalizerHeadroomDB = -maxBoost
        applyCombinedGlobalGain()

        Logger.player.info(
            "Equalizer preset applied: \(config.preset.displayName, privacy: .public), headroom \(self.equalizerHeadroomDB, privacy: .public) dB"
        )
    }

    /// Resets ReplayGain to 0 dB while preserving the selected EQ/headroom.
    func resetGain() {
        replayGainDB = 0
        applyCombinedGlobalGain()
    }

    private func applyCombinedGlobalGain() {
        // AVAudioUnitEQ.globalGain valid range: −96…+24 dB.
        eqNode.globalGain = (replayGainDB + equalizerHeadroomDB).clamped(to: -96...24)
    }

    // MARK: - Gain computation (pure, static, testable)

    /// Computes the EQ gain in dB from raw settings values.
    /// Returns 0.0 when disabled or when no gain data is available (play untouched).
    nonisolated static func computeGain(
        enabled: Bool,
        mode: ReplayGainMode,
        preAmp: Double,
        preventClipping: Bool,
        trackGain: Double?,
        trackPeak: Double?,
        albumGain: Double?,
        albumPeak: Double?,
        baseGain: Double?,
        fallbackGain: Double?
    ) -> Float {
        guard enabled else { return 0.0 }

        let selectedGain: Double?
        let selectedPeak: Double?
        switch mode {
        case .track:
            selectedGain = trackGain
            selectedPeak = trackPeak
        case .album:
            selectedGain = albumGain
            selectedPeak = albumPeak
        }

        let gainDB: Double
        let peakLinear: Double?
        if let g = selectedGain {
            gainDB = g
            peakLinear = selectedPeak
        } else if let fg = fallbackGain {
            gainDB = fg
            peakLinear = nil
        } else {
            return 0.0
        }

        let totalDB = gainDB + (baseGain ?? 0.0) + preAmp
        let gainLinear = pow(10.0, totalDB / 20.0)

        let finalLinear: Double
        if preventClipping, let peak = peakLinear, peak > 0 {
            finalLinear = min(gainLinear, 1.0 / peak)
        } else {
            finalLinear = gainLinear
        }

        let finalDB = 20.0 * log10(max(finalLinear, 0.0001))
        return Float(finalDB.clamped(to: -96.0...24.0))
    }
}

// MARK: - Comparable clamping helper

fileprivate extension Comparable {
    nonisolated func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

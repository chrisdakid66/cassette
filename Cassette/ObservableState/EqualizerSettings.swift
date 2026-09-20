// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import Foundation
import Observation

nonisolated enum EqualizerPreset: String, CaseIterable, Sendable, Codable, Identifiable {
    case deep
    case electronic
    case flat
    case hipHop
    case jazz
    case latin
    case loudness
    case lounge
    case piano
    case pop
    case rnb
    case rock
    case smallSpeakers
    case spokenWord
    case trebleBooster
    case trebleReducer
    case vocalBooster

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deep: return "Deep"
        case .electronic: return "Electronic"
        case .flat: return "Flat"
        case .hipHop: return "Hip-Hop"
        case .jazz: return "Jazz"
        case .latin: return "Latin"
        case .loudness: return "Loudness"
        case .lounge: return "Lounge"
        case .piano: return "Piano"
        case .pop: return "Pop"
        case .rnb: return "R&B"
        case .rock: return "Rock"
        case .smallSpeakers: return "Small Speakers"
        case .spokenWord: return "Spoken Word"
        case .trebleBooster: return "Treble Booster"
        case .trebleReducer: return "Treble Reducer"
        case .vocalBooster: return "Vocal Booster"
        }
    }

    /// Six-band curve in dB: 60, 150, 400, 1k, 2.4k, 15k Hz.
    var gains: [Float] {
        switch self {
        case .deep:           return [ 6.0,  4.5,  1.5,  0.0, -1.0, -2.0]
        case .electronic:     return [ 5.5,  3.0,  0.0,  1.5,  3.5,  5.0]
        case .flat:           return [ 0.0,  0.0,  0.0,  0.0,  0.0,  0.0]
        case .hipHop:         return [ 5.5,  4.0,  1.0,  0.0,  2.0,  3.5]
        case .jazz:           return [ 3.0,  1.5, -1.0,  2.0,  0.0,  3.5]
        case .latin:          return [ 4.0,  2.0,  0.0,  1.0,  2.5,  3.5]
        case .loudness:       return [ 5.5,  3.5,  0.0,  0.5,  3.5,  5.5]
        case .lounge:         return [-1.0,  0.0,  2.5,  4.0,  4.0,  0.0]
        case .piano:          return [ 0.0,  1.0,  2.0,  3.0,  3.5,  1.0]
        case .pop:            return [-1.0,  1.0,  3.0,  4.0,  2.5, -0.5]
        case .rnb:            return [ 4.5,  3.0,  1.0,  0.0,  2.0,  3.5]
        case .rock:           return [ 4.0,  2.5, -1.0,  1.0,  3.0,  4.0]
        case .smallSpeakers:  return [ 0.0,  0.0,  0.0,  0.5,  2.0,  4.5]
        case .spokenWord:     return [-2.0, -1.5,  2.5,  4.5,  4.5,  0.0]
        case .trebleBooster:  return [ 0.0,  0.0,  0.0,  0.5,  2.5,  5.5]
        case .trebleReducer:  return [ 2.5,  2.0,  1.0,  0.0, -2.0, -4.5]
        case .vocalBooster:   return [-2.0, -1.5,  3.0,  4.5,  3.5,  0.0]
        }
    }
}

nonisolated struct EqualizerConfig: Sendable {
    let preset: EqualizerPreset
    let gains: [Float]
}

@Observable
@MainActor
final class EqualizerSettings {
    @ObservationIgnored private var _preset: EqualizerPreset

    private static let presetKey = "chrasssette.equalizer.preset"

    var preset: EqualizerPreset {
        get {
            access(keyPath: \.preset)
            return _preset
        }
        set {
            withMutation(keyPath: \.preset) {
                _preset = newValue
            }
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.presetKey)
        }
    }

    var config: EqualizerConfig {
        EqualizerConfig(preset: _preset, gains: _preset.gains)
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.presetKey),
           let saved = EqualizerPreset(rawValue: raw) {
            _preset = saved
        } else {
            _preset = .flat
        }
    }
}

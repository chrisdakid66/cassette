// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

#if canImport(UIKit)
import SwiftUI
import UIKit
import ImageIO

struct AnimatedHomeBannerImageView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = .clear
        view.image = Self.decodeImage(from: data)
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = Self.decodeImage(from: data)
        uiView.startAnimating()
    }

    static func isAnimatedGIF(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetCount(source) > 1
    }

    private static func decodeImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }

        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            return UIImage(data: data)
        }

        var frames: [UIImage] = []
        var totalDuration: TimeInterval = 0

        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }

            let duration = frameDuration(source: source, index: index)
            totalDuration += duration
            frames.append(UIImage(cgImage: cgImage))
        }

        guard !frames.isEmpty else { return UIImage(data: data) }

        if totalDuration <= 0 {
            totalDuration = Double(frames.count) * 0.10
        }

        return UIImage.animatedImage(with: frames, duration: totalDuration) ?? frames.first
    }

    private static func frameDuration(source: CGImageSource, index: Int) -> TimeInterval {
        let defaultDuration = 0.10

        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return defaultDuration
        }

        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double
        let duration = unclamped ?? clamped ?? defaultDuration

        // Very small GIF frame delays are commonly browser-normalized.
        return duration < 0.02 ? defaultDuration : duration
    }
}
#endif

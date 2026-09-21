// Cassette — Music client for Subsonic/OpenSubsonic servers
// Copyright (C) 2026 Mathieu Dubart
// Licensed under the Mozilla Public License 2.0.

import Foundation
import CoreLocation
import Combine
import SwiftUI

struct NookWeatherSnapshot: Sendable {
    let temperature: Int
    let feelsLike: Int
    let condition: String
    let symbol: String
    let unit: String
    let isDay: Bool
}

@MainActor
final class NookWeatherModel: NSObject, ObservableObject {
    @Published private(set) var snapshot: NookWeatherSnapshot?
    @Published private(set) var statusText = "Finding local weather…"
    @Published private(set) var permissionDenied = false

    private let locationManager = CLLocationManager()
    private var hasRequestedLocation = false
    private var lastUpdatedAt: Date?
    private let refreshInterval: TimeInterval = 30 * 60

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func refresh(force: Bool = false) {
        if !force,
           let lastUpdatedAt,
           Date().timeIntervalSince(lastUpdatedAt) < refreshInterval {
            return
        }

        permissionDenied = false
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestLocation()
        case .denied, .restricted:
            permissionDenied = true
            statusText = "Location off"
        @unknown default:
            statusText = "Weather unavailable"
        }
    }

    private func requestLocation() {
        guard !hasRequestedLocation else { return }
        hasRequestedLocation = true
        statusText = "Updating weather…"
        locationManager.requestLocation()
    }

    private func fetchWeather(for location: CLLocation) async {
        defer { hasRequestedLocation = false }

        let useMetric = Locale.current.measurementSystem == .metric
        let tempUnit = useMetric ? "celsius" : "fahrenheit"
        let displayUnit = useMetric ? "°C" : "°F"

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.5f", location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.5f", location.coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day,precipitation"),
            URLQueryItem(name: "temperature_unit", value: tempUnit),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else {
            statusText = "Weather unavailable"
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                statusText = "Weather unavailable"
                return
            }

            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let condition = Self.describe(code: decoded.current.weather_code, isDay: decoded.current.is_day == 1)

            snapshot = NookWeatherSnapshot(
                temperature: Int(decoded.current.temperature_2m.rounded()),
                feelsLike: Int(decoded.current.apparent_temperature.rounded()),
                condition: condition.text,
                symbol: condition.symbol,
                unit: displayUnit,
                isDay: decoded.current.is_day == 1
            )
            statusText = condition.text
            lastUpdatedAt = Date()
        } catch {
            statusText = "Weather unavailable"
        }
    }

    func refreshIfStale() {
        refresh(force: false)
    }

    private static func describe(code: Int, isDay: Bool) -> (text: String, symbol: String) {
        switch code {
        case 0:
            return (isDay ? "Clear" : "Clear night", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1, 2:
            return ("Partly cloudy", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3:
            return ("Cloudy", "cloud.fill")
        case 45, 48:
            return ("Foggy", "cloud.fog.fill")
        case 51, 53, 55, 56, 57:
            return ("Drizzle", "cloud.drizzle.fill")
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return ("Rainy", "cloud.rain.fill")
        case 71, 73, 75, 77, 85, 86:
            return ("Snowy", "cloud.snow.fill")
        case 95, 96, 99:
            return ("Stormy", "cloud.bolt.rain.fill")
        default:
            return ("Outside", "cloud.fill")
        }
    }
}

extension NookWeatherModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                self.requestLocation()
            case .denied, .restricted:
                self.permissionDenied = true
                self.statusText = "Location off"
                self.hasRequestedLocation = false
            case .notDetermined:
                break
            @unknown default:
                self.statusText = "Weather unavailable"
                self.hasRequestedLocation = false
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            await self?.fetchWeather(for: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.statusText = "Weather unavailable"
            self?.hasRequestedLocation = false
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    let current: Current

    struct Current: Decodable {
        let temperature_2m: Double
        let apparent_temperature: Double
        let weather_code: Int
        let is_day: Int
        let precipitation: Double
    }
}

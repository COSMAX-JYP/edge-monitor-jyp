import Combine
import CoreLocation
import Foundation
import AppKit
import os

struct WeatherSnapshot {
    var temperature: Double = .nan
    var feelsLike: Double = .nan
    var humidity: Int = 0
    var windSpeed: Double = 0
    var uvIndex: Double = 0
    var weatherCode: Int = -1
    var locationName: String = ""

    var icon: String {
        switch weatherCode {
        case 0: return "sun.max.fill"
        case 1...3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57, 61...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "snowflake"
        case 95...99: return "cloud.bolt.fill"
        default: return "cloud.fill"
        }
    }

    var description: String {
        switch weatherCode {
        case 0: return "맑음"
        case 1: return "대체로 맑음"
        case 2: return "부분적으로 흐림"
        case 3: return "흐림"
        case 45, 48: return "안개"
        case 51...57: return "이슬비"
        case 61...67: return "비"
        case 71...77: return "눈"
        case 80...82: return "소나기"
        case 85, 86: return "눈 소나기"
        case 95...99: return "뇌우"
        default: return weatherCode < 0 ? "--" : "구름"
        }
    }
}

@MainActor
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var snapshot = WeatherSnapshot()
    @Published var hasLocationAccess = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var locationStatusText = ""

    private let manager = CLLocationManager()
    private var timer: Timer?
    private var currentLocation: CLLocation?
    private var lastGeocodedLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        refreshAuthorizationState()
    }

    deinit {
        manager.stopUpdatingLocation()
        manager.delegate = nil
        timer?.invalidate()
    }

    func start() {
        requestAccess()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
    }

    func requestAccess() {
        let status = manager.authorizationStatus
        locationStatusText = Self.statusDescription(status)
        switch status {
        case .notDetermined:
            NSApp.activate(ignoringOtherApps: true)
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorized:
            hasLocationAccess = true
            errorMessage = nil
            manager.startUpdatingLocation()
        case .denied, .restricted:
            hasLocationAccess = false
            openLocationPrivacySettings()
        @unknown default:
            hasLocationAccess = false
            openLocationPrivacySettings()
        }
    }

    func refreshAuthorizationState() {
        let status = manager.authorizationStatus
        locationStatusText = Self.statusDescription(status)
        hasLocationAccess = (status == .authorizedAlways || status == .authorized)
    }

    func refresh() async {
        guard let loc = currentLocation else { return }
        await fetchWeather(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
        await reverseGeocode(loc)
    }

    private func fetchWeather(lat: Double, lon: Double) async {
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=uv_index_max&timezone=auto")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            var snap = snapshot
            snap.temperature = decoded.current.temperature_2m
            snap.feelsLike = decoded.current.apparent_temperature
            snap.humidity = decoded.current.relative_humidity_2m
            snap.windSpeed = decoded.current.wind_speed_10m
            snap.weatherCode = decoded.current.weather_code
            snap.uvIndex = decoded.daily.uv_index_max.first ?? 0
            snapshot = snap
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            let msg = "날씨 조회 실패: \(error.localizedDescription)"
            errorMessage = msg
            AppLog.weather.error("\(msg)")
            ErrorBus.shared.publish("날씨", msg)
        }
    }

    private func reverseGeocode(_ location: CLLocation) async {
        if let lastGeocodedLocation,
           location.distance(from: lastGeocodedLocation) < 500,
           !snapshot.locationName.isEmpty {
            return
        }
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ko_KR"))
            if let p = placemarks.first {
                let parts = [p.administrativeArea, p.locality, p.subLocality].compactMap { $0 }
                snapshot.locationName = parts.joined(separator: " ")
                lastGeocodedLocation = location
            }
        } catch {
            // 무시
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = loc
            await self.refresh()
            manager.stopUpdatingLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
            self.refreshAuthorizationState()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            self.locationStatusText = Self.statusDescription(status)
            self.hasLocationAccess = (status == .authorizedAlways || status == .authorized)
            if self.hasLocationAccess {
                self.errorMessage = nil
                manager.startUpdatingLocation()
            }
        }
    }

    private func openLocationPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private static func statusDescription(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "권한 미요청"
        case .restricted:
            return "제한됨"
        case .denied:
            return "거부됨"
        case .authorizedAlways, .authorized:
            return "허용됨"
        @unknown default:
            return "알 수 없음"
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    let current: Current
    let daily: Daily
    struct Current: Decodable {
        let temperature_2m: Double
        let relative_humidity_2m: Int
        let apparent_temperature: Double
        let weather_code: Int
        let wind_speed_10m: Double
    }
    struct Daily: Decodable {
        let uv_index_max: [Double]
    }
}

import Combine
import Foundation

/// Current local weather for the Home surface.
struct Weather: Equatable {
    var temperature: Int      // whole degrees, in the locale's unit
    var unitSymbol: String    // "F" or "C"
    var symbolName: String    // SF Symbol for the condition
    var condition: String     // e.g. "Partly cloudy"
    var city: String?
}

/// Fetches current weather over keyless HTTPS and publishes it to `HomeView`
/// (mirrors `LyricsService`'s networking). Location comes from IP geolocation
/// (`ipapi.co`) rather than CoreLocation — the permission prompt is unreliable in
/// this unbundled build and IP-geo needs no entitlement. Refreshes every 30 min.
///
/// Privacy: the IP goes to `ipapi.co` and the resolved lat/lon to Open-Meteo — an
/// opt-out is a natural addition to M6's settings (alongside the lyrics toggle).
@MainActor
final class WeatherService: ObservableObject {
    @Published private(set) var current: Weather?

    private static let userAgent = "dyNotch/0.1 (https://github.com/jy26/dynotch)"
    private static let geoURL = "https://ipapi.co/json/"

    private var refreshTimer: Timer?
    private var location: (lat: Double, lon: Double, city: String?)?

    /// Fetches now, then every 30 minutes.
    func start() {
        Task { [weak self] in await self?.refresh() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refresh() async {
        if location == nil, let geo = await get(Self.geoURL, as: IPGeo.self) {
            location = (geo.latitude, geo.longitude, geo.city)
        }
        guard let location else { log("weather: no location yet"); return }

        let url = "https://api.open-meteo.com/v1/forecast?latitude=\(location.lat)"
            + "&longitude=\(location.lon)&current=temperature_2m,weather_code"
            + "&temperature_unit=\(Self.temperatureUnit)"
        guard let meteo = await get(url, as: OpenMeteo.self) else { return }

        let condition = Self.condition(for: meteo.current.weather_code)
        let weather = Weather(temperature: Int(meteo.current.temperature_2m.rounded()),
                              unitSymbol: Self.unitSymbol,
                              symbolName: condition.symbol,
                              condition: condition.label,
                              city: location.city)
        guard weather != current else { return }
        current = weather
        log("weather: \(weather.temperature)°\(weather.unitSymbol) \(weather.condition)"
            + (weather.city.map { " · \($0)" } ?? ""))
    }

    // MARK: Networking

    private func get<T: Decodable>(_ urlString: String, as type: T.Type) async -> T? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                log("weather: HTTP \(status) from \(url.host ?? urlString)")
                return nil
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            log("weather: request failed (\(error.localizedDescription))")
            return nil
        }
    }

    private static var usesFahrenheit: Bool { Locale.current.measurementSystem == .us }
    private static var temperatureUnit: String { usesFahrenheit ? "fahrenheit" : "celsius" }
    private static var unitSymbol: String { usesFahrenheit ? "F" : "C" }

    /// WMO weather code → (SF Symbol, label).
    private static func condition(for code: Int) -> (symbol: String, label: String) {
        switch code {
        case 0:               return ("sun.max.fill", "Clear")
        case 1, 2:            return ("cloud.sun.fill", "Partly cloudy")
        case 3:               return ("cloud.fill", "Cloudy")
        case 45, 48:          return ("cloud.fog.fill", "Fog")
        case 51, 53, 55, 56, 57: return ("cloud.drizzle.fill", "Drizzle")
        case 61, 63, 65, 66, 67: return ("cloud.rain.fill", "Rain")
        case 71, 73, 75, 77:  return ("cloud.snow.fill", "Snow")
        case 80, 81, 82:      return ("cloud.heavyrain.fill", "Showers")
        case 85, 86:          return ("cloud.snow.fill", "Snow showers")
        case 95, 96, 99:      return ("cloud.bolt.fill", "Thunderstorm")
        default:              return ("cloud.fill", "—")
        }
    }

    private func log(_ message: String) {
        print("[dyNotch] \(message)")
        fflush(stdout)
    }

    // MARK: Decoded responses

    private struct IPGeo: Decodable {
        let latitude: Double
        let longitude: Double
        let city: String?
    }

    private struct OpenMeteo: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
        }
        let current: Current
    }
}

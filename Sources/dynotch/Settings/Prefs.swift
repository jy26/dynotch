import Foundation

/// Temperature display preference (Milestone 6.1). `auto` follows the locale.
enum TemperatureUnit: String, CaseIterable, Identifiable {
    case auto, fahrenheit, celsius
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto:       return "Auto"
        case .fahrenheit: return "Fahrenheit"
        case .celsius:    return "Celsius"
        }
    }
}

/// Shared preferences store (Milestone 6.1). An **explicit** `UserDefaults` suite, not
/// `.standard`: this unbundled executable has no bundle ID, so `.standard` resolves to an
/// implicit process-name domain (the `ShelfModel` lesson). The suite gives a stable
/// `~/Library/Preferences/dyNotch.plist`. `SettingsView` binds via `@AppStorage(…, store:)`;
/// services read these keys and observe `UserDefaults.didChangeNotification` to react live.
enum Prefs {
    static let suite = UserDefaults(suiteName: "dyNotch") ?? .standard

    static let showLyrics = "showLyrics"
    static let showWeather = "showWeather"
    static let temperatureUnit = "temperatureUnit"

    /// Registers the intended defaults so a service's bare `suite.bool(forKey:)` reads the
    /// right value before the user ever opens Settings (unset `.bool` is `false`). Call once.
    static func registerDefaults() {
        suite.register(defaults: [
            showLyrics: true,
            showWeather: true,
            temperatureUnit: TemperatureUnit.auto.rawValue,
        ])
    }

    static var showsLyrics: Bool { suite.bool(forKey: showLyrics) }
    static var showsWeather: Bool { suite.bool(forKey: showWeather) }
    static var temperature: TemperatureUnit {
        TemperatureUnit(rawValue: suite.string(forKey: temperatureUnit) ?? "") ?? .auto
    }
}

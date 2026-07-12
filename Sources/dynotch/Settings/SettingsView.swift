import SwiftUI

/// Preferences UI (Milestone 6.1) — `@AppStorage`-backed toggles on the explicit
/// `Prefs.suite`. Services read the same keys and react via `didChangeNotification`.
struct SettingsView: View {
    @AppStorage(Prefs.showLyrics, store: Prefs.suite) private var showLyrics = true
    @AppStorage(Prefs.showWeather, store: Prefs.suite) private var showWeather = true
    @AppStorage(Prefs.temperatureUnit, store: Prefs.suite) private var temperatureUnit = TemperatureUnit.auto

    var body: some View {
        Form {
            Section {
                Toggle("Show lyrics", isOn: $showLyrics)
                Toggle("Show weather", isOn: $showWeather)
            } footer: {
                Text("Lyrics come from LRCLIB; weather uses your approximate (IP-based) "
                     + "location. Turn either off to make no such requests.")
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Section("Weather") {
                Picker("Temperature", selection: $temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .disabled(!showWeather)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 240)
    }
}

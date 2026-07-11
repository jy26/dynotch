import SwiftUI

/// Expanded activities surface (Milestone 5.3): battery + timer, side by side.
/// Framed to `ScreenGeometry.expandedSize` by `NotchView` and gated to the
/// `.activities` tab. Display-only — the timer is started via the temp status-menu
/// triggers for now; collapsed glanceable indicators arrive in 5.4.
struct ActivityView: View {
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var timer: TimerActivity

    var body: some View {
        HStack(spacing: 0) {
            batteryBlock.frame(maxWidth: .infinity)
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1, height: 58)
            timerBlock.frame(maxWidth: .infinity)
        }
        .padding(.top, 40)            // clears the hardware-notch strip + tab bar
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Battery

    @ViewBuilder private var batteryBlock: some View {
        if let state = battery.state {
            block(symbol: batterySymbol(state),
                  value: "\(Int((state.fraction * 100).rounded()))%",
                  caption: batteryCaption(state))
        } else {
            block(symbol: "battery.0", value: "—", caption: "No battery")
        }
    }

    private func batterySymbol(_ state: BatteryState) -> String {
        if state.isCharging { return "battery.100.bolt" }
        switch Int((state.fraction * 100).rounded()) {
        case 88...: return "battery.100"
        case 63...: return "battery.75"
        case 38...: return "battery.50"
        case 13...: return "battery.25"
        default:    return "battery.0"
        }
    }

    private func batteryCaption(_ state: BatteryState) -> String {
        if state.isCharged { return "Charged" }
        if state.isCharging {
            return state.timeRemaining.map { "Charging · \(clockText($0)) to full" } ?? "Charging"
        }
        if state.isPluggedIn { return "Plugged in" }
        return state.timeRemaining.map { "\(clockText($0)) left" } ?? "On battery"
    }

    // MARK: Timer

    @ViewBuilder private var timerBlock: some View {
        if let state = timer.state {
            block(symbol: state.isFinished ? "timer.circle.fill" : "timer",
                  value: countdownText(state.remaining),
                  caption: state.isFinished ? "Done" : "Running")
        } else {
            block(symbol: "timer", value: "—:—", caption: "No timer")
                .opacity(0.5)
        }
    }

    // MARK: Shared block

    private func block(symbol: String, value: String, caption: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 24))
                .foregroundStyle(.white)
            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
    }

    /// `H:MM` for a battery ETA (input in seconds).
    private func clockText(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
    }

    /// `M:SS` (or `H:MM:SS`) for a timer countdown.
    private func countdownText(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0
            ? "\(hours):\(String(format: "%02d:%02d", minutes, seconds))"
            : "\(minutes):\(String(format: "%02d", seconds))"
    }
}

import SwiftUI

/// Expanded activities surface: two side-by-side widget cards — a battery card and
/// a timer card you can drive in-notch (preset durations, a `+/−` fine adjust, and
/// a typeable duration field + Start when idle; the countdown + Cancel while
/// running). Framed to `ScreenGeometry.expandedSize` by `NotchView`, gated to the
/// `.activities` tab.
struct ActivityView: View {
    @EnvironmentObject private var state: NotchState
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var timer: TimerActivity

    /// Pending timer duration (seconds) the presets / stepper / text field edit.
    @State private var pendingSeconds = 300
    @State private var durationText = "5:00"
    @FocusState private var editing: Bool

    private static let presets = [1, 5, 10, 25]   // minutes

    var body: some View {
        HStack(spacing: 10) {
            widget { batteryCard }
            widget { timerCard }
        }
        .padding(.top, 40)            // clears the hardware-notch strip + tab bar
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // On the stable body, not the idle timer card — that card is torn down when
        // the timer starts, which would drop this and leave `isEditingTimer` stuck.
        .onChange(of: editing) { _, focused in
            state.isEditingTimer = focused
            if !focused { commit() }   // parse + normalize when focus leaves
        }
    }

    /// A card "widget" — a subtle rounded panel filling its share of the row.
    private func widget<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.06)))
    }

    // MARK: Battery card

    @ViewBuilder private var batteryCard: some View {
        if let state = battery.state {
            VStack(spacing: 3) {
                Image(systemName: batterySymbol(state)).font(.system(size: 26))
                Text("\(Int((state.fraction * 100).rounded()))%")
                    .font(.system(size: 24, weight: .semibold)).monospacedDigit()
                Text(batteryCaption(state))
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
        } else {
            VStack(spacing: 3) {
                Image(systemName: "battery.0").font(.system(size: 26))
                Text("No battery").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
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
            return state.timeRemaining.map { "Charging · \(clockText($0))" } ?? "Charging"
        }
        if state.isPluggedIn { return "Plugged in" }
        return state.timeRemaining.map { "\(clockText($0)) left" } ?? "On battery"
    }

    /// `H:MM` for a battery ETA (input in seconds).
    private func clockText(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
    }

    // MARK: Timer card

    @ViewBuilder private var timerCard: some View {
        if let state = timer.state {
            VStack(spacing: 6) {
                Text(state.clock)
                    .font(.system(size: 26, weight: .semibold)).monospacedDigit()
                Text(state.isFinished ? "Done" : "Running")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                pill("Cancel", prominent: false) { timer.cancel() }
            }
            .foregroundStyle(.white)
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 5) {
                    ForEach(Self.presets, id: \.self) { minutes in
                        pill("\(minutes)m", prominent: false) { setPending(minutes * 60) }
                    }
                }
                HStack(spacing: 6) {
                    stepButton("minus") { setPending(max(1, pendingSeconds - 60)) }
                    TextField("", text: $durationText)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 15, weight: .medium)).monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: 54)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(.white.opacity(editing ? 0.45 : 0.15), lineWidth: 1)
                                )
                        )
                        .focused($editing)
                        .onSubmit { commitAndStart() }
                    stepButton("plus") { setPending(pendingSeconds + 60) }
                    pill("Start", prominent: true) { commitAndStart() }
                }
            }
            .foregroundStyle(.white)
        }
    }

    // MARK: Duration editing

    private func setPending(_ seconds: Int) {
        pendingSeconds = seconds
        durationText = format(seconds)
    }

    private func commit() {
        if let seconds = parse(durationText) { pendingSeconds = max(1, seconds) }
        durationText = format(pendingSeconds)   // normalize the display either way
    }

    private func commitAndStart() {
        commit()
        editing = false
        state.isEditingTimer = false   // explicit — don't rely on onChange timing here
        timer.start(TimeInterval(pendingSeconds))
    }

    private func format(_ seconds: Int) -> String {
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60, secs = seconds % 60
        return hours > 0
            ? "\(hours):\(String(format: "%02d:%02d", minutes, secs))"
            : "\(minutes):\(String(format: "%02d", secs))"
    }

    /// Parses `H:MM:SS` / `M:SS`, a bare number (minutes), or a `90s` / `5m` / `1h`
    /// suffix. Returns nil on garbage (the display then snaps back to the last value).
    private func parse(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":").map { Int($0) }
            guard parts.allSatisfy({ $0 != nil }) else { return nil }
            let nums = parts.compactMap { $0 }
            switch nums.count {
            case 2: return nums[0] * 60 + nums[1]
            case 3: return nums[0] * 3600 + nums[1] * 60 + nums[2]
            default: return nil
            }
        }
        if let unit = trimmed.last, "smh".contains(unit), let value = Int(trimmed.dropLast()) {
            switch unit {
            case "s": return value
            case "h": return value * 3600
            default:  return value * 60   // "m"
            }
        }
        return Int(trimmed).map { $0 * 60 }   // bare number = minutes
    }

    // MARK: Buttons

    private func pill(_ title: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(prominent ? .white.opacity(0.9) : .white.opacity(0.12)))
                .foregroundStyle(prominent ? .black : .white)
        }
        .buttonStyle(.plain)
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 20, height: 20)
                .background(Circle().fill(.white.opacity(0.12)))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

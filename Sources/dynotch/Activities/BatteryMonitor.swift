import Combine
import Foundation
import IOKit.ps

/// The current power state of the built-in battery, derived from IOKit's
/// power-source snapshot. `nil` `timeRemaining` means macOS is still calculating it.
struct BatteryState: Equatable {
    var fraction: Double              // 0…1 (current / max capacity)
    var isCharging: Bool
    var isPluggedIn: Bool             // running on AC power
    var isCharged: Bool               // full and plugged in
    var timeRemaining: TimeInterval?  // to full when charging, else to empty
}

/// First live-activity data source (Milestone 5.1): watches the battery / charging
/// state via IOKit power-source notifications and publishes `BatteryState`.
///
/// `state` is read by `ActivityView`'s charging card (5.3 tab routing) and the
/// collapsed glanceable indicator (5.4).
@MainActor
final class BatteryMonitor: ObservableObject {
    /// Latest reading; `nil` when the machine has no internal battery (desktop).
    @Published private(set) var state: BatteryState?

    private var runLoopSource: CFRunLoopSource?
    private var started = false
    private var lastReported: ReportedSignature?

    /// Reads the current state once, then registers for power-source change
    /// notifications so `state` tracks plug/unplug and charge drift.
    func start() {
        refresh()
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            // Fires on the run loop it's added to (main), so we're main-isolated.
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.refresh() }
        }, context)?.takeRetainedValue() else {
            log("battery: failed to create power-source notification")
            return
        }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    func stop() {
        guard let source = runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = nil
    }

    /// Re-reads the snapshot; publishes + logs only when a *reported* field
    /// changes. Power notifications fire constantly and macOS re-estimates the ETA
    /// every time, so `timeRemaining` is excluded from the change test — it still
    /// rides along in `state`, refreshed whenever a reported field changes.
    private func refresh() {
        let next = readState()
        let signature = reportedSignature(of: next)
        guard !started || signature != lastReported else { return }
        started = true
        lastReported = signature
        state = next
        log(describe(next))
    }

    /// The fields worth reporting — deliberately not the ETA (see `refresh`).
    private struct ReportedSignature: Equatable {
        let percent: Int
        let isCharging: Bool
        let isPluggedIn: Bool
        let isCharged: Bool
    }

    private func reportedSignature(of state: BatteryState?) -> ReportedSignature? {
        state.map {
            ReportedSignature(percent: Int(($0.fraction * 100).rounded()),
                              isCharging: $0.isCharging,
                              isPluggedIn: $0.isPluggedIn,
                              isCharged: $0.isCharged)
        }
    }

    private func readState() -> BatteryState? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as NSArray
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)
                    .takeUnretainedValue() as? [String: Any],
                  let current = desc[kIOPSCurrentCapacityKey] as? Int,
                  let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int, maxCapacity > 0
            else { continue }
            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let isPluggedIn = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            // A time estimate only has meaning in one direction: to-full while
            // charging, to-empty only while discharging. Plugged-but-holding (e.g.
            // sitting at 99% on AC) has neither — so don't report a bogus "0:00".
            let minutes: Int
            if isCharging {
                minutes = desc[kIOPSTimeToFullChargeKey] as? Int ?? -1
            } else if !isPluggedIn {
                minutes = desc[kIOPSTimeToEmptyKey] as? Int ?? -1
            } else {
                minutes = -1
            }
            return BatteryState(
                fraction: Double(current) / Double(maxCapacity),
                isCharging: isCharging,
                isPluggedIn: isPluggedIn,
                isCharged: desc[kIOPSIsChargedKey] as? Bool ?? false,
                timeRemaining: minutes >= 0 ? TimeInterval(minutes * 60) : nil
            )
        }
        return nil
    }

    private func describe(_ state: BatteryState?) -> String {
        guard let state else { return "battery: no internal battery" }
        let percent = Int((state.fraction * 100).rounded())
        let power = state.isCharging ? "charging"
            : (state.isPluggedIn ? "plugged in (not charging)" : "on battery")
        var line = "battery: \(percent)%, \(power)"
        if state.isCharged {
            line += ", charged"
        } else if let remaining = state.timeRemaining {
            let hours = Int(remaining) / 3600
            let mins = (Int(remaining) % 3600) / 60
            line += ", \(hours):\(String(format: "%02d", mins)) to \(state.isCharging ? "full" : "empty")"
        }
        return line
    }

    private func log(_ message: String) {
        print("[dyNotch] \(message)")
        fflush(stdout)
    }
}

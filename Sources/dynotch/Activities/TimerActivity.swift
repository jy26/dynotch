import AppKit
import Combine
import Foundation

/// A countdown timer's current state. `remaining` counts down each tick; `isFinished`
/// latches true at zero and holds (00:00) until the timer is cancelled.
struct TimerState: Equatable {
    let duration: TimeInterval
    var remaining: TimeInterval
    var isFinished: Bool

    /// `M:SS` (or `H:MM:SS`) for the remaining time — the shared countdown label.
    var clock: String {
        let total = Int(remaining.rounded())
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0
            ? "\(hours):\(String(format: "%02d:%02d", minutes, seconds))"
            : "\(minutes):\(String(format: "%02d", seconds))"
    }
}

/// Second live-activity source (Milestone 5.2): a single countdown timer with
/// start / tick / finish. `remaining` is derived from a wall-clock `endDate` each
/// tick, so ticks are jitter-proof and survive sleep (on wake it reads the correct
/// value, or already-finished, rather than a paused-behind one).
///
/// `state` drives `ActivityView`'s timer card (5.3 tab routing) and the collapsed
/// glanceable indicator (5.4); `NSSound.beep()` fires on finish. Single timer:
/// `start` replaces a running one.
@MainActor
final class TimerActivity: ObservableObject {
    /// Current countdown; `nil` when idle.
    @Published private(set) var state: TimerState?

    private var ticker: Timer?
    private var endDate: Date?

    /// Starts (or restarts) a countdown of `duration` seconds.
    func start(_ duration: TimeInterval) {
        cancel()
        let end = Date(timeIntervalSinceNow: duration)
        endDate = end
        state = TimerState(duration: duration, remaining: duration, isFinished: false)
        log("timer: started \(format(duration))")
        let ticker = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // .common so it keeps ticking during run-loop tracking (an open menu, a
        // scroll) — a countdown shouldn't freeze mid-interaction; .default wouldn't.
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }

    /// Stops a running (or finished) timer and returns to idle.
    func cancel() {
        guard state != nil else { return }
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        state = nil
        log("timer: cancelled")
    }

    private func tick() {
        guard let endDate, var current = state else { return }
        let remaining = max(0, endDate.timeIntervalSinceNow)
        current.remaining = remaining
        state = current
        if remaining <= 0 {
            finish()
        } else {
            log("timer: \(format(remaining))")
        }
    }

    private func finish() {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        state?.remaining = 0
        state?.isFinished = true
        log("timer: finished")
        // A real user notification needs a bundle ID / signing (M6); a beep is the
        // MVP finish alert. The finished state holds until `cancel()`.
        NSSound.beep()
    }

    /// `M:SS`, or `H:MM:SS` for durations of an hour or more.
    private func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
            : "\(minutes):\(String(format: "%02d", seconds))"
    }

    private func log(_ message: String) {
        print("[dyNotch] \(message)")
        fflush(stdout)
    }

    deinit {
        ticker?.invalidate()
    }
}

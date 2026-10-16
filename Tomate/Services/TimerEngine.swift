import AppKit
import Foundation
import Observation
import SwiftData

/// Runs the active pomodoro: start, pause, skip, stop, and moving between phases.
///
/// Views read `session` (changes only on user actions and phase changes) and
/// `remaining` (changes once per second), so only what shows the clock redraws every second.
@MainActor
@Observable
final class TimerEngine {
    private(set) var session: ActiveSession?
    /// Seconds left in the current phase.
    private(set) var remaining = 0

    private let persistence: Persistence
    private let notifier: Notifier
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var activity: NSObjectProtocol?

    init(persistence: Persistence, notifier: Notifier) {
        self.persistence = persistence
        self.notifier = notifier

        // Pick up a session left running when the app was quit.
        guard let saved = ActiveSession.loadSaved() else { return }
        session = saved
        remaining = saved.remaining(at: .now)
        syncWithClock()
        if session != nil { applyChange() }
    }

    // MARK: State

    var isActive: Bool { session != nil }
    var isPaused: Bool { session?.isPaused ?? false }
    var phase: Phase? { session?.currentPhase }

    /// Share of the current phase still to go, from 1 down to 0.
    var remainingFraction: Double {
        guard let phase = session?.currentPhase, phase.seconds > 0 else { return 1 }
        return Double(remaining) / Double(phase.seconds)
    }

    // MARK: Commands

    func start(_ plan: SessionPlan, fromSchedule: Bool = false) {
        if session != nil { stop() }
        let new = ActiveSession(plan: plan, fromSchedule: fromSchedule)
        session = new
        remaining = new.remaining(at: .now)
        applyChange()
    }

    func togglePause() {
        if isPaused { resume() } else { pause() }
    }

    func pause() {
        guard var current = session, !current.isPaused else { return }
        current.pausedRemaining = max(1, current.remaining(at: .now))
        current.phaseEndsAt = nil
        session = current
        remaining = current.remaining(at: .now)
        applyChange()
    }

    func resume() {
        guard var current = session, current.isPaused else { return }
        let left = current.remaining(at: .now)
        current.phaseEndsAt = Date.now.addingTimeInterval(TimeInterval(left))
        current.pausedRemaining = nil
        session = current
        applyChange()
    }

    /// Ends the current phase now and starts the next one. Not available on the last phase:
    /// ending the session early is `stop()`.
    func skipPhase() {
        guard var current = session, !current.isLastPhase else { return }
        let now = Date.now
        if current.currentPhase.kind == .focus {
            current.focusedSeconds += current.currentPhase.seconds - current.remaining(at: now)
        }
        current.phaseIndex += 1
        current.pausedRemaining = nil
        current.phaseEndsAt = now.addingTimeInterval(TimeInterval(current.currentPhase.seconds))
        session = current
        remaining = current.remaining(at: now)
        applyChange()
    }

    /// Ends the session early. The study time so far goes to the history.
    func stop() {
        guard var current = session else { return }
        let now = Date.now
        if current.currentPhase.kind == .focus {
            current.focusedSeconds += current.currentPhase.seconds - current.remaining(at: now)
        }
        session = current
        notifier.cancelPhaseAlerts()
        finish(completed: false, at: now)
    }

    // MARK: Clock

    /// Moves past every phase whose end time has already gone by and refreshes `remaining`.
    private func syncWithClock(now: Date = .now) {
        guard var current = session else { return }
        guard var end = current.phaseEndsAt, end <= now else {
            let left = current.remaining(at: now)
            if left != remaining { remaining = left }
            return
        }

        while end <= now {
            if current.currentPhase.kind == .focus {
                current.focusedSeconds += current.currentPhase.seconds
            }
            if current.isLastPhase {
                session = current
                finish(completed: true, at: end)
                return
            }
            current.phaseIndex += 1
            end += TimeInterval(current.currentPhase.seconds)
            current.phaseEndsAt = end
        }

        session = current
        remaining = current.remaining(at: now)
        // Alerts for the coming phases were scheduled at start, so only the saved copy changes.
        ActiveSession.save(current)
        if notifier.isDenied { NSSound(named: "Glass")?.play() }
    }

    private func startTicking() {
        guard ticker == nil else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let delay = self?.delayUntilNextSecond() else { return }
                try? await Task.sleep(for: .seconds(delay))
                self?.syncWithClock()
            }
        }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    /// Wakes just after the displayed second changes, so the countdown never stutters.
    private func delayUntilNextSecond() -> Double {
        guard let end = session?.phaseEndsAt else { return 1 }
        let left = end.timeIntervalSinceNow
        return left - floor(left) + 0.02
    }

    // MARK: Side effects

    /// Persists the session and lines up alerts, ticking and App Nap with the new state.
    private func applyChange() {
        ActiveSession.save(session)
        if let session, !session.isPaused {
            notifier.schedulePhaseAlerts(for: session)
            startTicking()
            keepAwake(true)
        } else {
            notifier.cancelPhaseAlerts()
            stopTicking()
            keepAwake(false)
        }
    }

    /// Saves the session to the history and clears it. Pending alerts are left alone here:
    /// on a natural finish the last one is being delivered right now.
    private func finish(completed: Bool, at date: Date) {
        guard let current = session else { return }
        if completed || current.focusedSeconds >= 60 {
            persistence.context.insert(FocusRecord(session: current, endedAt: date, completed: completed))
            persistence.save()
        }
        session = nil
        remaining = 0
        ActiveSession.save(nil)
        stopTicking()
        keepAwake(false)
    }

    /// Stops App Nap from throttling the countdown while a session runs.
    /// Idle system sleep is still allowed; dates keep the time right after waking.
    private func keepAwake(_ awake: Bool) {
        if awake, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
                                                             reason: "Pomodoro en marcha")
        } else if !awake, let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }
}

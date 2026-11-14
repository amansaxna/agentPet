// Sources/AgentPetCore/FocusClock.swift
import Foundation

/// Active state of a focus clock (timer or stopwatch).
public enum FocusClockState: String, Codable, CaseIterable, Sendable {
    case idle
    case running
    case paused
    case completed
}

/// Active tool mode in the focus suite.
public enum FocusMode: String, Codable, CaseIterable, Sendable {
    case pomodoro
    case timer
    case stopwatch

    public var displayName: String {
        switch self {
        case .pomodoro: return "Pomodoro"
        case .timer: return "Timer"
        case .stopwatch: return "Stopwatch"
        }
    }

    public var icon: String {
        switch self {
        case .pomodoro: return "brain.head.profile"
        case .timer: return "timer"
        case .stopwatch: return "stopwatch"
        }
    }
}

/// State snapshot for a countdown timer.
public struct CountdownTimerState: Codable, Equatable, Sendable {
    public var state: FocusClockState
    public var targetSeconds: TimeInterval
    public var secondsRemaining: TimeInterval
    public var activeSubject: String
    public var lastTick: Date?

    public init(
        state: FocusClockState = .idle,
        targetSeconds: TimeInterval = 15 * 60,
        secondsRemaining: TimeInterval = 15 * 60,
        activeSubject: String = "Focus Session",
        lastTick: Date? = nil
    ) {
        self.state = state
        self.targetSeconds = targetSeconds
        self.secondsRemaining = secondsRemaining
        self.activeSubject = activeSubject
        self.lastTick = lastTick
    }

    public var progress: Double {
        guard targetSeconds > 0 else { return 0 }
        return max(0, min(1, (targetSeconds - secondsRemaining) / targetSeconds))
    }

    public var formattedRemaining: String {
        let total = max(0, Int(secondsRemaining))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}

/// State snapshot for a count-up stopwatch.
public struct StopwatchState: Codable, Equatable, Sendable {
    public var state: FocusClockState
    public var elapsedSeconds: TimeInterval
    public var activeSubject: String
    public var laps: [TimeInterval]
    public var lastTick: Date?

    public init(
        state: FocusClockState = .idle,
        elapsedSeconds: TimeInterval = 0,
        activeSubject: String = "Study Session",
        laps: [TimeInterval] = [],
        lastTick: Date? = nil
    ) {
        self.state = state
        self.elapsedSeconds = elapsedSeconds
        self.activeSubject = activeSubject
        self.laps = laps
        self.lastTick = lastTick
    }

    public var formattedElapsed: String {
        let total = max(0, Int(elapsedSeconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

/// Deterministic Countdown Timer Engine.
public final class CountdownTimerEngine: @unchecked Sendable {
    public private(set) var state: CountdownTimerState

    public init(state: CountdownTimerState = CountdownTimerState()) {
        self.state = state
    }

    public func start(duration: TimeInterval, subject: String = "Focus Session", now: Date) {
        state.targetSeconds = max(1, duration)
        state.secondsRemaining = state.targetSeconds
        state.activeSubject = subject
        state.state = .running
        state.lastTick = now
    }

    public func pause(now: Date) {
        guard state.state == .running else { return }
        _ = tick(now: now)
        state.state = .paused
        state.lastTick = nil
    }

    public func resume(now: Date) {
        guard state.state == .paused else { return }
        state.state = .running
        state.lastTick = now
    }

    public func addMinutes(_ minutes: Int) {
        let added = TimeInterval(minutes * 60)
        state.targetSeconds += added
        state.secondsRemaining += added
    }

    public func reset() {
        state.state = .idle
        state.secondsRemaining = state.targetSeconds
        state.lastTick = nil
    }

    /// Ticks timer and returns true if timer just completed.
    public func tick(now: Date) -> Bool {
        guard state.state == .running else { return false }
        let delta: TimeInterval
        if let last = state.lastTick {
            let raw = now.timeIntervalSince(last)
            delta = (raw > 300) ? 1.0 : max(0, raw)
        } else {
            delta = 0
        }
        state.lastTick = now
        state.secondsRemaining = max(0, state.secondsRemaining - delta)

        if state.secondsRemaining <= 0 {
            state.state = .completed
            return true
        }
        return false
    }
}

/// Deterministic Stopwatch Engine.
public final class StopwatchEngine: @unchecked Sendable {
    public private(set) var state: StopwatchState

    public init(state: StopwatchState = StopwatchState()) {
        self.state = state
    }

    public func start(subject: String = "Study Session", now: Date) {
        state.activeSubject = subject
        state.state = .running
        state.lastTick = now
    }

    public func pause(now: Date) {
        guard state.state == .running else { return }
        tick(now: now)
        state.state = .paused
        state.lastTick = nil
    }

    public func resume(now: Date) {
        guard state.state == .paused else { return }
        state.state = .running
        state.lastTick = now
    }

    public func lap(now: Date) {
        guard state.state == .running else { return }
        tick(now: now)
        state.laps.insert(state.elapsedSeconds, at: 0)
    }

    public func reset() {
        state.state = .idle
        state.elapsedSeconds = 0
        state.laps = []
        state.lastTick = nil
    }

    public func tick(now: Date) {
        guard state.state == .running else { return }
        let delta: TimeInterval
        if let last = state.lastTick {
            let raw = now.timeIntervalSince(last)
            delta = (raw > 300) ? 1.0 : max(0, raw)
        } else {
            delta = 0
        }
        state.lastTick = now
        state.elapsedSeconds += delta
    }
}

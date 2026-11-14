// Sources/AgentPetCore/PomodoroClock.swift
import Foundation

/// Active phase of the Pomodoro cycle.
public enum PomodoroPhase: String, Codable, CaseIterable, Sendable {
    case idle
    case focus
    case shortBreak
    case longBreak

    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    public var isBreak: Bool {
        self == .shortBreak || self == .longBreak
    }
}

/// User-configurable parameters for Pomodoro intervals and auto-transitions.
public struct PomodoroConfig: Codable, Equatable, Sendable {
    public var focusMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int
    public var cyclesBeforeLongBreak: Int
    public var autoStartBreak: Bool
    public var autoStartFocus: Bool
    public var soundEnabled: Bool
    public var defaultSubjectTag: String

    public init(
        focusMinutes: Int = 25,
        shortBreakMinutes: Int = 5,
        longBreakMinutes: Int = 15,
        cyclesBeforeLongBreak: Int = 4,
        autoStartBreak: Bool = false,
        autoStartFocus: Bool = false,
        soundEnabled: Bool = true,
        defaultSubjectTag: String = "GATE Exam"
    ) {
        self.focusMinutes = max(1, focusMinutes)
        self.shortBreakMinutes = max(1, shortBreakMinutes)
        self.longBreakMinutes = max(1, longBreakMinutes)
        self.cyclesBeforeLongBreak = max(1, cyclesBeforeLongBreak)
        self.autoStartBreak = autoStartBreak
        self.autoStartFocus = autoStartFocus
        self.soundEnabled = soundEnabled
        self.defaultSubjectTag = defaultSubjectTag
    }
}

/// Runtime snapshot of the Pomodoro timer.
public struct PomodoroState: Codable, Equatable, Sendable {
    public var phase: PomodoroPhase
    public var currentCycle: Int
    public var secondsRemaining: TimeInterval
    public var totalSeconds: TimeInterval
    public var activeSubject: String
    public var isPaused: Bool
    public var completedCyclesToday: Int
    public var dayKey: String
    public var lastTick: Date?

    public init(
        phase: PomodoroPhase = .idle,
        currentCycle: Int = 1,
        secondsRemaining: TimeInterval = 25 * 60,
        totalSeconds: TimeInterval = 25 * 60,
        activeSubject: String = "GATE Exam",
        isPaused: Bool = false,
        completedCyclesToday: Int = 0,
        dayKey: String = "",
        lastTick: Date? = nil
    ) {
        self.phase = phase
        self.currentCycle = currentCycle
        self.secondsRemaining = secondsRemaining
        self.totalSeconds = totalSeconds
        self.activeSubject = activeSubject
        self.isPaused = isPaused
        self.completedCyclesToday = completedCyclesToday
        self.dayKey = dayKey
        self.lastTick = lastTick
    }

    /// Progress through the active phase (0.0 to 1.0).
    public var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return max(0, min(1, (totalSeconds - secondsRemaining) / totalSeconds))
    }

    /// Formatted remaining time MM:SS.
    public var formattedRemaining: String {
        let remaining = max(0, Int(secondsRemaining))
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// Events emitted by the deterministic `PomodoroClock`.
public enum PomodoroEvent: Equatable, Sendable {
    case none
    case tick
    case phaseChanged(from: PomodoroPhase, to: PomodoroPhase)
    case focusCompleted(subject: String, duration: TimeInterval)
    case breakCompleted(phase: PomodoroPhase)
}

/// Pure deterministic Pomodoro clock. Accepts explicit `now` timestamps.
public final class PomodoroClock: @unchecked Sendable {
    public var config: PomodoroConfig
    public private(set) var state: PomodoroState

    public init(config: PomodoroConfig = PomodoroConfig(), state: PomodoroState? = nil) {
        self.config = config
        self.state = state ?? PomodoroState(
            secondsRemaining: TimeInterval(config.focusMinutes * 60),
            totalSeconds: TimeInterval(config.focusMinutes * 60),
            activeSubject: config.defaultSubjectTag
        )
    }

    /// Resets timer back to idle state with initial focus duration.
    public func reset() {
        let duration = TimeInterval(config.focusMinutes * 60)
        state.phase = .idle
        state.secondsRemaining = duration
        state.totalSeconds = duration
        state.isPaused = false
        state.lastTick = nil
    }

    /// Starts or restarts a focus session with an optional subject tag.
    @discardableResult
    public func startFocus(subject: String? = nil, now: Date = Date()) -> PomodoroEvent {
        rollDayIfNeeded(now: now)
        let oldPhase = state.phase
        let duration = TimeInterval(config.focusMinutes * 60)
        state.phase = .focus
        state.totalSeconds = duration
        state.secondsRemaining = duration
        state.activeSubject = (subject?.isEmpty == false) ? subject! : config.defaultSubjectTag
        state.isPaused = false
        state.lastTick = now
        return .phaseChanged(from: oldPhase, to: .focus)
    }

    /// Directly starts a short or long break.
    @discardableResult
    public func startBreak(isLong: Bool = false, now: Date = Date()) -> PomodoroEvent {
        rollDayIfNeeded(now: now)
        let oldPhase = state.phase
        let nextPhase: PomodoroPhase = isLong ? .longBreak : .shortBreak
        let breakMinutes = isLong ? config.longBreakMinutes : config.shortBreakMinutes
        let breakSecs = TimeInterval(breakMinutes * 60)
        state.phase = nextPhase
        state.totalSeconds = breakSecs
        state.secondsRemaining = breakSecs
        state.isPaused = false
        state.lastTick = now
        return .phaseChanged(from: oldPhase, to: nextPhase)
    }

    /// Pauses an active timer.
    public func pause(now: Date = Date()) {
        state.isPaused = true
        state.lastTick = now
    }

    /// Resumes a paused timer.
    public func resume(now: Date = Date()) {
        if state.phase == .idle {
            _ = startFocus(subject: state.activeSubject, now: now)
            return
        }
        state.isPaused = false
        state.lastTick = now
    }

    /// Skips the currently active phase.
    @discardableResult
    public func skipPhase(now: Date = Date()) -> PomodoroEvent {
        rollDayIfNeeded(now: now)
        let oldPhase = state.phase
        switch state.phase {
        case .idle:
            return startFocus(now: now)
        case .focus:
            let completedDuration = state.totalSeconds - state.secondsRemaining
            let isLong = (state.currentCycle % config.cyclesBeforeLongBreak == 0)
            let nextPhase: PomodoroPhase = isLong ? .longBreak : .shortBreak
            let breakMinutes = isLong ? config.longBreakMinutes : config.shortBreakMinutes
            let breakSecs = TimeInterval(breakMinutes * 60)
            state.phase = nextPhase
            state.totalSeconds = breakSecs
            state.secondsRemaining = breakSecs
            state.isPaused = !config.autoStartBreak
            state.lastTick = now
            return .focusCompleted(subject: state.activeSubject, duration: max(0, completedDuration))
        case .shortBreak, .longBreak:
            state.currentCycle += 1
            if config.autoStartFocus {
                let focusSecs = TimeInterval(config.focusMinutes * 60)
                state.phase = .focus
                state.totalSeconds = focusSecs
                state.secondsRemaining = focusSecs
                state.isPaused = false
                state.lastTick = now
            } else {
                let focusSecs = TimeInterval(config.focusMinutes * 60)
                state.phase = .idle
                state.totalSeconds = focusSecs
                state.secondsRemaining = focusSecs
                state.isPaused = false
                state.lastTick = nil
            }
            return .breakCompleted(phase: oldPhase)
        }
    }

    /// Advances the timer by `now - lastTick`. Returns event when phase finishes.
    @discardableResult
    public func tick(now: Date) -> PomodoroEvent {
        rollDayIfNeeded(now: now)
        guard state.phase != .idle, !state.isPaused else {
            state.lastTick = now
            return .none
        }

        let delta: TimeInterval
        if let last = state.lastTick {
            let rawDelta = now.timeIntervalSince(last)
            // Clamp long delta (e.g. system sleep) to avoid sudden negative jumps
            delta = (rawDelta > 300) ? 1.0 : max(0, rawDelta)
        } else {
            delta = 0
        }
        state.lastTick = now

        state.secondsRemaining = max(0, state.secondsRemaining - delta)

        if state.secondsRemaining <= 0 {
            let finishedPhase = state.phase
            switch finishedPhase {
            case .focus:
                state.completedCyclesToday += 1
                let isLong = (state.currentCycle % config.cyclesBeforeLongBreak == 0)
                let nextPhase: PomodoroPhase = isLong ? .longBreak : .shortBreak
                let breakMinutes = isLong ? config.longBreakMinutes : config.shortBreakMinutes
                let breakSecs = TimeInterval(breakMinutes * 60)
                state.phase = nextPhase
                state.totalSeconds = breakSecs
                state.secondsRemaining = breakSecs
                state.isPaused = !config.autoStartBreak
                return .focusCompleted(subject: state.activeSubject, duration: TimeInterval(config.focusMinutes * 60))

            case .shortBreak, .longBreak:
                state.currentCycle += 1
                if config.autoStartFocus {
                    let focusSecs = TimeInterval(config.focusMinutes * 60)
                    state.phase = .focus
                    state.totalSeconds = focusSecs
                    state.secondsRemaining = focusSecs
                    state.isPaused = false
                } else {
                    let focusSecs = TimeInterval(config.focusMinutes * 60)
                    state.phase = .idle
                    state.totalSeconds = focusSecs
                    state.secondsRemaining = focusSecs
                    state.isPaused = false
                }
                return .breakCompleted(phase: finishedPhase)

            case .idle:
                return .none
            }
        }

        return .tick
    }

    private func rollDayIfNeeded(now: Date) {
        let key = Self.dayKey(for: now)
        if state.dayKey.isEmpty {
            state.dayKey = key
        } else if state.dayKey != key {
            state.dayKey = key
            state.completedCyclesToday = 0
        }
    }

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let comp = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comp.year ?? 2026, comp.month ?? 1, comp.day ?? 1)
    }
}

/// Persistent store for Pomodoro configuration and state under `~/.agentpet/pomodoro.json`.
public final class PomodoroStore: @unchecked Sendable {
    public static let shared = PomodoroStore()

    public struct Snapshot: Codable, Sendable {
        public var config: PomodoroConfig
        public var state: PomodoroState

        public init(config: PomodoroConfig, state: PomodoroState) {
            self.config = config
            self.state = state
        }
    }

    public let fileURL: URL
    private let queue = DispatchQueue(label: "com.agentpet.PomodoroStore")

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.fileURL = home.appendingPathComponent(".agentpet/pomodoro.json")
        }
        ensureDirectoryExists()
    }

    private func ensureDirectoryExists() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    public func load() -> Snapshot {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let snapshot = try? Self.decoder.decode(Snapshot.self, from: data) else {
                return Snapshot(config: PomodoroConfig(), state: PomodoroState())
            }
            return snapshot
        }
    }

    public func save(config: PomodoroConfig, state: PomodoroState) {
        queue.sync {
            let snapshot = Snapshot(config: config, state: state)
            guard let data = try? Self.encoder.encode(snapshot) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

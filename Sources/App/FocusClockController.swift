// Sources/App/FocusClockController.swift
import Foundation
import AppKit
import AgentPetCore

/// Drives the countdown Timer and count-up Stopwatch, awarding focus XP to PetCare,
/// logging sessions to WorkTracker, and coordinating alerts/notifications.
@MainActor
public final class FocusClockController: ObservableObject {
    public static let shared = FocusClockController()

    @Published public private(set) var timerState: CountdownTimerState
    @Published public private(set) var stopwatchState: StopwatchState
    @Published public var activeMode: FocusMode = .pomodoro

    private let timerEngine: CountdownTimerEngine
    private let stopwatchEngine: StopwatchEngine
    private var clockTimer: Timer?

    public var isTimerActive: Bool {
        timerState.state == .running || timerState.state == .paused
    }

    public var isStopwatchActive: Bool {
        stopwatchState.state == .running || stopwatchState.state == .paused
    }

    public var isAnyActive: Bool {
        isTimerActive || isStopwatchActive
    }

    private init() {
        let tEngine = CountdownTimerEngine()
        let sEngine = StopwatchEngine()
        self.timerEngine = tEngine
        self.stopwatchEngine = sEngine
        self.timerState = tEngine.state
        self.stopwatchState = sEngine.state
    }

    // MARK: - Countdown Timer Actions

    public func startTimer(minutes: Int = 15, subject: String? = nil) {
        let resolvedSubject = subject ?? TargetGoalController.shared.primaryGoal?.title ?? "Focus Timer"
        let duration = TimeInterval(max(1, minutes) * 60)
        timerEngine.start(duration: duration, subject: resolvedSubject, now: Date())
        timerState = timerEngine.state
        syncHeartbeat()

        NSSound(named: "Glass")?.play()
        PetController.shared.flashReactiveLine("Timer started: \(minutes)m (\(resolvedSubject)) ⏱")
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func pauseTimer() {
        timerEngine.pause(now: Date())
        timerState = timerEngine.state
        syncHeartbeat()
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func resumeTimer() {
        timerEngine.resume(now: Date())
        timerState = timerEngine.state
        syncHeartbeat()
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func addTimerMinutes(_ minutes: Int) {
        timerEngine.addMinutes(minutes)
        timerState = timerEngine.state
        PetController.shared.flashReactiveLine("+\(minutes)m added to timer ⏱")
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func stopTimer() {
        let elapsed = max(0, Int(timerState.targetSeconds - timerState.secondsRemaining))
        if elapsed >= 30 {
            PetCareController.shared.recordFocus(seconds: elapsed)
            let now = Date()
            WorkTrackerController.shared.logCompletedSegment(
                source: .pomodoro,
                category: timerState.activeSubject,
                startedAt: now.addingTimeInterval(-Double(elapsed)),
                endedAt: now,
                kind: .focus,
                note: "Countdown Timer (Partial)"
            )
        }
        timerEngine.reset()
        timerState = timerEngine.state
        syncHeartbeat()
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func resetTimer() {
        timerEngine.reset()
        timerState = timerEngine.state
        syncHeartbeat()
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    // MARK: - Stopwatch Actions

    public func startStopwatch(subject: String? = nil) {
        let resolvedSubject = subject ?? TargetGoalController.shared.primaryGoal?.title ?? "Stopwatch Session"
        stopwatchEngine.start(subject: resolvedSubject, now: Date())
        stopwatchState = stopwatchEngine.state
        syncHeartbeat()

        NSSound(named: "Blow")?.play()
        PetController.shared.flashReactiveLine("Stopwatch running: \(resolvedSubject) ⏱")
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func pauseStopwatch() {
        stopwatchEngine.pause(now: Date())
        stopwatchState = stopwatchEngine.state
        syncHeartbeat()
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func resumeStopwatch() {
        stopwatchEngine.resume(now: Date())
        stopwatchState = stopwatchEngine.state
        syncHeartbeat()
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func lapStopwatch() {
        stopwatchEngine.lap(now: Date())
        stopwatchState = stopwatchEngine.state
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func stopStopwatch() {
        let elapsed = max(0, Int(stopwatchState.elapsedSeconds))
        if elapsed >= 10 {
            // Award Focus XP directly
            let gainedXP = PetCareController.shared.recordFocus(seconds: elapsed)
            let now = Date()
            WorkTrackerController.shared.logCompletedSegment(
                source: .manual,
                category: stopwatchState.activeSubject,
                startedAt: now.addingTimeInterval(-Double(elapsed)),
                endedAt: now,
                kind: .focus,
                note: "Stopwatch Focus Session"
            )
            PetController.shared.flashCelebrate(line: "Focus logged: \(PetCare.formattedFocusDuration(seconds: elapsed)) (+\(gainedXP) XP) 🎯")
        }
        stopwatchEngine.reset()
        stopwatchState = stopwatchEngine.state
        syncHeartbeat()
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func resetStopwatch() {
        stopwatchEngine.reset()
        stopwatchState = stopwatchEngine.state
        syncHeartbeat()
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    // MARK: - Background Heartbeat

    private func syncHeartbeat() {
        let shouldRun = (timerState.state == .running || stopwatchState.state == .running)
        if shouldRun && clockTimer == nil {
            let t = Timer(timeInterval: 1.0, repeats: true) { _ in
                Task { @MainActor [weak self] in
                    self?.tick()
                }
            }
            RunLoop.main.add(t, forMode: .common)
            self.clockTimer = t
        } else if !shouldRun && clockTimer != nil {
            clockTimer?.invalidate()
            clockTimer = nil
        }
    }

    private func tick() {
        let now = Date()

        // 1. Tick Countdown Timer
        if timerState.state == .running {
            let completed = timerEngine.tick(now: now)
            timerState = timerEngine.state
            if completed {
                handleTimerFinished()
            }
        }

        // 2. Tick Stopwatch
        if stopwatchState.state == .running {
            stopwatchEngine.tick(now: now)
            stopwatchState = stopwatchEngine.state
        }

        syncHeartbeat()
    }

    private func handleTimerFinished() {
        let duration = Int(timerState.targetSeconds)

        // 1. Award Focus XP + meal if duration >= 15m
        PetCareController.shared.recordFocus(seconds: duration)
        if duration >= 15 * 60 {
            PetCareController.shared.recordMeal()
        }

        // 2. Log to WorkTracker
        let now = Date()
        WorkTrackerController.shared.logCompletedSegment(
            source: .pomodoro,
            category: timerState.activeSubject,
            startedAt: now.addingTimeInterval(-Double(duration)),
            endedAt: now,
            kind: .focus,
            note: "Countdown Timer Complete"
        )

        // 3. Audio & Notification
        NSSound(named: "Hero")?.play()
        NotificationManager.shared.notify(
            title: "Timer Complete! ⏰",
            body: "Your \(timerState.activeSubject) session finished! Great focus."
        )
        PetController.shared.flashCelebrate(line: "Timer finished! +\(duration / 60) Focus XP 🌟")
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }
}

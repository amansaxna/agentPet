// Sources/App/PomodoroController.swift
import Foundation
import AppKit
import AgentPetCore

/// Drives the Pomodoro timer on macOS, updating menu bar UI, triggering
/// notifications, awarding pet care progress, and logging focus sessions into work tracker.
@MainActor
public final class PomodoroController: ObservableObject {
    public static let shared = PomodoroController()

    @Published public private(set) var state: PomodoroState
    @Published public var config: PomodoroConfig {
        didSet {
            clock.config = config
            store.save(config: config, state: state)
        }
    }

    private let clock: PomodoroClock
    private let store = PomodoroStore.shared
    private var timer: Timer?

    private init() {
        let snapshot = store.load()
        self.config = snapshot.config
        self.clock = PomodoroClock(config: snapshot.config, state: snapshot.state)
        self.state = clock.state
        if state.phase != .idle && !state.isPaused {
            startTimer()
        }
    }

    public func startFocus(subject: String? = nil) {
        FocusClockController.shared.activeMode = .pomodoro
        let resolvedSubject = subject ?? TargetGoalController.shared.primaryGoal?.title ?? config.defaultSubjectTag
        _ = clock.startFocus(subject: resolvedSubject, now: Date())
        state = clock.state
        store.save(config: config, state: state)
        startTimer()

        if config.soundEnabled {
            NSSound(named: "Glass")?.play()
        }
        PetController.shared.flashReactiveLine("Focus started: \(state.activeSubject) 🎯")
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
        VoiceController.shared.speakFocusPhase(phase: .focus)
    }

    public func startBreak(isLong: Bool = false) {
        FocusClockController.shared.activeMode = .pomodoro
        _ = clock.startBreak(isLong: isLong, now: Date())
        state = clock.state
        store.save(config: config, state: state)
        startTimer()

        if config.soundEnabled {
            NSSound(named: "Blow")?.play()
        }
        PetController.shared.flashReactiveLine("Break started: Relax ☕")
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
        VoiceController.shared.speakFocusPhase(phase: isLong ? .longBreak : .shortBreak)
    }

    public func stop() {
        if state.phase == .focus {
            let elapsed = max(0, Int(state.totalSeconds - state.secondsRemaining))
            if elapsed >= 30 {
                PetCareController.shared.recordFocus(seconds: elapsed)
                let now = Date()
                WorkTrackerController.shared.logCompletedSegment(
                    source: .pomodoro,
                    category: state.activeSubject,
                    startedAt: now.addingTimeInterval(-Double(elapsed)),
                    endedAt: now,
                    kind: .focus,
                    note: "Pomodoro Focus (Partial)"
                )
            }
        }
        reset()
    }

    public func pause() {
        clock.pause(now: Date())
        state = clock.state
        store.save(config: config, state: state)
        stopTimer()
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func resume() {
        FocusClockController.shared.activeMode = .pomodoro
        clock.resume(now: Date())
        state = clock.state
        store.save(config: config, state: state)
        startTimer()
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func skip() {
        let event = clock.skipPhase(now: Date())
        state = clock.state
        store.save(config: config, state: state)
        handleEvent(event)
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func reset() {
        clock.reset()
        state = clock.state
        store.save(config: config, state: state)
        stopTimer()
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func updateConfig(_ newConfig: PomodoroConfig) {
        self.config = newConfig
    }

    // MARK: - Private Timer & Events

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let event = clock.tick(now: Date())
        state = clock.state

        if state.phase == .idle || state.isPaused {
            stopTimer()
        }

        handleEvent(event)
        store.save(config: config, state: state)
    }

    private func handleEvent(_ event: PomodoroEvent) {
        switch event {
        case .focusCompleted(let subject, let duration):
            // 1. Log to WorkTracker
            let now = Date()
            let startedAt = now.addingTimeInterval(-duration)
            WorkTrackerController.shared.logCompletedSegment(
                source: .pomodoro,
                category: subject,
                startedAt: startedAt,
                endedAt: now,
                kind: .focus,
                note: "Pomodoro Focus Session"
            )

            // 2. Award PetCare Focus XP + Meal XP
            PetCareController.shared.recordFocus(seconds: Int(duration))
            PetCareController.shared.recordMeal()

            // 3. Notification & Sound
            if config.soundEnabled {
                NSSound(named: "Hero")?.play()
            }
            NotificationManager.shared.notify(
                title: "Focus Complete! 🎯",
                body: "Great job focusing on \(subject). Take a well-deserved break!"
            )
            PetController.shared.flashCelebrate(line: "Focus completed! +1 Meal 🌟")
            VoiceController.shared.speakFocusPhase(phase: .shortBreak)

        case .breakCompleted(let phase):
            if config.soundEnabled {
                NSSound(named: "Ping")?.play()
            }
            let label = (phase == .longBreak) ? "Long break" : "Short break"
            NotificationManager.shared.notify(
                title: "\(label) Finished 💪",
                body: "Ready to dive back into focus?"
            )
            PetController.shared.flashReactiveLine("Break over! Let's get to work 💪")
            VoiceController.shared.speakFocusPhase(phase: .focus)

        case .phaseChanged:
            break
        case .tick, .none:
            break
        }
    }
}

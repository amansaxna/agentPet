// Tests/AgentPetCoreTests/PomodoroClockTests.swift
import XCTest
@testable import AgentPetCore

final class PomodoroClockTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1700000000)

    func testInitialStateIsIdle() {
        let clock = PomodoroClock()
        XCTAssertEqual(clock.state.phase, .idle)
        XCTAssertEqual(clock.state.secondsRemaining, 25 * 60)
        XCTAssertEqual(clock.state.isPaused, false)
    }

    func testStartFocusSetsPhaseAndDuration() {
        let clock = PomodoroClock(config: PomodoroConfig(focusMinutes: 30, defaultSubjectTag: "GATE CS"))
        let event = clock.startFocus(subject: "Operating Systems", now: t0)
        XCTAssertEqual(event, .phaseChanged(from: .idle, to: .focus))
        XCTAssertEqual(clock.state.phase, .focus)
        XCTAssertEqual(clock.state.activeSubject, "Operating Systems")
        XCTAssertEqual(clock.state.secondsRemaining, 30 * 60)
        XCTAssertEqual(clock.state.totalSeconds, 30 * 60)
    }

    func testTickDecrementsRemainingSeconds() {
        let clock = PomodoroClock(config: PomodoroConfig(focusMinutes: 25))
        clock.startFocus(subject: "Algorithms", now: t0)
        let event = clock.tick(now: t0.addingTimeInterval(60))
        XCTAssertEqual(event, .tick)
        XCTAssertEqual(clock.state.secondsRemaining, 24 * 60)
        XCTAssertEqual(clock.state.progress, 60.0 / 1500.0, accuracy: 0.001)
    }

    func testFocusCompletesAndTransitionsToShortBreak() {
        let clock = PomodoroClock(config: PomodoroConfig(
            focusMinutes: 25,
            shortBreakMinutes: 5,
            cyclesBeforeLongBreak: 4,
            autoStartBreak: false
        ))
        clock.startFocus(subject: "GATE Maths", now: t0)
        let event = clock.tick(now: t0.addingTimeInterval(25 * 60))
        XCTAssertEqual(event, .focusCompleted(subject: "GATE Maths", duration: 25 * 60))
        XCTAssertEqual(clock.state.phase, .shortBreak)
        XCTAssertEqual(clock.state.secondsRemaining, 5 * 60)
        XCTAssertEqual(clock.state.completedCyclesToday, 1)
        XCTAssertTrue(clock.state.isPaused)
    }

    func testCyclesBeforeLongBreakTriggersLongBreak() {
        let clock = PomodoroClock(config: PomodoroConfig(
            focusMinutes: 20,
            shortBreakMinutes: 5,
            longBreakMinutes: 15,
            cyclesBeforeLongBreak: 2,
            autoStartBreak: true
        ))
        clock.startFocus(subject: "Cycle 1", now: t0)
        _ = clock.tick(now: t0.addingTimeInterval(20 * 60))
        XCTAssertEqual(clock.state.phase, .shortBreak) // cycle 1 -> short break

        // skip short break
        _ = clock.skipPhase(now: t0.addingTimeInterval(25 * 60))
        XCTAssertEqual(clock.state.currentCycle, 2)

        // focus cycle 2
        clock.startFocus(subject: "Cycle 2", now: t0.addingTimeInterval(25 * 60))
        let event = clock.tick(now: t0.addingTimeInterval(45 * 60))
        XCTAssertEqual(event, .focusCompleted(subject: "Cycle 2", duration: 20 * 60))
        XCTAssertEqual(clock.state.phase, .longBreak) // cycle 2 -> long break!
        XCTAssertEqual(clock.state.secondsRemaining, 15 * 60)
    }

    func testPauseAndResumePreservesRemainingTime() {
        let clock = PomodoroClock(config: PomodoroConfig(focusMinutes: 25))
        clock.startFocus(subject: "Test", now: t0)
        _ = clock.tick(now: t0.addingTimeInterval(300)) // 20m remaining
        XCTAssertEqual(clock.state.secondsRemaining, 20 * 60)

        clock.pause(now: t0.addingTimeInterval(300))
        XCTAssertTrue(clock.state.isPaused)

        // ticking while paused must do nothing
        let pausedEvent = clock.tick(now: t0.addingTimeInterval(600))
        XCTAssertEqual(pausedEvent, .none)
        XCTAssertEqual(clock.state.secondsRemaining, 20 * 60)

        clock.resume(now: t0.addingTimeInterval(600))
        XCTAssertFalse(clock.state.isPaused)
        _ = clock.tick(now: t0.addingTimeInterval(660))
        XCTAssertEqual(clock.state.secondsRemaining, 19 * 60)
    }

    func testSkipFocusTransitionsToBreakAndEmitsCompleted() {
        let clock = PomodoroClock(config: PomodoroConfig(focusMinutes: 25, shortBreakMinutes: 5))
        clock.startFocus(subject: "Skip Test", now: t0)
        _ = clock.tick(now: t0.addingTimeInterval(10 * 60))

        let event = clock.skipPhase(now: t0.addingTimeInterval(10 * 60))
        XCTAssertEqual(event, .focusCompleted(subject: "Skip Test", duration: 10 * 60))
        XCTAssertEqual(clock.state.phase, .shortBreak)
    }

    func testResetRestoresInitialState() {
        let clock = PomodoroClock(config: PomodoroConfig(focusMinutes: 25))
        clock.startFocus(subject: "Reset Test", now: t0)
        _ = clock.tick(now: t0.addingTimeInterval(300))
        clock.reset()

        XCTAssertEqual(clock.state.phase, .idle)
        XCTAssertEqual(clock.state.secondsRemaining, 25 * 60)
        XCTAssertFalse(clock.state.isPaused)
    }
}

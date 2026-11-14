// Tests/AgentPetCoreTests/TargetGoalEngineTests.swift
import XCTest
@testable import AgentPetCore

final class TargetGoalEngineTests: XCTestCase {
    private let cal = Calendar.current
    private let t0 = Date(timeIntervalSince1970: 1700000000)

    func testGoalDaysPassedAndDaysLeftMath() {
        let start = cal.date(byAdding: .day, value: -10, to: t0)!
        let target = cal.date(byAdding: .day, value: 50, to: t0)!

        let goal = TargetGoal(
            title: "GATE Top 100",
            category: .gateExam,
            isPrimary: true,
            startDate: start,
            targetDate: target
        )

        let metrics = TargetGoalEngine.metrics(for: goal, now: t0, calendar: cal)
        XCTAssertEqual(metrics.daysPassed, 10)
        XCTAssertEqual(metrics.daysLeft, 50)
        XCTAssertEqual(metrics.totalDays, 60)
        XCTAssertEqual(metrics.timelineProgress, 10.0 / 60.0, accuracy: 0.001)
        XCTAssertFalse(metrics.isDueToday)
        XCTAssertFalse(metrics.isOverdue)
        XCTAssertEqual(metrics.statusLabel, "50d left")
    }

    func testOverdueAndDueTodayCalculations() {
        let start = cal.date(byAdding: .day, value: -30, to: t0)!

        // Due today
        let dueTodayGoal = TargetGoal(title: "Today Exam", startDate: start, targetDate: t0)
        let m1 = TargetGoalEngine.metrics(for: dueTodayGoal, now: t0, calendar: cal)
        XCTAssertTrue(m1.isDueToday)
        XCTAssertFalse(m1.isOverdue)
        XCTAssertEqual(m1.statusLabel, "Target Day!")

        // Overdue by 5 days
        let past = cal.date(byAdding: .day, value: -5, to: t0)!
        let overdueGoal = TargetGoal(title: "Past Exam", startDate: start, targetDate: past)
        let m2 = TargetGoalEngine.metrics(for: overdueGoal, now: t0, calendar: cal)
        XCTAssertFalse(m2.isDueToday)
        XCTAssertTrue(m2.isOverdue)
        XCTAssertEqual(m2.daysLeft, -5)
        XCTAssertEqual(m2.statusLabel, "5d past")
    }

    func testMilestoneProgress() {
        let goal = TargetGoal(
            title: "Project Alpha",
            milestones: [
                GoalMilestone(title: "M1", completed: true),
                GoalMilestone(title: "M2", completed: true),
                GoalMilestone(title: "M3", completed: false),
                GoalMilestone(title: "M4", completed: false)
            ]
        )

        let metrics = TargetGoalEngine.metrics(for: goal, now: t0, calendar: cal)
        XCTAssertEqual(metrics.milestoneProgress, 0.5, accuracy: 0.001)
    }

    func testSinglePrimaryGoalEnforcement() {
        let g1 = TargetGoal(id: "g1", title: "Goal 1", isPrimary: true)
        let g2 = TargetGoal(id: "g2", title: "Goal 2", isPrimary: false)
        let engine = TargetGoalEngine(goals: [g1, g2])

        XCTAssertEqual(engine.primaryGoal?.id, "g1")

        engine.setPrimaryGoal(id: "g2")
        XCTAssertEqual(engine.primaryGoal?.id, "g2")
        XCTAssertFalse(engine.goals.first { $0.id == "g1" }?.isPrimary ?? true)
    }
}

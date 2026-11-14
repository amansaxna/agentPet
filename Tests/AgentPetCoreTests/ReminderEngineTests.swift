// Tests/AgentPetCoreTests/ReminderEngineTests.swift
import XCTest
@testable import AgentPetCore

final class ReminderEngineTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1700000000)

    func testDefaultRulesWaterAndTakeTime() {
        let engine = ReminderEngine()
        XCTAssertEqual(engine.rules.count, 2)
        XCTAssertTrue(engine.rules.contains { $0.id == ReminderEngine.defaultWaterRuleId })
        XCTAssertTrue(engine.rules.contains { $0.id == ReminderEngine.defaultTakeTimeRuleId })
    }

    func testIntervalReminderTriggersWhenElapsed() {
        let rule = ReminderRule(
            id: "water-test",
            title: "Drink Water",
            message: "Water",
            kind: .water,
            schedule: .intervalMinutes(minutes: 30, activeOnly: false)
        )
        let engine = ReminderEngine(rules: [rule])

        // First tick: anchors reference time to t0, returns none
        let firstDue = engine.tick(now: t0, isPresent: true)
        XCTAssertTrue(firstDue.isEmpty)

        // 15 mins later: not yet due
        let midwayDue = engine.tick(now: t0.addingTimeInterval(15 * 60), isPresent: true)
        XCTAssertTrue(midwayDue.isEmpty)

        // 30 mins later: DUE!
        let due = engine.tick(now: t0.addingTimeInterval(30 * 60), isPresent: true)
        XCTAssertEqual(due.count, 1)
        XCTAssertEqual(due.first?.ruleId, "water-test")
    }

    func testActiveOnlySuppressesWhenUserAway() {
        let rule = ReminderRule(
            id: "stretch-test",
            title: "Stretch",
            message: "Stretch",
            kind: .takeTime,
            schedule: .intervalMinutes(minutes: 60, activeOnly: true)
        )
        let engine = ReminderEngine(rules: [rule])

        _ = engine.tick(now: t0, isPresent: true)

        // 60 mins later, user is NOT present -> should not fire
        let awayDue = engine.tick(now: t0.addingTimeInterval(60 * 60), isPresent: false)
        XCTAssertTrue(awayDue.isEmpty)

        // User is present -> fires
        let presentDue = engine.tick(now: t0.addingTimeInterval(60 * 60), isPresent: true)
        XCTAssertEqual(presentDue.count, 1)
        XCTAssertEqual(presentDue.first?.ruleId, "stretch-test")
    }

    func testSnoozeSuppressesUntilTargetDate() {
        let rule = ReminderRule(
            id: "r1",
            title: "Task",
            message: "Prompt",
            kind: .custom,
            schedule: .intervalMinutes(minutes: 20, activeOnly: false)
        )
        let engine = ReminderEngine(rules: [rule])
        _ = engine.tick(now: t0, isPresent: true)

        // Fires at +20m
        let due = engine.tick(now: t0.addingTimeInterval(20 * 60), isPresent: true)
        XCTAssertEqual(due.count, 1)

        // Snooze 5m
        engine.snooze(ruleId: "r1", minutes: 5, now: t0.addingTimeInterval(20 * 60))

        // At +23m: snoozed, no due
        let check1 = engine.tick(now: t0.addingTimeInterval(23 * 60), isPresent: true)
        XCTAssertTrue(check1.isEmpty)

        // At +25m: snooze elapsed, DUE!
        let check2 = engine.tick(now: t0.addingTimeInterval(25 * 60), isPresent: true)
        XCTAssertEqual(check2.count, 1)
        XCTAssertEqual(check2.first?.ruleId, "r1")
    }

    func testCompleteIncrementsWaterCounterAndClearsSnooze() {
        let engine = ReminderEngine()
        XCTAssertEqual(engine.waterCupsToday(now: t0), 0)

        engine.complete(ruleId: ReminderEngine.defaultWaterRuleId, now: t0)
        XCTAssertEqual(engine.waterCupsToday(now: t0), 1)

        engine.complete(ruleId: ReminderEngine.defaultWaterRuleId, now: t0.addingTimeInterval(3600))
        XCTAssertEqual(engine.waterCupsToday(now: t0.addingTimeInterval(3600)), 2)
    }

    func testDailyScheduleTriggersAtScheduledTime() {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: t0)
        comps.hour = 14
        comps.minute = 0
        let dateAt14 = cal.date(from: comps)!

        let rule = ReminderRule(
            id: "daily-rev",
            title: "Daily Revision",
            message: "Review short notes",
            kind: .custom,
            schedule: .dailyTime(hour: 14, minute: 30)
        )
        let engine = ReminderEngine(rules: [rule])

        // At 14:00 (before 14:30) -> not due
        let beforeDue = engine.tick(now: dateAt14, isPresent: true, calendar: cal)
        XCTAssertTrue(beforeDue.isEmpty)

        // At 14:35 -> due!
        let atDue = engine.tick(now: dateAt14.addingTimeInterval(35 * 60), isPresent: true, calendar: cal)
        XCTAssertEqual(atDue.count, 1)

        // Complete it
        engine.complete(ruleId: "daily-rev", now: dateAt14.addingTimeInterval(35 * 60), calendar: cal)

        // At 15:00 same day -> already triggered today, not due again!
        let laterDue = engine.tick(now: dateAt14.addingTimeInterval(60 * 60), isPresent: true, calendar: cal)
        XCTAssertTrue(laterDue.isEmpty)
    }

    func testCustomRuleCRUD() {
        let engine = ReminderEngine(rules: [])
        let newRule = ReminderRule(
            id: "custom-1",
            title: "Flashcards",
            message: "Revise",
            kind: .custom,
            schedule: .intervalMinutes(minutes: 45, activeOnly: false)
        )
        engine.addRule(newRule)
        XCTAssertEqual(engine.rules.count, 1)

        var edited = newRule
        edited.title = "Math Flashcards"
        engine.updateRule(edited)
        XCTAssertEqual(engine.rules.first?.title, "Math Flashcards")

        engine.deleteRule(id: "custom-1")
        XCTAssertTrue(engine.rules.isEmpty)
    }
}

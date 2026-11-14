// Tests/AgentPetCoreTests/WorkTimeTrackerTests.swift
import XCTest
@testable import AgentPetCore

final class WorkTimeTrackerTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1700000000)

    func testMergeIntervalsNonOverlapping() {
        let i1 = (start: t0, end: t0.addingTimeInterval(1800)) // 30m
        let i2 = (start: t0.addingTimeInterval(3600), end: t0.addingTimeInterval(5400)) // 30m
        let merged = WorkTimeAnalyzer.mergeIntervals([i1, i2])
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(WorkTimeAnalyzer.mergedDuration(for: merged), 3600)
    }

    func testMergeIntervalsOverlappingMergesIntoSingleWindow() {
        // Pomodoro running from 0 to 1500 (25 min)
        let pomodoro = (start: t0, end: t0.addingTimeInterval(1500))
        // Claude agent session running from 600 to 1800 (overlap from 600 to 1500)
        let agent = (start: t0.addingTimeInterval(600), end: t0.addingTimeInterval(1800))

        let merged = WorkTimeAnalyzer.mergeIntervals([pomodoro, agent])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.start, t0)
        XCTAssertEqual(merged.first?.end, t0.addingTimeInterval(1800))
        // Total duration is 1800s (30m) instead of 3300s (no double counting!)
        XCTAssertEqual(WorkTimeAnalyzer.mergedDuration(for: [pomodoro, agent]), 1800)
    }

    func testMergeIntervalsContainedWindowDoesNotDoubleCount() {
        let outer = (start: t0, end: t0.addingTimeInterval(3600))
        let inner = (start: t0.addingTimeInterval(300), end: t0.addingTimeInterval(900))
        let merged = WorkTimeAnalyzer.mergeIntervals([outer, inner])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(WorkTimeAnalyzer.mergedDuration(for: merged), 3600)
    }

    func testWorkTimeAnalyzerCalculatesTotalsAndBreakdowns() {
        let seg1 = WorkSegment(
            source: .pomodoro,
            category: "GATE CS",
            startedAt: t0,
            endedAt: t0.addingTimeInterval(1500),
            kind: .focus
        )
        let seg2 = WorkSegment(
            source: .manual,
            category: "GATE CS",
            startedAt: t0.addingTimeInterval(1800),
            endedAt: t0.addingTimeInterval(3600),
            kind: .focus
        )
        let breakSeg = WorkSegment(
            source: .pomodoro,
            category: "Break",
            startedAt: t0.addingTimeInterval(1500),
            endedAt: t0.addingTimeInterval(1800),
            kind: .breakTime
        )

        let report = WorkTimeAnalyzer.analyze(
            segments: [seg1, seg2, breakSeg],
            period: .today,
            from: t0,
            to: t0.addingTimeInterval(7200),
            dailyTargetMinutes: 60
        )

        XCTAssertEqual(report.totalFocusSeconds, 3300) // 1500 + 1800
        XCTAssertEqual(report.totalBreakSeconds, 300)
        XCTAssertEqual(report.categoryBreakdown.first?.category, "GATE CS")
        XCTAssertEqual(report.categoryBreakdown.first?.duration, 3300)
        XCTAssertEqual(report.categoryBreakdown.first?.percentage, 100.0)
    }

    func testHourlyPeakDistributionBuckets() {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: t0)
        comps.hour = 10
        comps.minute = 0
        let start10 = cal.date(from: comps)!

        let seg = WorkSegment(
            source: .manual,
            category: "Maths",
            startedAt: start10,
            endedAt: start10.addingTimeInterval(3600), // 1 hour at 10:00
            kind: .focus
        )

        let report = WorkTimeAnalyzer.analyze(
            segments: [seg],
            period: .today,
            from: start10.addingTimeInterval(-3600),
            to: start10.addingTimeInterval(7200),
            dailyTargetMinutes: 60,
            calendar: cal
        )

        XCTAssertEqual(report.hourlyPeakDistribution[10], 60)
        XCTAssertEqual(report.peakHourIndex, 10)
    }
}

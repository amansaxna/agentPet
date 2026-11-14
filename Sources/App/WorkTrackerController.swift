// Sources/App/WorkTrackerController.swift
import Foundation
import AppKit
import AgentPetCore

/// Coordinates live manual work tracking, imports agent & pomodoro intervals,
/// and computes unified analytics reports with double-counting prevention.
@MainActor
public final class WorkTrackerController: ObservableObject {
    public static let shared = WorkTrackerController()

    @Published public private(set) var isWorkingManual: Bool = false
    @Published public private(set) var manualStartTime: Date? = nil
    @Published public private(set) var manualCategory: String = "GATE Exam"
    @Published public private(set) var todaySecondsWorked: TimeInterval = 0

    @Published public private(set) var todayReport: WorkAnalyticsReport? = nil
    @Published public private(set) var weekReport: WorkAnalyticsReport? = nil
    @Published public private(set) var monthReport: WorkAnalyticsReport? = nil

    private let store = WorkTimeStore.shared
    private var refreshTimer: Timer?

    private init() {
        refreshReports()
        startLiveRefreshTimer()
    }

    private func startLiveRefreshTimer() {
        let t = Timer(timeInterval: 60.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.refreshReports()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.refreshTimer = t
    }

    // MARK: - Manual Clock In / Out

    public func startManualWork(category: String? = nil) {
        let resolvedCategory = category ?? TargetGoalController.shared.primaryGoal?.title ?? "GATE Exam"
        self.manualCategory = resolvedCategory
        self.manualStartTime = Date()
        self.isWorkingManual = true
        PetController.shared.flashReactiveLine("Clocked in: \(resolvedCategory) ✍️")
    }

    public func stopManualWork() {
        guard isWorkingManual, let start = manualStartTime else { return }
        let now = Date()
        let segment = WorkSegment(
            source: .manual,
            category: manualCategory,
            startedAt: start,
            endedAt: now,
            kind: .focus,
            note: "Manual Study Session"
        )
        store.saveSegment(segment)

        self.isWorkingManual = false
        self.manualStartTime = nil

        let mins = Int(now.timeIntervalSince(start) / 60)
        PetController.shared.flashReactiveLine("Clocked out: \(mins)m logged! 📝")
        refreshReports()
    }

    public func toggleManualWork() {
        if isWorkingManual {
            stopManualWork()
        } else {
            startManualWork()
        }
    }

    // MARK: - Logging Segments

    public func logCompletedSegment(
        source: WorkSource,
        category: String,
        startedAt: Date,
        endedAt: Date,
        kind: WorkSegmentKind = .focus,
        note: String? = nil
    ) {
        let segment = WorkSegment(
            source: source,
            category: category,
            startedAt: startedAt,
            endedAt: endedAt,
            kind: kind,
            note: note
        )
        store.saveSegment(segment)
        refreshReports()
    }

    // MARK: - Analytics Refresh

    public func refreshReports() {
        let now = Date()
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        let endOfToday = cal.date(byAdding: .day, value: 1, to: startOfToday) ?? now

        let targetMinutes = Double(TargetGoalController.shared.primaryGoal?.dailyTargetMinutes ?? 240)

        // Today
        var todaySegments = store.segments(for: now, calendar: cal)
        if isWorkingManual, let start = manualStartTime {
            todaySegments.append(WorkSegment(source: .manual, category: manualCategory, startedAt: start, endedAt: now, kind: .focus))
        }
        let reportToday = WorkTimeAnalyzer.analyze(
            segments: todaySegments,
            period: .today,
            from: startOfToday,
            to: endOfToday,
            dailyTargetMinutes: targetMinutes,
            calendar: cal
        )
        self.todayReport = reportToday
        self.todaySecondsWorked = reportToday.totalFocusSeconds

        // Week (7 days)
        let startOfWeek = cal.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        var weekSegments = store.segments(from: startOfWeek, to: now, calendar: cal)
        if isWorkingManual, let start = manualStartTime {
            weekSegments.append(WorkSegment(source: .manual, category: manualCategory, startedAt: start, endedAt: now, kind: .focus))
        }
        self.weekReport = WorkTimeAnalyzer.analyze(
            segments: weekSegments,
            period: .week,
            from: startOfWeek,
            to: endOfToday,
            dailyTargetMinutes: targetMinutes,
            calendar: cal
        )

        // Month (30 days)
        let startOfMonth = cal.date(byAdding: .day, value: -29, to: startOfToday) ?? startOfToday
        var monthSegments = store.segments(from: startOfMonth, to: now, calendar: cal)
        if isWorkingManual, let start = manualStartTime {
            monthSegments.append(WorkSegment(source: .manual, category: manualCategory, startedAt: start, endedAt: now, kind: .focus))
        }
        self.monthReport = WorkTimeAnalyzer.analyze(
            segments: monthSegments,
            period: .month,
            from: startOfMonth,
            to: endOfToday,
            dailyTargetMinutes: targetMinutes,
            calendar: cal
        )
    }

    public var formattedTodayWorked: String {
        let total = Int(todaySecondsWorked)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m)m"
        }
    }
}

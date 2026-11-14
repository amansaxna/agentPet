// Sources/AgentPetCore/WorkTimeTracker.swift
import Foundation

/// The origin of a recorded work or study segment.
public enum WorkSource: String, Codable, CaseIterable, Sendable {
    case pomodoro
    case manual
    case agent
    case presence

    public var displayName: String {
        switch self {
        case .pomodoro: return "Pomodoro"
        case .manual: return "Manual Study"
        case .agent: return "AI Agent"
        case .presence: return "Active Screen"
        }
    }

    public var icon: String {
        switch self {
        case .pomodoro: return "timer"
        case .manual: return "pencil.and.outline"
        case .agent: return "cpu"
        case .presence: return "macbook"
        }
    }
}

/// Whether a segment represents active focus or a rest break.
public enum WorkSegmentKind: String, Codable, CaseIterable, Sendable {
    case focus
    case breakTime

    public var displayName: String {
        switch self {
        case .focus: return "Focus"
        case .breakTime: return "Break"
        }
    }
}

/// A contiguous slice of tracked work or rest.
public struct WorkSegment: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var source: WorkSource
    public var category: String
    public var startedAt: Date
    public var endedAt: Date
    public var kind: WorkSegmentKind
    public var note: String?

    public init(
        id: String = UUID().uuidString,
        source: WorkSource,
        category: String = "GATE Exam",
        startedAt: Date,
        endedAt: Date,
        kind: WorkSegmentKind = .focus,
        note: String? = nil
    ) {
        self.id = id
        self.source = source
        self.category = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "General" : category
        self.startedAt = startedAt
        self.endedAt = max(startedAt, endedAt)
        self.kind = kind
        self.note = note
    }

    public var duration: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt))
    }
}

/// Analysis period for reporting.
public enum WorkAnalysisPeriod: String, Codable, CaseIterable, Sendable {
    case today
    case week
    case month

    public var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "7 Days"
        case .month: return "30 Days"
        }
    }
}

/// Distribution of work for a specific category.
public struct CategoryStat: Identifiable, Equatable, Sendable {
    public var id: String { category }
    public var category: String
    public var duration: TimeInterval
    public var percentage: Double

    public init(category: String, duration: TimeInterval, percentage: Double) {
        self.category = category
        self.duration = duration
        self.percentage = percentage
    }

    public var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Daily work aggregate for charts.
public struct DailyWorkPoint: Identifiable, Equatable, Sendable {
    public var id: String { dateKey }
    public var dateKey: String
    public var minutes: Double
    public var targetMinutes: Double

    public init(dateKey: String, minutes: Double, targetMinutes: Double) {
        self.dateKey = dateKey
        self.minutes = minutes
        self.targetMinutes = targetMinutes
    }

    public var attainmentRatio: Double {
        guard targetMinutes > 0 else { return 0 }
        return minutes / targetMinutes
    }
}

/// Comprehensive analytics report for a given time window.
public struct WorkAnalyticsReport: Equatable, Sendable {
    public var period: WorkAnalysisPeriod
    public var totalFocusSeconds: TimeInterval
    public var totalBreakSeconds: TimeInterval
    public var netDuration: TimeInterval
    public var focusToBreakRatio: Double
    public var categoryBreakdown: [CategoryStat]
    public var sourceBreakdown: [WorkSource: TimeInterval]
    public var dailyPoints: [DailyWorkPoint]
    public var hourlyPeakDistribution: [Int] // 24 buckets (0...23) in minutes
    public var activeStreakDays: Int
    public var dailyTargetAttainmentPercent: Double

    public init(
        period: WorkAnalysisPeriod,
        totalFocusSeconds: TimeInterval,
        totalBreakSeconds: TimeInterval,
        netDuration: TimeInterval,
        focusToBreakRatio: Double,
        categoryBreakdown: [CategoryStat],
        sourceBreakdown: [WorkSource: TimeInterval],
        dailyPoints: [DailyWorkPoint],
        hourlyPeakDistribution: [Int],
        activeStreakDays: Int,
        dailyTargetAttainmentPercent: Double
    ) {
        self.period = period
        self.totalFocusSeconds = totalFocusSeconds
        self.totalBreakSeconds = totalBreakSeconds
        self.netDuration = netDuration
        self.focusToBreakRatio = focusToBreakRatio
        self.categoryBreakdown = categoryBreakdown
        self.sourceBreakdown = sourceBreakdown
        self.dailyPoints = dailyPoints
        self.hourlyPeakDistribution = hourlyPeakDistribution
        self.activeStreakDays = activeStreakDays
        self.dailyTargetAttainmentPercent = dailyTargetAttainmentPercent
    }

    public var formattedFocusDuration: String {
        let hours = Int(totalFocusSeconds) / 3600
        let minutes = (Int(totalFocusSeconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    public var peakHourIndex: Int {
        var maxIndex = 0
        var maxMinutes = 0
        for (i, mins) in hourlyPeakDistribution.enumerated() {
            if mins > maxMinutes {
                maxMinutes = mins
                maxIndex = i
            }
        }
        return maxIndex
    }
}

/// Pure deterministic analytics engine and interval merger.
public enum WorkTimeAnalyzer {

    /// Merges overlapping or consecutive time intervals to prevent double-counting.
    public static func mergeIntervals(_ intervals: [(start: Date, end: Date)]) -> [(start: Date, end: Date)] {
        let valid = intervals.filter { $0.end > $0.start }
        guard !valid.isEmpty else { return [] }

        let sorted = valid.sorted { $0.start < $1.start }
        var merged: [(start: Date, end: Date)] = []

        var current = sorted[0]
        for next in sorted.dropFirst() {
            if next.start <= current.end {
                current.end = max(current.end, next.end)
            } else {
                merged.append(current)
                current = next
            }
        }
        merged.append(current)
        return merged
    }

    /// Sums total seconds across merged intervals.
    public static func mergedDuration(for intervals: [(start: Date, end: Date)]) -> TimeInterval {
        let merged = mergeIntervals(intervals)
        return merged.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
    }

    /// Generates a complete `WorkAnalyticsReport` across `[from, to]`.
    public static func analyze(
        segments: [WorkSegment],
        period: WorkAnalysisPeriod,
        from: Date,
        to: Date,
        dailyTargetMinutes: Double = 240,
        calendar: Calendar = .current
    ) -> WorkAnalyticsReport {
        // Filter segments within range
        let relevant = segments.filter { seg in
            seg.endedAt >= from && seg.startedAt <= to
        }

        // Clamp segments to [from, to]
        let focusIntervals: [(start: Date, end: Date)] = relevant
            .filter { $0.kind == .focus }
            .map { seg in
                (start: max(from, seg.startedAt), end: min(to, seg.endedAt))
            }

        let totalFocusSeconds = mergedDuration(for: focusIntervals)

        let breakIntervals: [(start: Date, end: Date)] = relevant
            .filter { $0.kind == .breakTime }
            .map { seg in
                (start: max(from, seg.startedAt), end: min(to, seg.endedAt))
            }
        let totalBreakSeconds = mergedDuration(for: breakIntervals)

        let ratio = (totalBreakSeconds > 0) ? (totalFocusSeconds / totalBreakSeconds) : (totalFocusSeconds > 0 ? 10.0 : 0.0)

        // Category breakdown
        var categorySeconds: [String: TimeInterval] = [:]
        for seg in relevant where seg.kind == .focus {
            let clampedStart = max(from, seg.startedAt)
            let clampedEnd = min(to, seg.endedAt)
            let dur = max(0, clampedEnd.timeIntervalSince(clampedStart))
            categorySeconds[seg.category, default: 0] += dur
        }

        let totalCategorySecs = categorySeconds.values.reduce(0, +)
        let categoryStats: [CategoryStat] = categorySeconds
            .map { cat, dur in
                let pct = (totalCategorySecs > 0) ? (dur / totalCategorySecs * 100.0) : 0
                return CategoryStat(category: cat, duration: dur, percentage: pct)
            }
            .sorted { $0.duration > $1.duration }

        // Source breakdown
        var sourceSeconds: [WorkSource: TimeInterval] = [:]
        for seg in relevant where seg.kind == .focus {
            let clampedStart = max(from, seg.startedAt)
            let clampedEnd = min(to, seg.endedAt)
            let dur = max(0, clampedEnd.timeIntervalSince(clampedStart))
            sourceSeconds[seg.source, default: 0] += dur
        }

        // Daily points & streak calculation
        let startOfDay = calendar.startOfDay(for: from)
        var currentDay = startOfDay
        var dailyPoints: [DailyWorkPoint] = []
        var streak = 0
        var consecutiveActive = 0

        while currentDay <= to {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            let dayKey = Self.dayKey(for: currentDay, calendar: calendar)

            let dayIntervals: [(start: Date, end: Date)] = relevant
                .filter { $0.kind == .focus && $0.endedAt >= currentDay && $0.startedAt < nextDay }
                .map { (start: max(currentDay, $0.startedAt), end: min(nextDay, $0.endedAt)) }

            let daySeconds = mergedDuration(for: dayIntervals)
            let dayMinutes = daySeconds / 60.0
            dailyPoints.append(DailyWorkPoint(dateKey: dayKey, minutes: dayMinutes, targetMinutes: dailyTargetMinutes))

            if dayMinutes >= 15.0 {
                consecutiveActive += 1
                streak = consecutiveActive
            } else {
                consecutiveActive = 0
            }

            currentDay = nextDay
        }

        // Hourly peak distribution (0...23)
        var hourlyMins = Array(repeating: 0, count: 24)
        for seg in relevant where seg.kind == .focus {
            let segStart = max(from, seg.startedAt)
            let segEnd = min(to, seg.endedAt)
            guard segEnd > segStart else { continue }

            var cur = segStart
            while cur < segEnd {
                let hour = calendar.component(.hour, from: cur)
                guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: cur) ?? cur) else { break }
                let stepEnd = min(segEnd, nextHour)
                let durMins = Int(stepEnd.timeIntervalSince(cur) / 60.0)
                if hour >= 0 && hour < 24 {
                    hourlyMins[hour] += durMins
                }
                cur = stepEnd
            }
        }

        // Attainment percentage
        let totalTargetMinutes = dailyTargetMinutes * Double(max(1, dailyPoints.count))
        let totalActualMinutes = totalFocusSeconds / 60.0
        let attainmentPct = (totalTargetMinutes > 0) ? min(100.0, (totalActualMinutes / totalTargetMinutes) * 100.0) : 0.0

        return WorkAnalyticsReport(
            period: period,
            totalFocusSeconds: totalFocusSeconds,
            totalBreakSeconds: totalBreakSeconds,
            netDuration: totalFocusSeconds,
            focusToBreakRatio: ratio,
            categoryBreakdown: categoryStats,
            sourceBreakdown: sourceSeconds,
            dailyPoints: dailyPoints,
            hourlyPeakDistribution: hourlyMins,
            activeStreakDays: streak,
            dailyTargetAttainmentPercent: attainmentPct
        )
    }

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let comp = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comp.year ?? 2026, comp.month ?? 1, comp.day ?? 1)
    }
}

/// Stores daily work segments in `~/.agentpet/worktime/yyyy-MM-dd.json`.
public final class WorkTimeStore: @unchecked Sendable {
    public static let shared = WorkTimeStore()

    public let baseURL: URL
    private let queue = DispatchQueue(label: "com.agentpet.WorkTimeStore")

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

    public init(baseURL: URL? = nil) {
        if let baseURL {
            self.baseURL = baseURL
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.baseURL = home.appendingPathComponent(".agentpet/worktime", isDirectory: true)
        }
        ensureDirectoryExists()
    }

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    private func fileURL(for date: Date, calendar: Calendar = .current) -> URL {
        let key = WorkTimeAnalyzer.dayKey(for: date, calendar: calendar)
        return baseURL.appendingPathComponent("\(key).json")
    }

    public func saveSegment(_ segment: WorkSegment) {
        queue.sync {
            let url = fileURL(for: segment.startedAt)
            var existing = readRecords(from: url)
            existing.append(segment)
            guard let data = try? Self.encoder.encode(existing) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    public func segments(for date: Date, calendar: Calendar = .current) -> [WorkSegment] {
        queue.sync {
            let url = fileURL(for: date, calendar: calendar)
            return readRecords(from: url)
        }
    }

    public func segments(from: Date, to: Date, calendar: Calendar = .current) -> [WorkSegment] {
        queue.sync {
            var result: [WorkSegment] = []
            var current = calendar.startOfDay(for: from)
            let endDay = calendar.startOfDay(for: to)

            while current <= endDay {
                let url = fileURL(for: current, calendar: calendar)
                result.append(contentsOf: readRecords(from: url))
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
            return result
        }
    }

    private func readRecords(from url: URL) -> [WorkSegment] {
        guard let data = try? Data(contentsOf: url),
              let list = try? Self.decoder.decode([WorkSegment].self, from: data) else {
            return []
        }
        return list
    }
}

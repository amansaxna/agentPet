// Sources/AgentPetCore/TargetGoalEngine.swift
import Foundation

/// Categories for targets and long-term goals.
public enum GoalCategory: String, Codable, CaseIterable, Sendable {
    case gateExam
    case learning
    case career
    case project
    case health
    case personal

    public var displayName: String {
        switch self {
        case .gateExam: return "GATE Exam"
        case .learning: return "Learning"
        case .career: return "Career"
        case .project: return "Project"
        case .health: return "Health"
        case .personal: return "Personal"
        }
    }

    public var icon: String {
        switch self {
        case .gateExam: return "graduationcap.fill"
        case .learning: return "book.fill"
        case .career: return "briefcase.fill"
        case .project: return "hammer.fill"
        case .health: return "heart.fill"
        case .personal: return "person.fill"
        }
    }
}

/// A milestone or checkpoint towards achieving a goal.
public struct GoalMilestone: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var completed: Bool

    public init(id: String = UUID().uuidString, title: String, completed: Bool = false) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.completed = completed
    }
}

/// Target goal model with start date, target deadline, and daily workload target.
public struct TargetGoal: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var category: GoalCategory
    public var isPrimary: Bool
    public var startDate: Date
    public var targetDate: Date
    public var dailyTargetMinutes: Int
    public var milestones: [GoalMilestone]
    public var notes: String
    public var archived: Bool

    public init(
        id: String = UUID().uuidString,
        title: String,
        category: GoalCategory = .gateExam,
        isPrimary: Bool = false,
        startDate: Date = Date(),
        targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date(),
        dailyTargetMinutes: Int = 240,
        milestones: [GoalMilestone] = [],
        notes: String = "",
        archived: Bool = false
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.category = category
        self.isPrimary = isPrimary
        self.startDate = startDate
        self.targetDate = targetDate
        self.dailyTargetMinutes = max(15, dailyTargetMinutes)
        self.milestones = milestones
        self.notes = notes
        self.archived = archived
    }
}

/// Calendar and progress calculations derived from a goal.
public struct GoalMetrics: Equatable, Sendable {
    public var daysPassed: Int
    public var daysLeft: Int
    public var totalDays: Int
    public var timelineProgress: Double // 0.0 to 1.0
    public var milestoneProgress: Double // 0.0 to 1.0
    public var isDueToday: Bool
    public var isOverdue: Bool
    public var statusLabel: String
    public var elapsedLabel: String

    public init(
        daysPassed: Int,
        daysLeft: Int,
        totalDays: Int,
        timelineProgress: Double,
        milestoneProgress: Double,
        isDueToday: Bool,
        isOverdue: Bool,
        statusLabel: String,
        elapsedLabel: String
    ) {
        self.daysPassed = daysPassed
        self.daysLeft = daysLeft
        self.totalDays = totalDays
        self.timelineProgress = timelineProgress
        self.milestoneProgress = milestoneProgress
        self.isDueToday = isDueToday
        self.isOverdue = isOverdue
        self.statusLabel = statusLabel
        self.elapsedLabel = elapsedLabel
    }
}

/// Pure deterministic calculations and target goal manager.
public final class TargetGoalEngine: @unchecked Sendable {
    public private(set) var goals: [TargetGoal]

    public static func defaultGoals(now: Date = Date(), calendar: Calendar = .current) -> [TargetGoal] {
        let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let exam = calendar.date(byAdding: .day, value: 90, to: now) ?? now
        return [
            TargetGoal(
                id: "default-gate-target",
                title: "GATE CS 2027 — Top 100",
                category: .gateExam,
                isPrimary: true,
                startDate: start,
                targetDate: exam,
                dailyTargetMinutes: 240,
                milestones: [
                    GoalMilestone(title: "Complete Core CS Syllabus (OS, CN, DBMS, TOC, CD)", completed: true),
                    GoalMilestone(title: "15-Year PYQs Twice with Error Log", completed: false),
                    GoalMilestone(title: "Full-Length Mock Series (10 Tests >= 65 marks)", completed: false),
                    GoalMilestone(title: "Final Formula & Shortcut Notes Revision", completed: false)
                ],
                notes: "Focus on concept depth and numerical accuracy. Analyze every mock test thoroughly."
            )
        ]
    }

    public init(goals: [TargetGoal]? = nil) {
        self.goals = goals ?? Self.defaultGoals()
        ensureSinglePrimary()
    }

    /// Normalizes day differences between two dates using start of day.
    public static func calendarDays(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let components = calendar.dateComponents([.day], from: startDay, to: endDay)
        return components.day ?? 0
    }

    /// Computes deterministic metrics for a given goal relative to `now`.
    public static func metrics(for goal: TargetGoal, now: Date = Date(), calendar: Calendar = .current) -> GoalMetrics {
        let daysPassed = max(0, calendarDays(from: goal.startDate, to: now, calendar: calendar))
        let daysLeft = calendarDays(from: now, to: goal.targetDate, calendar: calendar)
        let totalDays = max(1, calendarDays(from: goal.startDate, to: goal.targetDate, calendar: calendar))

        let timelineRatio = max(0.0, min(1.0, Double(daysPassed) / Double(totalDays)))

        let completedMilestones = goal.milestones.filter { $0.completed }.count
        let milestoneRatio = goal.milestones.isEmpty ? 0.0 : (Double(completedMilestones) / Double(goal.milestones.count))

        let isDueToday = (daysLeft == 0)
        let isOverdue = (daysLeft < 0)

        let statusText: String
        if isDueToday {
            statusText = "Target Day!"
        } else if isOverdue {
            statusText = "\(abs(daysLeft))d past"
        } else {
            statusText = "\(daysLeft)d left"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        let startFormatted = formatter.string(from: goal.startDate)
        let elapsedText = "Day \(daysPassed + 1) · \(daysPassed)d passed from \(startFormatted)"

        return GoalMetrics(
            daysPassed: daysPassed,
            daysLeft: daysLeft,
            totalDays: totalDays,
            timelineProgress: timelineRatio,
            milestoneProgress: milestoneRatio,
            isDueToday: isDueToday,
            isOverdue: isOverdue,
            statusLabel: statusText,
            elapsedLabel: elapsedText
        )
    }

    public var primaryGoal: TargetGoal? {
        goals.first { $0.isPrimary && !$0.archived } ?? goals.first { !$0.archived }
    }

    public func setPrimaryGoal(id: String) {
        for i in 0..<goals.count {
            goals[i].isPrimary = (goals[i].id == id)
        }
    }

    public func addGoal(_ goal: TargetGoal) {
        if goal.isPrimary {
            for i in 0..<goals.count { goals[i].isPrimary = false }
        }
        goals.append(goal)
        ensureSinglePrimary()
    }

    public func updateGoal(_ goal: TargetGoal) {
        if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
            if goal.isPrimary {
                for i in 0..<goals.count { goals[i].isPrimary = false }
            }
            goals[idx] = goal
            ensureSinglePrimary()
        }
    }

    public func deleteGoal(id: String) {
        goals.removeAll(where: { $0.id == id })
        ensureSinglePrimary()
    }

    public func toggleMilestone(goalId: String, milestoneId: String) {
        guard let gIdx = goals.firstIndex(where: { $0.id == goalId }) else { return }
        if let mIdx = goals[gIdx].milestones.firstIndex(where: { $0.id == milestoneId }) {
            goals[gIdx].milestones[mIdx].completed.toggle()
        }
    }

    private func ensureSinglePrimary() {
        let active = goals.filter { !$0.archived }
        let primaryCount = active.filter { $0.isPrimary }.count
        if primaryCount == 0, let first = active.first {
            if let idx = goals.firstIndex(where: { $0.id == first.id }) {
                goals[idx].isPrimary = true
            }
        } else if primaryCount > 1 {
            var seen = false
            for i in 0..<goals.count where !goals[i].archived {
                if goals[i].isPrimary {
                    if seen {
                        goals[i].isPrimary = false
                    } else {
                        seen = true
                    }
                }
            }
        }
    }
}

/// Stores goals in `~/.agentpet/goals.json`.
public final class TargetGoalStore: @unchecked Sendable {
    public static let shared = TargetGoalStore()

    public let fileURL: URL
    private let queue = DispatchQueue(label: "com.agentpet.TargetGoalStore")

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
            self.fileURL = home.appendingPathComponent(".agentpet/goals.json")
        }
        ensureDirectoryExists()
    }

    private func ensureDirectoryExists() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    public func load() -> [TargetGoal] {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let list = try? Self.decoder.decode([TargetGoal].self, from: data) else {
                return TargetGoalEngine.defaultGoals()
            }
            return list
        }
    }

    public func save(goals: [TargetGoal]) {
        queue.sync {
            guard let data = try? Self.encoder.encode(goals) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

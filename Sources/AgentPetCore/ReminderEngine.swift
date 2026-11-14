// Sources/AgentPetCore/ReminderEngine.swift
import Foundation

/// Categories of reminders supported by the system.
public enum ReminderKind: String, Codable, CaseIterable, Sendable {
    case water
    case takeTime
    case custom

    public var displayName: String {
        switch self {
        case .water: return "Water"
        case .takeTime: return "Take Time"
        case .custom: return "Custom"
        }
    }

    public var defaultIcon: String {
        switch self {
        case .water: return "drop.fill"
        case .takeTime: return "figure.walk"
        case .custom: return "bell.fill"
        }
    }
}

/// Trigger schedule for a reminder rule.
public enum ReminderSchedule: Codable, Equatable, Sendable {
    case intervalMinutes(minutes: Int, activeOnly: Bool)
    case dailyTime(hour: Int, minute: Int)

    public var isInterval: Bool {
        if case .intervalMinutes = self { return true }
        return false
    }

    public var displayString: String {
        switch self {
        case .intervalMinutes(let m, let activeOnly):
            return activeOnly ? "Every \(m)m (active only)" : "Every \(m)m"
        case .dailyTime(let h, let m):
            return String(format: "Daily at %02d:%02d", h, m)
        }
    }
}

/// A configurable reminder rule.
public struct ReminderRule: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var message: String
    public var kind: ReminderKind
    public var schedule: ReminderSchedule
    public var enabled: Bool
    public var soundEnabled: Bool
    public var defaultSnoozeMinutes: Int
    public var icon: String

    public init(
        id: String = UUID().uuidString,
        title: String,
        message: String,
        kind: ReminderKind,
        schedule: ReminderSchedule,
        enabled: Bool = true,
        soundEnabled: Bool = true,
        defaultSnoozeMinutes: Int = 5,
        icon: String? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.kind = kind
        self.schedule = schedule
        self.enabled = enabled
        self.soundEnabled = soundEnabled
        self.defaultSnoozeMinutes = max(1, defaultSnoozeMinutes)
        self.icon = icon ?? kind.defaultIcon
    }
}

/// Ephemeral and per-day runtime state for a reminder rule.
public struct ReminderRuntimeState: Codable, Equatable, Sendable {
    public var ruleId: String
    public var snoozedUntil: Date?
    public var lastTriggeredAt: Date?
    public var lastCompletedAt: Date?
    public var completedCountToday: Int
    public var dayKey: String

    public init(
        ruleId: String,
        snoozedUntil: Date? = nil,
        lastTriggeredAt: Date? = nil,
        lastCompletedAt: Date? = nil,
        completedCountToday: Int = 0,
        dayKey: String = ""
    ) {
        self.ruleId = ruleId
        self.snoozedUntil = snoozedUntil
        self.lastTriggeredAt = lastTriggeredAt
        self.lastCompletedAt = lastCompletedAt
        self.completedCountToday = completedCountToday
        self.dayKey = dayKey
    }
}

/// A reminder that is currently firing or pending acknowledgement.
public struct DueReminder: Identifiable, Equatable, Sendable {
    public var id: String { ruleId }
    public var ruleId: String
    public var title: String
    public var message: String
    public var kind: ReminderKind
    public var dueAt: Date
    public var defaultSnoozeMinutes: Int
    public var soundEnabled: Bool
    public var icon: String

    public init(
        ruleId: String,
        title: String,
        message: String,
        kind: ReminderKind,
        dueAt: Date = Date(),
        defaultSnoozeMinutes: Int = 5,
        soundEnabled: Bool = true,
        icon: String = "bell.fill"
    ) {
        self.ruleId = ruleId
        self.title = title
        self.message = message
        self.kind = kind
        self.dueAt = dueAt
        self.defaultSnoozeMinutes = defaultSnoozeMinutes
        self.soundEnabled = soundEnabled
        self.icon = icon
    }
}

/// Pure deterministic reminder engine.
public final class ReminderEngine: @unchecked Sendable {
    public private(set) var rules: [ReminderRule]
    public private(set) var states: [String: ReminderRuntimeState]

    public static let defaultWaterRuleId = "built-in-water"
    public static let defaultTakeTimeRuleId = "built-in-take-time"

    public static func defaultRules() -> [ReminderRule] {
        [
            ReminderRule(
                id: defaultWaterRuleId,
                title: "Drink Water",
                message: "Stay hydrated! Drink a fresh glass of water 💧",
                kind: .water,
                schedule: .intervalMinutes(minutes: 45, activeOnly: false),
                enabled: true,
                soundEnabled: true,
                defaultSnoozeMinutes: 5,
                icon: "drop.fill"
            ),
            ReminderRule(
                id: defaultTakeTimeRuleId,
                title: "Take a Moment",
                message: "Step away from the screen, stretch, and relax your eyes 🧘",
                kind: .takeTime,
                schedule: .intervalMinutes(minutes: 75, activeOnly: true),
                enabled: true,
                soundEnabled: true,
                defaultSnoozeMinutes: 10,
                icon: "figure.walk"
            )
        ]
    }

    public init(rules: [ReminderRule]? = nil, states: [String: ReminderRuntimeState] = [:]) {
        self.rules = rules ?? Self.defaultRules()
        self.states = states
    }

    /// Evaluates all rules against current time and user presence.
    public func tick(now: Date, isPresent: Bool, calendar: Calendar = .current) -> [DueReminder] {
        let todayKey = Self.dayKey(for: now, calendar: calendar)
        rollDayIfNeeded(todayKey: todayKey)

        var dueList: [DueReminder] = []

        for rule in rules where rule.enabled {
            var state = states[rule.id] ?? ReminderRuntimeState(ruleId: rule.id, dayKey: todayKey)

            // Check if snoozed
            if let snoozed = state.snoozedUntil {
                if now >= snoozed {
                    dueList.append(makeDue(from: rule, dueAt: snoozed))
                }
                continue
            }

            switch rule.schedule {
            case .intervalMinutes(let minutes, let activeOnly):
                if activeOnly && !isPresent {
                    continue
                }
                let refDate = state.lastTriggeredAt ?? state.lastCompletedAt
                if let ref = refDate {
                    let interval = Double(minutes * 60)
                    if now.timeIntervalSince(ref) >= interval {
                        dueList.append(makeDue(from: rule, dueAt: now))
                    }
                } else {
                    // First tick initialization: anchor to now so it doesn't fire instantly
                    state.lastTriggeredAt = now
                    states[rule.id] = state
                }

            case .dailyTime(let targetHour, let targetMinute):
                let currentComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
                let currentHour = currentComps.hour ?? 0
                let currentMinute = currentComps.minute ?? 0

                let isPastTarget = (currentHour > targetHour) || (currentHour == targetHour && currentMinute >= targetMinute)
                if !isPastTarget {
                    continue
                }

                // Check if already fired or completed today
                let alreadyFiredToday: Bool
                if let last = state.lastTriggeredAt {
                    let lastComps = calendar.dateComponents([.year, .month, .day], from: last)
                    alreadyFiredToday = (lastComps.year == currentComps.year &&
                                         lastComps.month == currentComps.month &&
                                         lastComps.day == currentComps.day)
                } else {
                    alreadyFiredToday = false
                }

                if !alreadyFiredToday {
                    dueList.append(makeDue(from: rule, dueAt: now))
                }
            }
        }

        return dueList
    }

    private func makeDue(from rule: ReminderRule, dueAt: Date) -> DueReminder {
        DueReminder(
            ruleId: rule.id,
            title: rule.title,
            message: rule.message,
            kind: rule.kind,
            dueAt: dueAt,
            defaultSnoozeMinutes: rule.defaultSnoozeMinutes,
            soundEnabled: rule.soundEnabled,
            icon: rule.icon
        )
    }

    /// Postpones the reminder by `minutes`.
    @discardableResult
    public func snooze(ruleId: String, minutes: Int, now: Date = Date()) -> Bool {
        guard rules.contains(where: { $0.id == ruleId }) else { return false }
        var state = states[ruleId] ?? ReminderRuntimeState(ruleId: ruleId, dayKey: Self.dayKey(for: now))
        state.snoozedUntil = now.addingTimeInterval(TimeInterval(minutes * 60))
        states[ruleId] = state
        return true
    }

    /// Marks the reminder completed (e.g. drank water). Increments today's counter.
    @discardableResult
    public func complete(ruleId: String, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard rules.contains(where: { $0.id == ruleId }) else { return false }
        let todayKey = Self.dayKey(for: now, calendar: calendar)
        rollDayIfNeeded(todayKey: todayKey)

        var state = states[ruleId] ?? ReminderRuntimeState(ruleId: ruleId, dayKey: todayKey)
        state.snoozedUntil = nil
        state.lastTriggeredAt = now
        state.lastCompletedAt = now
        state.completedCountToday += 1
        states[ruleId] = state
        return true
    }

    /// Dismisses the reminder without counting it as completed.
    @discardableResult
    public func dismiss(ruleId: String, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard rules.contains(where: { $0.id == ruleId }) else { return false }
        let todayKey = Self.dayKey(for: now, calendar: calendar)
        rollDayIfNeeded(todayKey: todayKey)

        var state = states[ruleId] ?? ReminderRuntimeState(ruleId: ruleId, dayKey: todayKey)
        state.snoozedUntil = nil
        state.lastTriggeredAt = now
        states[ruleId] = state
        return true
    }

    // MARK: - Rule CRUD

    public func addRule(_ rule: ReminderRule) {
        rules.append(rule)
    }

    public func updateRule(_ rule: ReminderRule) {
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[idx] = rule
        }
    }

    public func deleteRule(id: String) {
        rules.removeAll(where: { $0.id == id })
        states.removeValue(forKey: id)
    }

    public func state(for ruleId: String) -> ReminderRuntimeState? {
        states[ruleId]
    }

    public func waterCupsToday(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let todayKey = Self.dayKey(for: now, calendar: calendar)
        rollDayIfNeeded(todayKey: todayKey)
        return states[Self.defaultWaterRuleId]?.completedCountToday ?? 0
    }

    private func rollDayIfNeeded(todayKey: String) {
        for (id, state) in states where state.dayKey != todayKey {
            var updated = state
            updated.dayKey = todayKey
            updated.completedCountToday = 0
            states[id] = updated
        }
    }

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let comp = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comp.year ?? 2026, comp.month ?? 1, comp.day ?? 1)
    }
}

/// Stores reminders rules and runtime states under `~/.agentpet/reminders.json`.
public final class ReminderStore: @unchecked Sendable {
    public static let shared = ReminderStore()

    public struct Snapshot: Codable, Sendable {
        public var rules: [ReminderRule]
        public var states: [String: ReminderRuntimeState]

        public init(rules: [ReminderRule], states: [String: ReminderRuntimeState]) {
            self.rules = rules
            self.states = states
        }
    }

    public let fileURL: URL
    private let queue = DispatchQueue(label: "com.agentpet.ReminderStore")

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
            self.fileURL = home.appendingPathComponent(".agentpet/reminders.json")
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
                return Snapshot(rules: ReminderEngine.defaultRules(), states: [:])
            }
            return snapshot
        }
    }

    public func save(rules: [ReminderRule], states: [String: ReminderRuntimeState]) {
        queue.sync {
            let snapshot = Snapshot(rules: rules, states: states)
            guard let data = try? Self.encoder.encode(snapshot) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

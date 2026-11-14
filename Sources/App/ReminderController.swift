// Sources/App/ReminderController.swift
import Foundation
import AppKit
import AgentPetCore

/// Drives the configurable reminder engine: checks schedule every 15s,
/// evaluates user presence, triggers notifications with snooze actions, and
/// exposes due reminders for popover banners.
@MainActor
public final class ReminderController: ObservableObject {
    public static let shared = ReminderController()

    @Published public private(set) var dueReminders: [DueReminder] = []
    @Published public private(set) var rules: [ReminderRule] = []
    @Published public private(set) var waterCupsToday: Int = 0

    private let engine: ReminderEngine
    private let store = ReminderStore.shared
    private var timer: Timer?

    private init() {
        let snapshot = store.load()
        self.rules = snapshot.rules
        self.engine = ReminderEngine(rules: snapshot.rules, states: snapshot.states)
        self.waterCupsToday = engine.waterCupsToday()
        start()
    }

    public func start() {
        timer?.invalidate()
        let t = Timer(timeInterval: 15.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    private func isPresent() -> Bool {
        let anyInput = CGEventType(rawValue: UInt32.max)!
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        if idle < 300 { return true }
        return AppDaemon.shared.sessions.contains { $0.state == .working || $0.state == .waiting }
    }

    public func tick() {
        let previouslyDueIds = Set(dueReminders.map { $0.ruleId })
        let due = engine.tick(now: Date(), isPresent: isPresent())
        self.dueReminders = due
        self.waterCupsToday = engine.waterCupsToday()
        PetController.shared.update(sessions: AppDaemon.shared.sessions)

        // Notify for newly due reminders
        for item in due where !previouslyDueIds.contains(item.ruleId) {
            NotificationManager.shared.notifyReminder(reminder: item)
            if item.soundEnabled {
                NSSound(named: "Tink")?.play()
            }
        }

        store.save(rules: engine.rules, states: engine.states)
    }

    public func snooze(ruleId: String, minutes: Int? = nil) {
        let rule = rules.first { $0.id == ruleId }
        let mins = minutes ?? rule?.defaultSnoozeMinutes ?? 5
        engine.snooze(ruleId: ruleId, minutes: mins, now: Date())
        dueReminders.removeAll { $0.ruleId == ruleId }
        store.save(rules: engine.rules, states: engine.states)
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func complete(ruleId: String) {
        engine.complete(ruleId: ruleId, now: Date())
        dueReminders.removeAll { $0.ruleId == ruleId }
        waterCupsToday = engine.waterCupsToday()
        store.save(rules: engine.rules, states: engine.states)
        PetController.shared.update(sessions: AppDaemon.shared.sessions)

        if ruleId == ReminderEngine.defaultWaterRuleId {
            PetController.shared.flashCelebrate(line: "Hydrated! 💧 Total: \(waterCupsToday) glasses today")
        } else {
            PetController.shared.flashCelebrate(line: "Reminder complete! ✅")
        }
    }

    public func dismiss(ruleId: String) {
        engine.dismiss(ruleId: ruleId, now: Date())
        dueReminders.removeAll { $0.ruleId == ruleId }
        store.save(rules: engine.rules, states: engine.states)
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func drinkWaterQuick() {
        complete(ruleId: ReminderEngine.defaultWaterRuleId)
    }

    // MARK: - Rule Management

    public func addRule(_ rule: ReminderRule) {
        engine.addRule(rule)
        self.rules = engine.rules
        store.save(rules: engine.rules, states: engine.states)
    }

    public func updateRule(_ rule: ReminderRule) {
        engine.updateRule(rule)
        self.rules = engine.rules
        store.save(rules: engine.rules, states: engine.states)
    }

    public func deleteRule(id: String) {
        engine.deleteRule(id: id)
        self.rules = engine.rules
        self.dueReminders.removeAll { $0.ruleId == id }
        store.save(rules: engine.rules, states: engine.states)
    }

    public func toggleRule(id: String) {
        guard let rule = rules.first(where: { $0.id == id }) else { return }
        var updated = rule
        updated.enabled.toggle()
        updateRule(updated)
    }
}

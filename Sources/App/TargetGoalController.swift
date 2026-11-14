// Sources/App/TargetGoalController.swift
import Foundation
import AppKit
import AgentPetCore

/// Manages exam prep targets, milestones, calendar day calculations,
/// and the pinned Primary Goal overview.
@MainActor
public final class TargetGoalController: ObservableObject {
    public static let shared = TargetGoalController()

    @Published public private(set) var goals: [TargetGoal] = []
    @Published public private(set) var primaryGoal: TargetGoal? = nil
    @Published public private(set) var primaryMetrics: GoalMetrics? = nil

    private let engine: TargetGoalEngine
    private let store = TargetGoalStore.shared

    private init() {
        let loaded = store.load()
        self.engine = TargetGoalEngine(goals: loaded)
        self.goals = engine.goals
        refresh()
    }

    public func refresh() {
        self.goals = engine.goals
        let prim = engine.primaryGoal
        self.primaryGoal = prim
        if let prim {
            self.primaryMetrics = TargetGoalEngine.metrics(for: prim, now: Date())
        } else {
            self.primaryMetrics = nil
        }
    }

    public func setPrimary(id: String) {
        engine.setPrimaryGoal(id: id)
        store.save(goals: engine.goals)
        refresh()
    }

    public func addGoal(
        title: String,
        category: GoalCategory,
        isPrimary: Bool = false,
        startDate: Date,
        targetDate: Date,
        dailyTargetMinutes: Int = 240,
        milestones: [GoalMilestone] = [],
        notes: String = ""
    ) {
        let goal = TargetGoal(
            title: title,
            category: category,
            isPrimary: isPrimary,
            startDate: startDate,
            targetDate: targetDate,
            dailyTargetMinutes: dailyTargetMinutes,
            milestones: milestones,
            notes: notes
        )
        engine.addGoal(goal)
        store.save(goals: engine.goals)
        refresh()
    }

    public func updateGoal(_ goal: TargetGoal) {
        engine.updateGoal(goal)
        store.save(goals: engine.goals)
        refresh()
    }

    public func deleteGoal(id: String) {
        engine.deleteGoal(id: id)
        store.save(goals: engine.goals)
        refresh()
    }

    public func toggleMilestone(goalId: String, milestoneId: String) {
        engine.toggleMilestone(goalId: goalId, milestoneId: milestoneId)
        store.save(goals: engine.goals)
        refresh()
    }

    public func focusOnPrimary() {
        let subject = primaryGoal?.title ?? "Target Focus"
        PomodoroController.shared.startFocus(subject: subject)
    }

    public func metrics(for goal: TargetGoal) -> GoalMetrics {
        TargetGoalEngine.metrics(for: goal, now: Date())
    }
}

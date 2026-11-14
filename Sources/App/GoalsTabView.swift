// Sources/App/GoalsTabView.swift
import SwiftUI
import AgentPetCore

/// Tab view for Target Goals, exam countdowns, milestone roadmaps, and setting the Primary Target.
struct GoalsTabView: View {
    @ObservedObject private var goalCtrl = TargetGoalController.shared
    @ObservedObject private var workCtrl = WorkTrackerController.shared

    @State private var newTitle: String = ""
    @State private var newCategory: GoalCategory = .gateExam
    @State private var newStartDate: Date = Date()
    @State private var newTargetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var newDailyHours: Int = 4
    @State private var newNotes: String = ""
    @State private var newMilestoneTitle: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                primaryGoalCard
                allGoalsListCard
                addGoalCard
            }
            .padding(20)
        }
    }

    // MARK: - Primary Goal Card

    @ViewBuilder
    private var primaryGoalCard: some View {
        if let goal = goalCtrl.primaryGoal, let metrics = goalCtrl.primaryMetrics {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "crown.fill").foregroundStyle(.yellow)
                    EyebrowLabel("PRIMARY TARGET OVERVIEW")
                    Spacer()
                    Text(metrics.statusLabel)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.accent.opacity(0.25)))
                        .foregroundStyle(Theme.accent)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.title)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text(metrics.elapsedLabel)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button {
                        goalCtrl.focusOnPrimary()
                    } label: {
                        Label("Focus Now", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.systemAccent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Timeline Progress").font(.caption).foregroundStyle(Theme.muted)
                        Spacer()
                        Text("\(Int(metrics.timelineProgress * 100))% elapsed")
                            .font(.caption.monospaced())
                            .foregroundStyle(.white)
                    }
                    ProgressView(value: metrics.timelineProgress)
                        .tint(Theme.accent)
                }

                // Milestones checklist
                if !goal.milestones.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Milestones (\(goal.milestones.filter { $0.completed }.count)/\(goal.milestones.count))")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.8))

                        ForEach(goal.milestones) { m in
                            Button {
                                goalCtrl.toggleMilestone(goalId: goal.id, milestoneId: m.id)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: m.completed ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(m.completed ? Color.green : Theme.muted)
                                    Text(m.title)
                                        .font(.system(size: 12))
                                        .strikethrough(m.completed)
                                        .foregroundStyle(m.completed ? Theme.muted : .white)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }

                // Add milestone inline
                HStack {
                    TextField("Add milestone checkpoint...", text: $newMilestoneTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    Button("Add") {
                        guard !newMilestoneTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        var updated = goal
                        updated.milestones.append(GoalMilestone(title: newMilestoneTitle))
                        goalCtrl.updateGoal(updated)
                        newMilestoneTitle = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(newMilestoneTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .themedCard()
        }
    }

    // MARK: - All Goals List

    private var allGoalsListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel("ALL TARGETS")

            if goalCtrl.goals.isEmpty {
                Text("No target goals set yet. Add your primary exam or project target below.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(goalCtrl.goals) { g in
                    let m = goalCtrl.metrics(for: g)
                    HStack(spacing: 12) {
                        Image(systemName: g.category.icon)
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(g.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                if g.isPrimary {
                                    Text("PRIMARY")
                                        .font(.system(size: 8, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.yellow.opacity(0.25)))
                                        .foregroundStyle(.yellow)
                                }
                            }
                            Text("\(m.statusLabel) · \(g.dailyTargetMinutes / 60)h/day target · \(g.milestones.count) milestones")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }

                        Spacer()

                        if !g.isPrimary {
                            Button("Set Primary") {
                                goalCtrl.setPrimary(id: g.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }

                        Button(role: .destructive) {
                            goalCtrl.deleteGoal(id: g.id)
                        } label: {
                            Image(systemName: "trash").foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    Divider().overlay(Theme.cardStroke)
                }
            }
        }
        .themedCard()
    }

    // MARK: - Add Goal Card

    private var addGoalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel("CREATE NEW TARGET")

            TextField("Goal Title (e.g. GATE CS 2027 — AIR < 50)", text: $newTitle)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Category:").font(.system(size: 12))
                Picker("", selection: $newCategory) {
                    ForEach(GoalCategory.allCases, id: \.self) { cat in
                        Label(cat.displayName, systemImage: cat.icon).tag(cat)
                    }
                }
            }

            HStack(spacing: 16) {
                DatePicker("Start Date:", selection: $newStartDate, displayedComponents: .date)
                    .font(.system(size: 12))
                DatePicker("Target Date:", selection: $newTargetDate, displayedComponents: .date)
                    .font(.system(size: 12))
            }

            HStack {
                Text("Daily Work Target:").font(.system(size: 12))
                Stepper(value: $newDailyHours, in: 1...16) {
                    Text("\(newDailyHours) hours / day")
                }
                .font(.system(size: 12))
            }

            TextField("Notes & focus strategy (optional)", text: $newNotes)
                .textFieldStyle(.roundedBorder)

            Button("Save Target Goal") {
                guard !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                goalCtrl.addGoal(
                    title: newTitle,
                    category: newCategory,
                    isPrimary: goalCtrl.goals.isEmpty,
                    startDate: newStartDate,
                    targetDate: newTargetDate,
                    dailyTargetMinutes: newDailyHours * 60,
                    milestones: [],
                    notes: newNotes
                )
                newTitle = ""
                newNotes = ""
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .themedCard()
    }
}

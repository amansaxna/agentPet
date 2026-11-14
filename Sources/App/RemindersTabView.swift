// Sources/App/RemindersTabView.swift
import SwiftUI
import AgentPetCore

/// Tab view for managing Water, Take Time, and Custom Reminders with snooze presets.
struct RemindersTabView: View {
    @ObservedObject private var reminderCtrl = ReminderController.shared

    @State private var newTitle: String = ""
    @State private var newMessage: String = ""
    @State private var newIntervalMins: Int = 60
    @State private var isDaily: Bool = false
    @State private var dailyHour: Int = 18
    @State private var dailyMinute: Int = 0
    @State private var defaultSnooze: Int = 10

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                waterCard
                takeTimeCard
                customRemindersCard
                addReminderCard
            }
            .padding(20)
        }
    }

    // MARK: - Water Card

    private var waterCard: some View {
        let rule = reminderCtrl.rules.first { $0.id == ReminderEngine.defaultWaterRuleId }
        let isEnabled = rule?.enabled ?? true

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill").foregroundStyle(.cyan)
                EyebrowLabel("HYDRATION REMINDER (WATER)")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { _ in reminderCtrl.toggleRule(id: ReminderEngine.defaultWaterRuleId) }
                ))
                .toggleStyle(.switch)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Glasses Drunk Today: \(reminderCtrl.waterCupsToday)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Target: 8 glasses (64 oz)")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Button {
                    reminderCtrl.drinkWaterQuick()
                } label: {
                    Label("+1 Glass", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .controlSize(.small)
            }

            if let r = rule {
                HStack {
                    Text("Schedule: \(r.schedule.displayString)")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Text("Snooze: \(r.defaultSnoozeMinutes)m")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .themedCard()
    }

    // MARK: - Take Time Card

    private var takeTimeCard: some View {
        let rule = reminderCtrl.rules.first { $0.id == ReminderEngine.defaultTakeTimeRuleId }
        let isEnabled = rule?.enabled ?? true

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.walk").foregroundStyle(.orange)
                EyebrowLabel("TAKE A MOMENT (STRETCH & REST)")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { _ in reminderCtrl.toggleRule(id: ReminderEngine.defaultTakeTimeRuleId) }
                ))
                .toggleStyle(.switch)
            }

            Text("Prompts you to stand up, stretch, and relax your eyes after continuous screen activity.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)

            if let r = rule {
                HStack {
                    Text("Schedule: \(r.schedule.displayString)")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Text("Snooze: \(r.defaultSnoozeMinutes)m")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .themedCard()
    }

    // MARK: - Custom Reminders List

    private var customRemindersCard: some View {
        let customs = reminderCtrl.rules.filter { $0.kind == .custom }

        return VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel("CUSTOM REMINDERS")

            if customs.isEmpty {
                Text("No custom reminders yet. Create your first study or lifestyle reminder below.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(customs) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("\(item.schedule.displayString) · Snooze \(item.defaultSnoozeMinutes)m")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { item.enabled },
                            set: { _ in reminderCtrl.toggleRule(id: item.id) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()

                        Button(role: .destructive) {
                            reminderCtrl.deleteRule(id: item.id)
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

    // MARK: - Add Reminder Card

    private var addReminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel("ADD NEW REMINDER")

            TextField("Title (e.g. GATE Revision Flashcards, Posture Check)", text: $newTitle)
                .textFieldStyle(.roundedBorder)

            TextField("Message (optional prompt)", text: $newMessage)
                .textFieldStyle(.roundedBorder)

            HStack {
                Picker("Type", selection: $isDaily) {
                    Text("Interval (Every N min)").tag(false)
                    Text("Daily Fixed Time").tag(true)
                }
                .pickerStyle(.segmented)
            }

            if isDaily {
                HStack(spacing: 8) {
                    Text("Time:")
                    Stepper(value: $dailyHour, in: 0...23) {
                        Text(String(format: "%02d:00", dailyHour))
                    }
                    Stepper(value: $dailyMinute, in: 0...59, step: 5) {
                        Text(String(format: ":%02d", dailyMinute))
                    }
                }
                .font(.system(size: 12))
            } else {
                HStack {
                    Text("Interval:")
                    Stepper(value: $newIntervalMins, in: 10...360, step: 10) {
                        Text("\(newIntervalMins) minutes")
                    }
                }
                .font(.system(size: 12))
            }

            HStack {
                Text("Default Snooze:")
                Picker("", selection: $defaultSnooze) {
                    Text("5m").tag(5)
                    Text("10m").tag(10)
                    Text("15m").tag(15)
                    Text("30m").tag(30)
                }
                .pickerStyle(.segmented)
            }

            Button("Save Reminder") {
                guard !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                let schedule: ReminderSchedule = isDaily ?
                    .dailyTime(hour: dailyHour, minute: dailyMinute) :
                    .intervalMinutes(minutes: newIntervalMins, activeOnly: true)

                let rule = ReminderRule(
                    title: newTitle,
                    message: newMessage.isEmpty ? newTitle : newMessage,
                    kind: .custom,
                    schedule: schedule,
                    enabled: true,
                    soundEnabled: true,
                    defaultSnoozeMinutes: defaultSnooze,
                    icon: "bell.badge.fill"
                )
                reminderCtrl.addRule(rule)
                newTitle = ""
                newMessage = ""
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .themedCard()
    }
}

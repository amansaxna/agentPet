// Sources/App/FocusTabView.swift
import SwiftUI
import AgentPetCore

/// Tab view for Pomodoro, Countdown Timer, and Stopwatch settings and live controls.
struct FocusTabView: View {
    @ObservedObject private var pomo = PomodoroController.shared
    @ObservedObject private var focusClock = FocusClockController.shared
    @ObservedObject private var goals = TargetGoalController.shared

    @State private var selectedMode: FocusMode = .pomodoro
    @State private var customTimerMinutes: Int = 15

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Focus Mode Unified Segmented Selector
                HStack(spacing: 12) {
                    Text("Focus Tool")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))

                    HStack(spacing: 3) {
                        ForEach(FocusMode.allCases, id: \.self) { mode in
                            let isSelected = selectedMode == mode
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedMode = mode
                                    focusClock.activeMode = mode
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                    Text(mode.displayName)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color(red: 0x3B / 255.0, green: 0x82 / 255.0, blue: 0xF6 / 255.0))
                                            .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
                                    } else {
                                        Color.clear
                                    }
                                }
                                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.65))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }

                switch selectedMode {
                case .pomodoro:
                    // Live Pomodoro Status Card
                    liveTimerCard
                    // Duration Settings Card
                    durationsCard
                    // Automation & Sound Card
                    automationCard
                    // Target Association Card
                    associationCard

                case .timer:
                    countdownTimerCard

                case .stopwatch:
                    stopwatchCard
                }
            }
            .padding(20)
        }
    }

    // MARK: - Countdown Timer Card

    private var countdownTimerCard: some View {
        let tState = focusClock.timerState
        let isActive = (tState.state == .running || tState.state == .paused)
        let isPaused = (tState.state == .paused)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                EyebrowLabel("COUNTDOWN TIMER")
                Spacer()
                if isActive {
                    Text(isPaused ? "PAUSED" : "RUNNING")
                        .font(.caption)
                        .foregroundStyle(isPaused ? .orange : .cyan)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isActive ? tState.activeSubject : "Ready to Focus")
                        .font(.headline)
                        .foregroundStyle(Color.cyan)
                    Text(isActive ? tState.formattedRemaining : String(format: "%02d:00", customTimerMinutes))
                        .font(.system(size: 38, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(isActive ? "\(Int(tState.targetSeconds / 60)) min session" : "Select duration or preset below")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                VStack(spacing: 8) {
                    if !isActive {
                        Button("Start Timer") {
                            focusClock.startTimer(minutes: customTimerMinutes)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.cyan)
                    } else {
                        Button(isPaused ? "Resume" : "Pause") {
                            isPaused ? focusClock.resumeTimer() : focusClock.pauseTimer()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isPaused ? Color.orange : Color.cyan)

                        HStack(spacing: 6) {
                            Button("+5m") { focusClock.addTimerMinutes(5) }
                                .buttonStyle(.bordered)
                            Button("Stop") { focusClock.stopTimer() }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if isActive {
                ProgressView(value: tState.progress)
                    .tint(Color.cyan)
            } else {
                Divider().overlay(Theme.cardStroke)
                EyebrowLabel("QUICK PRESETS")
                HStack(spacing: 8) {
                    ForEach([5, 10, 15, 25, 30, 45, 60], id: \.self) { mins in
                        let isSel = (customTimerMinutes == mins)
                        Button("\(mins)m") {
                            customTimerMinutes = mins
                        }
                        .buttonStyle(.bordered)
                        .tint(isSel ? Color.cyan : .secondary)
                    }
                }

                stepperRow(label: "Custom duration", value: $customTimerMinutes, range: 1...180, unit: "min")
            }
        }
        .themedCard()
    }

    // MARK: - Stopwatch Card

    private var stopwatchCard: some View {
        let sState = focusClock.stopwatchState
        let isActive = (sState.state == .running || sState.state == .paused)
        let isPaused = (sState.state == .paused)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                EyebrowLabel("COUNT-UP STOPWATCH")
                Spacer()
                if isActive {
                    Text(isPaused ? "PAUSED" : "ACTIVE")
                        .font(.caption)
                        .foregroundStyle(isPaused ? .orange : .green)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isActive ? sState.activeSubject : "Track Deep Work")
                        .font(.headline)
                        .foregroundStyle(Color.green)
                    Text(sState.formattedElapsed)
                        .font(.system(size: 38, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(isActive ? "\(sState.laps.count) laps recorded" : "Start clocking uninterrupted focus time")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                VStack(spacing: 8) {
                    if !isActive {
                        Button("Start Stopwatch") {
                            focusClock.startStopwatch()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.green)
                    } else {
                        Button(isPaused ? "Resume" : "Pause") {
                            isPaused ? focusClock.resumeStopwatch() : focusClock.pauseStopwatch()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isPaused ? Color.orange : Color.green)

                        HStack(spacing: 6) {
                            Button("Lap") { focusClock.lapStopwatch() }
                                .buttonStyle(.bordered)
                            Button("Stop & Save") { focusClock.stopStopwatch() }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if !sState.laps.isEmpty {
                Divider().overlay(Theme.cardStroke)
                EyebrowLabel("LAPS / SPLITS")
                ForEach(Array(sState.laps.enumerated()), id: \.offset) { idx, lapSecs in
                    let m = Int(lapSecs) / 60
                    let s = Int(lapSecs) % 60
                    HStack {
                        Text("Lap \(sState.laps.count - idx)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(String(format: "%02d:%02d", m, s))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
        }
        .themedCard()
    }

    // MARK: - Live Timer Card

    private var liveTimerCard: some View {
        VStack(spacing: 12) {
            HStack {
                EyebrowLabel("POMODORO SESSION")
                Spacer()
                Text("Cycle #\(pomo.state.currentCycle) · \(pomo.state.completedCyclesToday) today")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pomo.state.phase.displayName)
                        .font(.headline)
                        .foregroundStyle(phaseColor)
                    Text(pomo.state.formattedRemaining)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("Subject: \(pomo.state.activeSubject)")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                VStack(spacing: 8) {
                    if pomo.state.phase == .idle {
                        Button("Start Focus") {
                            pomo.startFocus()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.systemAccent)
                    } else {
                        Button(pomo.state.isPaused ? "Resume" : "Pause") {
                            pomo.state.isPaused ? pomo.resume() : pomo.pause()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.systemAccent)

                        HStack(spacing: 8) {
                            Button("Skip") { pomo.skip() }
                                .buttonStyle(.bordered)
                            Button("Reset") { pomo.reset() }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            ProgressView(value: pomo.state.progress)
                .tint(phaseColor)
        }
        .themedCard()
    }

    private var phaseColor: Color {
        switch pomo.state.phase {
        case .focus: return .red
        case .shortBreak: return .green
        case .longBreak: return .cyan
        case .idle: return Theme.muted
        }
    }

    // MARK: - Durations Card

    private var durationsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EyebrowLabel("INTERVAL DURATIONS")

            stepperRow(label: "Focus duration", value: $pomo.config.focusMinutes, range: 5...120, unit: "min")
            Divider().overlay(Theme.cardStroke)
            stepperRow(label: "Short break duration", value: $pomo.config.shortBreakMinutes, range: 1...30, unit: "min")
            Divider().overlay(Theme.cardStroke)
            stepperRow(label: "Long break duration", value: $pomo.config.longBreakMinutes, range: 5...60, unit: "min")
            Divider().overlay(Theme.cardStroke)
            stepperRow(label: "Cycles before long break", value: $pomo.config.cyclesBeforeLongBreak, range: 1...10, unit: "cycles")
        }
        .themedCard()
    }

    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(.white)
            Spacer()
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue) \(unit)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Automation & Sound

    private var automationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EyebrowLabel("AUTOMATION & ALERTS")

            Toggle("Auto-start break when focus ends", isOn: $pomo.config.autoStartBreak)
                .toggleStyle(.switch)
            Divider().overlay(Theme.cardStroke)
            Toggle("Auto-start focus when break ends", isOn: $pomo.config.autoStartFocus)
                .toggleStyle(.switch)
            Divider().overlay(Theme.cardStroke)
            Toggle("Sound alerts on phase completion", isOn: $pomo.config.soundEnabled)
                .toggleStyle(.switch)
        }
        .themedCard()
    }

    // MARK: - Association Card

    private var associationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel("DEFAULT SUBJECT / TAG")

            HStack {
                TextField("e.g. GATE Exam, Deep Work", text: $pomo.config.defaultSubjectTag)
                    .textFieldStyle(.roundedBorder)

                if let prim = goals.primaryGoal {
                    Button("Use Primary Target") {
                        pomo.config.defaultSubjectTag = prim.title
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            Text("Focus sessions log automatically under this tag in your Work Time Tracker.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .themedCard()
    }
}

import AppKit
import SwiftUI
import AgentPetCore

/// The pet's right-click HUD: the companion's stats, primary target goal countdown,
/// Pomodoro & focus tracker, hydration counter, tailored quote strip, and quick footer.
struct PetStatsView: View {
    /// The pet whose stats to show. `nil` resolves to the globally selected pet.
    var petID: String? = nil
    @ObservedObject private var care = PetCareController.shared
    @ObservedObject private var pet = PetController.shared
    @ObservedObject private var imagePets = ImagePetStore.shared
    @ObservedObject private var usage = OpenUsageClient.shared
    @ObservedObject private var usageStore = ProjectUsageStore.shared
    @ObservedObject private var updater = UpdaterController.shared

    @ObservedObject private var goalCtrl = TargetGoalController.shared
    @ObservedObject private var pomoCtrl = PomodoroController.shared
    @ObservedObject private var focusClock = FocusClockController.shared
    @ObservedObject private var musicCtrl = FocusMusicController.shared
    @ObservedObject private var workCtrl = WorkTrackerController.shared
    @ObservedObject private var reminderCtrl = ReminderController.shared
    @ObservedObject private var quoteCtrl = QuoteController.shared
    @ObservedObject private var dayProgressCtrl = DayProgressController.shared

    @AppStorage("pet_stats_view_mode") private var viewMode: String = "all"
    @State private var updateLabel: String?
    @State private var hoveredAchievement: Achievement?
    @State private var selectedFocusTab: FocusMode = .pomodoro
    @State private var selectedTimerMinutes: Int = 15

    private static let stageColors: [Color] = [.green, .teal, .blue, .purple, .orange]

    /// The pet id this card is showing — the passed id, else the selected pet.
    private var resolvedPetID: String? { petID ?? pet.selectedPetID }

    private var pack: ImagePetPack? {
        resolvedPetID.flatMap { imagePets.pack(id: $0) }
    }

    /// Care state of the resolved pet.
    private var careState: PetCareState { care.state(for: resolvedPetID) }
    private var level: Int { PetCare.displayLevel(forXP: careState.xp) }
    private var stageKey: String { PetCare.stageName(forLevel: PetCare.level(forXP: careState.xp)) }
    private var stageIndex: Int { PetCare.stageIndex(forLevel: PetCare.level(forXP: careState.xp)) }
    private var levelProgress: Double { PetCare.progress(forXP: careState.xp) }
    private var hunger: PetHunger { PetCare.hunger(state: careState, now: Date()) }

    private var stageColor: Color { Self.stageColors[min(stageIndex, Self.stageColors.count - 1)] }

    var body: some View {
        let state = careState
        VStack(alignment: .leading, spacing: 10) {
            header(state)
            viewModeSelector

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    if viewMode == "all" || viewMode == "pet" {
                        xpBlock(state)
                    }

                    if viewMode == "all" {
                        dueReminderAlertSection
                        dayProgressDashboardSection
                        goalOverviewSection
                        quoteSection
                    } else if viewMode == "focus" {
                        dueReminderAlertSection
                        dayProgressDashboardSection
                        goalOverviewSection
                        pomodoroSectionAboveAgents
                        focusMusicSection
                        quoteSection
                        workAnalyticsSection
                        milestonesSection
                    }

                    if viewMode == "all" || viewMode == "pet" {
                        achievementBlock
                        statGrid(state)
                        trendBlock(state)
                        costBlock

                        // Dedicated Focus Suite Section placed directly above the agents line
                        pomodoroSectionAboveAgents
                        focusMusicSection
                        if viewMode == "pet" {
                            dayProgressDashboardSection
                        }

                        AgentUsageRows(limit: 3)
                        usageBlock
                        if let last = state.lastFedAt {
                            HStack {
                                Text("Last fed").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                                Spacer()
                                Text(verbatim: last.formatted(.relative(presentation: .named)))
                                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 490)

            footer
        }
        .padding(14)
        .frame(width: 320)
        .background(.regularMaterial)
        .environment(\.colorScheme, .dark)
        .textSelection(.enabled)
        .noFocusRing()
    }

    // MARK: - View Mode Selector

    private var viewModeSelector: some View {
        HStack(spacing: 3) {
            modeButton(id: "all", label: "All", icon: "sparkles")
            modeButton(id: "focus", label: "Target & Focus", icon: "target")
            modeButton(id: "pet", label: "Companion", icon: "pawprint.fill")
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
    }

    private func modeButton(id: String, label: String, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewMode = id
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9))
                Text(label).font(.system(size: 10, weight: viewMode == id ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(viewMode == id ? stageColor.opacity(0.25) : Color.clear)
            )
            .foregroundStyle(viewMode == id ? stageColor : Color.white.opacity(0.55))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Primary Target Goal Overview

    @ViewBuilder
    private var goalOverviewSection: some View {
        if let goal = goalCtrl.primaryGoal, let metrics = goalCtrl.primaryMetrics {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: goal.category.icon)
                        .font(.system(size: 9))
                        .foregroundStyle(stageColor)
                    Text("PRIMARY TARGET · \(goal.category.displayName.uppercased())")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Text(metrics.statusLabel)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(metrics.isOverdue ? Color.red.opacity(0.25) : stageColor.opacity(0.2)))
                        .foregroundStyle(metrics.isOverdue ? Color.red : stageColor)
                }

                HStack {
                    Text(goal.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        goalCtrl.focusOnPrimary()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "play.fill").font(.system(size: 7))
                            Text("Focus").font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(stageColor))
                        .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                }

                ProgressView(value: metrics.timelineProgress)
                    .tint(stageColor)
                    .controlSize(.mini)

                HStack {
                    Text(metrics.elapsedLabel)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Text("Today \(workCtrl.formattedTodayWorked) / \(goal.dailyTargetMinutes / 60)h")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(9)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(stageColor.opacity(0.25), lineWidth: 1))
        }
    }

    // MARK: - Pomodoro & Focus Section (Above Agents Line)

    // MARK: - Pomodoro & Focus Suite Section (Above Agents Line)

    private var isFocusBorderActive: Bool {
        (pomoCtrl.state.phase != .idle) || focusClock.isAnyActive
    }

    private var pomodoroSectionAboveAgents: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Mode Selector: [ Pomodoro | Timer | Stopwatch ]
            HStack(spacing: 4) {
                ForEach(FocusMode.allCases, id: \.self) { mode in
                    let isTabSelected = (selectedFocusTab == mode)
                    let isModeRunning: Bool = {
                        switch mode {
                        case .pomodoro: return pomoCtrl.state.phase != .idle
                        case .timer: return focusClock.isTimerActive
                        case .stopwatch: return focusClock.isStopwatchActive
                        }
                    }()

                    Button {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            selectedFocusTab = mode
                        }
                    } label: {
                        HStack(spacing: 3) {
                            if isModeRunning {
                                Circle().fill(Color.orange).frame(width: 4, height: 4)
                            }
                            Image(systemName: mode.icon).font(.system(size: 8))
                            Text(mode.displayName).font(.system(size: 8.5, weight: isTabSelected ? .bold : .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3.5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isTabSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.04))
                        )
                        .foregroundStyle(isTabSelected ? .white : .white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Tab Content
            switch selectedFocusTab {
            case .pomodoro:
                pomodoroTabContent
            case .timer:
                timerTabContent
            case .stopwatch:
                stopwatchTabContent
            }

            // Quick sub-row: Clock in/out, Hydration, Worked today
            focusSubRow
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocusBorderActive ? stageColor.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Pomodoro Tab Content

    private var pomodoroTabContent: some View {
        let pomoState = pomoCtrl.state
        let isRunning = (pomoState.phase != .idle)
        let isFocus = (pomoState.phase == .focus)
        let isBreak = pomoState.phase.isBreak

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isFocus ? Color.red : (isBreak ? Color.green : Color.gray))
                    .frame(width: 7, height: 7)
                Text(isRunning ? pomoState.phase.displayName.uppercased() : "POMODORO")
                    .font(.system(size: 9, weight: .bold)).tracking(0.8)
                    .foregroundStyle(isFocus ? Color.red : (isBreak ? Color.green : .white.opacity(0.45)))

                if isRunning && !pomoState.activeSubject.isEmpty {
                    Text("· \(pomoState.activeSubject)")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer()

                Text(pomoState.formattedRemaining)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(isRunning ? (pomoState.isPaused ? .orange : .white) : .white.opacity(0.5))
            }

            HStack(spacing: 6) {
                if !isRunning {
                    Button {
                        pomoCtrl.startFocus()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill").font(.system(size: 8))
                            Text("Start Focus").font(.system(size: 10, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(stageColor))
                        .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)

                    Button {
                        pomoCtrl.startBreak(isLong: false)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "cup.and.saucer.fill").font(.system(size: 8))
                            Text("Start Break").font(.system(size: 10, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                        .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        pomoState.isPaused ? pomoCtrl.resume() : pomoCtrl.pause()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: pomoState.isPaused ? "play.fill" : "pause.fill").font(.system(size: 8))
                            Text(pomoState.isPaused ? "Resume" : "Pause").font(.system(size: 10, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(stageColor))
                        .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)

                    Button {
                        pomoCtrl.stop()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "stop.fill").font(.system(size: 8))
                            Text("Stop").font(.system(size: 10, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.2)))
                        .foregroundStyle(Color.red)
                    }
                    .buttonStyle(.plain)

                    if isFocus {
                        Button {
                            pomoCtrl.startBreak(isLong: false)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "cup.and.saucer.fill").font(.system(size: 8))
                                Text("Break").font(.system(size: 10, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                            .foregroundStyle(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            pomoCtrl.startFocus()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "target").font(.system(size: 8))
                                Text("Focus").font(.system(size: 10, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                            .foregroundStyle(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Countdown Timer Tab Content

    private var timerTabContent: some View {
        let tState = focusClock.timerState
        let isRunning = (tState.state == .running)
        let isPaused = (tState.state == .paused)
        let isActive = isRunning || isPaused

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isActive ? (isPaused ? Color.orange : Color.cyan) : Color.gray)
                    .frame(width: 7, height: 7)
                Text(isActive ? "COUNTDOWN TIMER" : "TIMER PRESETS")
                    .font(.system(size: 9, weight: .bold)).tracking(0.8)
                    .foregroundStyle(isActive ? Color.cyan : .white.opacity(0.45))

                if isActive && !tState.activeSubject.isEmpty {
                    Text("· \(tState.activeSubject)")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer()

                Text(isActive ? tState.formattedRemaining : String(format: "%02d:00", selectedTimerMinutes))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(isActive ? (isPaused ? .orange : .white) : .white.opacity(0.5))
            }

            if !isActive {
                // Preset options bar: 5m, 15m, 25m, 45m, 60m
                HStack(spacing: 4) {
                    ForEach([5, 10, 15, 25, 45, 60], id: \.self) { mins in
                        let isPresetSelected = (selectedTimerMinutes == mins)
                        Button {
                            selectedTimerMinutes = mins
                        } label: {
                            Text("\(mins)m")
                                .font(.system(size: 8.5, weight: isPresetSelected ? .bold : .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 3.5)
                                .background(RoundedRectangle(cornerRadius: 4).fill(isPresetSelected ? stageColor.opacity(0.25) : Color.white.opacity(0.06)))
                                .foregroundStyle(isPresetSelected ? stageColor : .white.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    focusClock.startTimer(minutes: selectedTimerMinutes)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill").font(.system(size: 8))
                        Text("Start \(selectedTimerMinutes)m Timer").font(.system(size: 10, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(stageColor))
                    .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 6) {
                    Button {
                        isPaused ? focusClock.resumeTimer() : focusClock.pauseTimer()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: isPaused ? "play.fill" : "pause.fill").font(.system(size: 8))
                            Text(isPaused ? "Resume" : "Pause").font(.system(size: 10, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(stageColor))
                        .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)

                    Button {
                        focusClock.addTimerMinutes(5)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus").font(.system(size: 8))
                            Text("+5m").font(.system(size: 10, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                        .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)

                    Button {
                        focusClock.stopTimer()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "stop.fill").font(.system(size: 8))
                            Text("Stop").font(.system(size: 10, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.2)))
                        .foregroundStyle(Color.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Stopwatch Tab Content

    private var stopwatchTabContent: some View {
        let sState = focusClock.stopwatchState
        let isRunning = (sState.state == .running)
        let isPaused = (sState.state == .paused)
        let isActive = isRunning || isPaused

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isActive ? (isPaused ? Color.orange : Color.green) : Color.gray)
                    .frame(width: 7, height: 7)
                Text(isActive ? "STOPWATCH RUNNING" : "STOPWATCH")
                    .font(.system(size: 9, weight: .bold)).tracking(0.8)
                    .foregroundStyle(isActive ? Color.green : .white.opacity(0.45))

                if isActive && !sState.activeSubject.isEmpty {
                    Text("· \(sState.activeSubject)")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer()

                Text(sState.formattedElapsed)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(isActive ? (isPaused ? .orange : .white) : .white.opacity(0.5))
            }

            HStack(spacing: 6) {
                if !isActive {
                    Button {
                        focusClock.startStopwatch()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill").font(.system(size: 8))
                            Text("Start Stopwatch").font(.system(size: 10, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(stageColor))
                        .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        isPaused ? focusClock.resumeStopwatch() : focusClock.pauseStopwatch()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: isPaused ? "play.fill" : "pause.fill").font(.system(size: 8))
                            Text(isPaused ? "Resume" : "Pause").font(.system(size: 10, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(stageColor))
                        .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)

                    Button {
                        focusClock.lapStopwatch()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "flag.fill").font(.system(size: 8))
                            Text("Lap (\(sState.laps.count))").font(.system(size: 10, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                        .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)

                    Button {
                        focusClock.stopStopwatch()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "stop.fill").font(.system(size: 8))
                            Text("Stop (Save)").font(.system(size: 10, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.2)))
                        .foregroundStyle(Color.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !sState.laps.isEmpty {
                HStack(spacing: 6) {
                    Text("LAPS:")
                        .font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.35))
                    ForEach(Array(sState.laps.prefix(3).enumerated()), id: \.offset) { idx, lapSecs in
                        let m = Int(lapSecs) / 60
                        let s = Int(lapSecs) % 60
                        Text("#\(sState.laps.count - idx): \(String(format: "%02d:%02d", m, s))")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Focus Quick Actions Sub-row

    private var focusSubRow: some View {
        HStack(spacing: 6) {
            Button {
                workCtrl.toggleManualWork()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: workCtrl.isWorkingManual ? "stop.circle.fill" : "play.circle")
                        .font(.system(size: 8))
                    Text(workCtrl.isWorkingManual ? "Clock Out" : "Clock In")
                        .font(.system(size: 8.5, weight: .medium))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2.5)
                .background(RoundedRectangle(cornerRadius: 4).fill(workCtrl.isWorkingManual ? Color.red.opacity(0.2) : Color.white.opacity(0.06)))
                .foregroundStyle(workCtrl.isWorkingManual ? Color.red : .white.opacity(0.8))
            }
            .buttonStyle(.plain)

            Button {
                reminderCtrl.drinkWaterQuick()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "drop.fill").font(.system(size: 8))
                    Text("+1 Water (\(reminderCtrl.waterCupsToday))").font(.system(size: 8.5))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2.5)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.blue.opacity(0.18)))
                .foregroundStyle(Color.cyan)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: "clock").font(.system(size: 8))
                Text(workCtrl.formattedTodayWorked)
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Focus Music Section

    private var focusMusicSection: some View {
        let isPlaying = musicCtrl.isPlaying
        let station = musicCtrl.currentStation

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isPlaying ? Color.cyan : Color.gray)
                    .frame(width: 7, height: 7)
                Text(isPlaying ? "NOW PLAYING" : "FOCUS MUSIC")
                    .font(.system(size: 9, weight: .bold)).tracking(0.8)
                    .foregroundStyle(isPlaying ? Color.cyan : .white.opacity(0.45))

                Text("· \(station.title)")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)

                Spacer()

                Button {
                    musicCtrl.togglePlay()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 11))
                        Text(isPlaying ? "Stop" : "Play")
                            .font(.system(size: 8.5, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(RoundedRectangle(cornerRadius: 4).fill(isPlaying ? Color.cyan.opacity(0.2) : stageColor.opacity(0.2)))
                    .foregroundStyle(isPlaying ? Color.cyan : stageColor)
                }
                .buttonStyle(.plain)
            }

            // Soundscape Station Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(FocusMusicStation.stations) { st in
                        let isSel = (st.id == station.id)
                        Button {
                            musicCtrl.selectStation(st)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: st.icon).font(.system(size: 7.5))
                                Text(st.title).font(.system(size: 8, weight: isSel ? .bold : .regular))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isSel ? Color.cyan.opacity(0.25) : Color.white.opacity(0.06))
                            )
                            .foregroundStyle(isSel ? Color.cyan : .white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Volume slider + quick controls
            HStack(spacing: 6) {
                Image(systemName: musicCtrl.volume == 0 ? "speaker.slash" : (musicCtrl.volume < 0.5 ? "speaker.wave.1" : "speaker.wave.2"))
                    .font(.system(size: 8.5))
                    .foregroundStyle(.white.opacity(0.4))

                Slider(value: $musicCtrl.volume, in: 0...1)
                    .controlSize(.mini)
                    .tint(Color.cyan)

                Text("\(Int(musicCtrl.volume * 100))%")
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 24, alignment: .trailing)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isPlaying ? Color.cyan.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - 24-Hour Day Progress & Sleep Schedule Dashboard Section

    private var dayProgressDashboardSection: some View {
        let snap = dayProgressCtrl.currentSnapshot
        let cfg = dayProgressCtrl.config

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: snap.currentSection.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: snap.currentSection.colorHex))
                Text("24h Day Progress & Sleep")
                    .font(.system(size: 9, weight: .bold)).tracking(0.7)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text("\(Int(snap.percentPassed * 100))% done")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.cyan)
            }

            HStack {
                Text("\(snap.hoursPassedFormatted) passed")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                Text("·")
                    .foregroundStyle(.white.opacity(0.3))
                Text("\(snap.remainingFormatted) left")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if snap.isPastSleepTime {
                    Text("🌙 Nighttime")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(red: 0.7, green: 0.6, blue: 1.0))
                } else {
                    Text("🌙 Sleep: \(snap.sleepTimeFormatted)")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // The 24-Hour Day Progress Bar with Nighttime Demarcation Line
            DayProgressBarView(snapshot: snap, config: cfg, barWidth: 292, barHeight: 9)

            HStack {
                Text("0h")
                    .font(.system(size: 8)).foregroundStyle(.white.opacity(0.3))
                Spacer()
                Text("🌅 \(snap.wakeTimeFormatted)")
                    .font(.system(size: 8)).foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text("🌙 \(snap.sleepTimeFormatted)")
                    .font(.system(size: 8, weight: .bold)).foregroundStyle(Color(red: 0.75, green: 0.65, blue: 1.0))
                Spacer()
                Text("24h")
                    .font(.system(size: 8)).foregroundStyle(.white.opacity(0.3))
            }

            // Controls: Configurable Sleep Hour & Preview Button
            HStack(spacing: 6) {
                Menu {
                    ForEach([20, 21, 22, 23, 0, 1, 2], id: \.self) { h in
                        Button(action: { dayProgressCtrl.updateSleepHour(h) }) {
                            Text(h == 0 ? "12:00 AM" : h > 12 ? "\(h - 12):00 PM" : "\(h):00 AM")
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "moon.fill").font(.system(size: 8))
                        Text("Bedtime: \(snap.sleepTimeFormatted)")
                    }
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .foregroundStyle(.white.opacity(0.85))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                Button {
                    dayProgressCtrl.showChime()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "bell.badge.fill").font(.system(size: 8))
                        Text("Preview Chime")
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.cyan.opacity(0.2)))
                    .foregroundStyle(Color.cyan)
                }
                .buttonStyle(.plain)
                .help("Show the hourly day-progress notification above the pet")
            }
            .padding(.top, 2)
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: 0.12).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Due Reminder Alert Banner

    @ViewBuilder
    private var dueReminderAlertSection: some View {
        if let due = reminderCtrl.dueReminders.first {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: due.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.orange)
                    Text(due.title)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("DUE")
                        .font(.system(size: 8, weight: .black))
                        .tracking(0.8)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color.orange.opacity(0.3)))
                        .foregroundStyle(Color.orange)
                }
                Text(due.message)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)

                HStack(spacing: 5) {
                    Button("Snooze 5m") {
                        reminderCtrl.snooze(ruleId: due.ruleId, minutes: 5)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Spacer()

                    Button("Done") {
                        reminderCtrl.complete(ruleId: due.ruleId)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.mini)
                }
                .padding(.top, 2)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
        }
    }

    // MARK: - Quote Section

    private var quoteSection: some View {
        let item = quoteCtrl.currentQuote
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                HStack(spacing: 3) {
                    Image(systemName: item.category.icon).font(.system(size: 7))
                    Text(item.category.displayName.uppercased())
                        .font(.system(size: 7, weight: .bold))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(stageColor.opacity(0.2)))
                .foregroundStyle(stageColor)

                Spacer()

                Button {
                    quoteCtrl.toggleFavorite(id: item.id)
                } label: {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 9))
                        .foregroundStyle(item.isFavorite ? Color.yellow : .white.opacity(0.35))
                }
                .buttonStyle(.plain)

                Button {
                    quoteCtrl.nextQuote()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }

            Text("\"\(item.text)\"")
                .font(.system(size: 9.5, weight: .medium, design: .serif))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !item.authorOrMeaning.isEmpty {
                Text(item.category == .idioms ? "Meaning: \(item.authorOrMeaning)" : "— \(item.authorOrMeaning)")
                    .font(.system(size: 8.5, design: .serif))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
    }

    // MARK: - Focus Tab Specific: Work Analytics & Milestones

    @ViewBuilder
    private var workAnalyticsSection: some View {
        if let report = workCtrl.todayReport {
            let focusRatio = Int(report.focusToBreakRatio * 100)
            let attainment = Int(report.dailyTargetAttainmentPercent * 100)
            let cells: [(String, String, String)] = [
                ("FOCUS TIME", workCtrl.formattedTodayWorked, "Worked today"),
                ("EFFICIENCY", "\(focusRatio)%", "Focus ratio"),
                ("TARGET", "\(attainment)%", "Daily goal attainment"),
                ("ACTIVE STREAK", "\(report.activeStreakDays)", "Days in a row")
            ]
            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY'S WORK ANALYSIS")
                    .font(.system(size: 8, weight: .semibold)).tracking(0.8)
                    .foregroundStyle(.white.opacity(0.35))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(cells, id: \.0) { cell in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(cell.0)
                                .font(.system(size: 7.5, weight: .semibold)).tracking(0.6)
                                .foregroundStyle(.white.opacity(0.35))
                            Text(verbatim: cell.1)
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            Text(verbatim: cell.2)
                                .font(.system(size: 8)).foregroundStyle(.white.opacity(0.45))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 7).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var milestonesSection: some View {
        if let primary = goalCtrl.primaryGoal, !primary.milestones.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("MILESTONES")
                    .font(.system(size: 8, weight: .semibold)).tracking(0.8)
                    .foregroundStyle(.white.opacity(0.35))
                ForEach(primary.milestones) { ms in
                    HStack(spacing: 6) {
                        Button {
                            goalCtrl.toggleMilestone(goalId: primary.id, milestoneId: ms.id)
                        } label: {
                            Image(systemName: ms.completed ? "checkmark.square.fill" : "square")
                                .font(.system(size: 11))
                                .foregroundStyle(ms.completed ? stageColor : .white.opacity(0.3))
                        }
                        .buttonStyle(.plain)

                        Text(ms.title)
                            .font(.system(size: 10, weight: ms.completed ? .regular : .medium))
                            .foregroundStyle(ms.completed ? .white.opacity(0.4) : .white.opacity(0.85))
                            .strikethrough(ms.completed, color: .white.opacity(0.4))
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
        }
    }

    // MARK: - Footer (Settings / Updates / Quit)

    private var footer: some View {
        VStack(spacing: 8) {
            Divider().overlay(Color.white.opacity(0.08))
            HStack {
                footButton(icon: "gearshape", label: "Settings") {
                    PetWindowController.shared.closeStatsPopover()
                    SettingsWindowController.shared.show()
                }
                footButton(icon: "arrow.triangle.2.circlepath",
                           label: updateLabel ?? NSLocalizedString("Updates", comment: ""),
                           badge: updater.updatePending) {
                    updateLabel = NSLocalizedString("Checking…", comment: "")
                    UpdaterController.shared.checkForUpdates()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { updateLabel = nil }
                }
                Spacer()
                footButton(icon: "power", label: "Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    private func footButton(icon: String, label: String, badge: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                    if badge {
                        Circle().fill(Color.orange).frame(width: 5, height: 5).offset(x: 3, y: -3)
                    }
                }
                Text(verbatim: label)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private func header(_ state: PetCareState) -> some View {
        HStack(spacing: 10) {
            Group {
                if let frame = pack?.clip(0).first {
                    Image(nsImage: frame).resizable().interpolation(.none).scaledToFit().padding(4)
                } else {
                    Image(systemName: "pawprint.fill").foregroundStyle(.secondary)
                }
            }
            .frame(width: 46, height: 46)
            .background(RoundedRectangle(cornerRadius: 10).fill(stageColor.opacity(0.14)))

            VStack(alignment: .leading, spacing: 3) {
                Text(imagePets.displayName(for: resolvedPetID))
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(verbatim: "Lv \(level)")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(stageColor)
                    StageBadge(stageIndex: stageIndex, size: 16)
                    Text(NSLocalizedString(stageKey, comment: "stage"))
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(stageColor.opacity(0.2)))
                        .foregroundStyle(stageColor)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(CareFormat.hunger(hunger))
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                ProgressView(value: fullness)
                    .tint(fullness > 0.5 ? .green : (fullness > 0.25 ? .orange : .red))
                    .controlSize(.small)
                    .frame(width: 64)
            }
        }
    }

    // MARK: - XP

    private func xpBlock(_ state: PetCareState) -> some View {
        let (inLevel, span) = PetCare.xpWithinLevel(forXP: state.xp)
        let xpRemaining = max(0, span - inLevel)
        let focusMinutes = xpRemaining // 1 XP = 60s (1 min) focus
        let focusText = focusMinutes >= 60 ? String(format: "or ≈ %.1fh focus", Double(focusMinutes) / 60.0) : "or ≈ \(focusMinutes)m focus"

        return VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: levelProgress).tint(stageColor).controlSize(.small)
            HStack {
                Text(verbatim: "\(CareFormat.plain(inLevel)) / \(CareFormat.plain(span)) XP")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text(verbatim: "\(Int((levelProgress * 100).rounded()))%")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(stageColor)
            }
            Text("≈ \(CareFormat.tokens(PetCare.tokensToNextLevel(state: state))) tokens (\(focusText)) to Lv \(level + 1)")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(stageColor.opacity(0.9))
        }
    }

    // MARK: - Achievements

    private var achievementBlock: some View {
        let unlocked = care.achievements
        let total = Achievement.allCases.count
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Achievements")
                    .font(.system(size: 9, weight: .semibold)).tracking(0.8)
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
                Text(verbatim: "\(unlocked.count) / \(total)")
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.55))
            }
            HStack(spacing: 2) {
                ForEach(Achievement.allCases, id: \.self) { a in
                    let symbol = PetCare.achievementSymbol(a)
                    let isUnlocked = unlocked.contains(a)
                    Image(systemName: symbol)
                        .font(.system(size: 11))
                        .foregroundStyle(isUnlocked ? stageColor : Color.white.opacity(0.15))
                        .frame(maxWidth: .infinity, minHeight: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(hoveredAchievement == a ? Color.white.opacity(0.08) : .clear)
                        )
                        .help(PetCare.achievementDisplayName(a))
                        .onHover { inside in
                            hoveredAchievement = inside ? a : (hoveredAchievement == a ? nil : hoveredAchievement)
                        }
                }
            }
            .frame(maxWidth: .infinity)
            achievementHint(unlocked: unlocked)
        }
    }

    @ViewBuilder private func achievementHint(unlocked: Set<Achievement>) -> some View {
        HStack(spacing: 5) {
            if let a = hoveredAchievement {
                let done = unlocked.contains(a)
                Image(systemName: done ? "checkmark.circle.fill" : "lock.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(done ? stageColor : .white.opacity(0.35))
                Text(PetCare.achievementDisplayName(a))
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                Text(verbatim: "·").font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
                Text(PetCare.achievementDescription(a))
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            } else {
                Text("Hover a badge to see how to unlock it")
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
            }
            Spacer(minLength: 0)
        }
        .frame(height: 12)
    }

    // MARK: - Stat grid

    private func statGrid(_ state: PetCareState) -> some View {
        let todaySub: String = {
            let meals = mealText(state.mealsToday)
            if state.focusSecondsToday > 0 {
                return "\(meals) · \(PetCare.formattedFocusDuration(seconds: state.focusSecondsToday)) focus"
            }
            return meals
        }()
        let lifeSub: String = {
            if state.totalFocusSeconds > 0 {
                return "\(PetCare.formattedFocusDuration(seconds: state.totalFocusSeconds)) focus"
            }
            return NSLocalizedString("tokens eaten", comment: "")
        }()

        let cells: [(String, String, String)] = [
            (NSLocalizedString("Today", comment: ""), CareFormat.tokens(state.tokensToday), todaySub),
            (NSLocalizedString("Streak", comment: ""), streakValue(state), NSLocalizedString("days fed", comment: "")),
            (NSLocalizedString("Lifetime", comment: ""), CareFormat.tokens(state.totalTokens), lifeSub),
            (NSLocalizedString("Sessions", comment: ""), "\(state.totalMeals)", NSLocalizedString("completed", comment: "")),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(cells, id: \.0) { cell in
                VStack(alignment: .leading, spacing: 1) {
                    Text(cell.0.uppercased())
                        .font(.system(size: 8, weight: .semibold)).tracking(0.8)
                        .foregroundStyle(.white.opacity(0.35))
                    Text(verbatim: cell.1)
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    Text(verbatim: cell.2)
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
            }
        }
    }

    // MARK: - 7-day trend

    private func trendBlock(_ state: PetCareState) -> some View {
        let series = PetCare.recentDays(state: state, now: Date())
        let peak = max(series.map(\.tokens).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Burn, last 7 days")
                    .font(.system(size: 9, weight: .semibold)).tracking(0.8)
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
                Text(verbatim: CareFormat.tokens(series.map(\.tokens).reduce(0, +)))
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.55))
            }
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(series.enumerated()), id: \.offset) { i, day in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i == series.count - 1 ? stageColor : stageColor.opacity(0.4))
                            .frame(height: max(3, CGFloat(day.tokens) / CGFloat(peak) * 34))
                            .frame(maxWidth: .infinity)
                        Text(verbatim: day.label)
                            .font(.system(size: 8)).foregroundStyle(.white.opacity(0.35))
                    }
                }
            }
            .frame(height: 48, alignment: .bottom)
        }
    }

    // MARK: - Cost

    private var costBlock: some View {
        HStack {
            Text("Est. cost (Claude)")
                .font(.system(size: 9, weight: .semibold)).tracking(0.8)
                .foregroundStyle(.white.opacity(0.35))
            Spacer()
            Text(verbatim: String(format: NSLocalizedString("Today %@ · Month %@", comment: "cost row: today / this month estimate"),
                                   Self.costString(usageStore.todayCostUSD), Self.costString(usageStore.monthlyCostUSD)))
                .font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.55))
        }
    }

    private static func costString(_ usd: Double) -> String {
        String(format: "$%.2f", usd)
    }

    // MARK: - Usage / limits

    @ObservedObject private var probe = NativeUsageProbe.shared
    @ObservedObject private var visibility = UsageVisibility.shared
    @State private var limitsExpanded = false
    private static let collapsedProviders = 2

    @ViewBuilder private var usageBlock: some View {
        let providers = visibility.visible(NativeUsageProbe.combined())
        if !providers.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Limits")
                    .font(.system(size: 9, weight: .semibold)).tracking(0.8)
                    .foregroundStyle(.white.opacity(0.35))
                let shown = limitsExpanded ? providers : Array(providers.prefix(Self.collapsedProviders))
                ForEach(shown) { p in
                    LimitWindowsView(provider: p, tint: stageColor)
                }
                if providers.count > Self.collapsedProviders {
                    ShowMoreButton(expanded: $limitsExpanded, hidden: providers.count - shown.count)
                }
            }
        }
    }

    // MARK: - Derived

    private var fullness: Double {
        guard let last = careState.lastFedAt else { return 0.5 }
        let hours = Date().timeIntervalSince(last) / 3600
        return max(0, min(1, 1 - hours / 48))
    }

    private func mealText(_ meals: Int) -> String {
        meals == 1
            ? NSLocalizedString("1 meal", comment: "")
            : String(format: NSLocalizedString("%d meals", comment: ""), meals)
    }

    private func streakValue(_ s: PetCareState) -> String {
        "\(s.streakDays)"
    }
}

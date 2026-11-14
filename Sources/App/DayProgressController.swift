// Sources/App/DayProgressController.swift
import Foundation
import AppKit
import AgentPetCore

/// Drives live Day Progress calculation, hourly chimes, and day segmentation.
@MainActor
public final class DayProgressController: ObservableObject {
    public static let shared = DayProgressController()

    @Published public var config: DayProgressConfig {
        didSet {
            saveConfig()
            updateSnapshot()
        }
    }

    @Published public private(set) var currentSnapshot: DayProgressSnapshot
    @Published public var isChimeBubbleVisible: Bool = false

    private var ticker: Timer?
    private var autoDismissTimer: Timer?
    private var lastChimedHour: Int = -1
    private let storeKey = "agentpet.day_progress_config"

    private init() {
        let defaults = UserDefaults.standard
        let initialConfig: DayProgressConfig
        if let data = defaults.data(forKey: "agentpet.day_progress_config"),
           let loaded = try? JSONDecoder().decode(DayProgressConfig.self, from: data) {
            initialConfig = loaded
        } else {
            initialConfig = DayProgressConfig()
        }

        self.config = initialConfig
        self.currentSnapshot = DayProgressSnapshot(config: initialConfig)
        self.lastChimedHour = Calendar.current.component(.hour, from: Date())
        startTicker()
    }

    public func startTicker() {
        ticker?.invalidate()
        let t = Timer(timeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.ticker = t
        updateSnapshot()
    }

    private func tick() {
        let now = Date()
        updateSnapshot(now)

        guard config.enabled && config.hourlyNotificationEnabled else { return }

        let currentHour = Calendar.current.component(.hour, from: now)
        let currentMinute = Calendar.current.component(.minute, from: now)

        // Trigger right at the start of a new hour (first 5 minutes of the hour)
        if currentHour != lastChimedHour && currentMinute <= 5 {
            lastChimedHour = currentHour
            showChime()
        }
    }

    public func updateSnapshot(_ date: Date = Date()) {
        self.currentSnapshot = DayProgressSnapshot(date: date, config: config)
    }

    public func showChime() {
        updateSnapshot()
        isChimeBubbleVisible = true

        autoDismissTimer?.invalidate()
        if config.autoDismissSeconds > 0 {
            autoDismissTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(config.autoDismissSeconds), repeats: false) { _ in
                Task { @MainActor [weak self] in
                    self?.isChimeBubbleVisible = false
                }
            }
        }
    }

    public func dismiss() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        isChimeBubbleVisible = false
    }

    public func updateSleepHour(_ hour: Int) {
        config.sleepHour = max(0, min(23, hour))
        config.sections = DayProgressConfig.defaultSections(wakeHour: config.wakeHour, sleepHour: config.sleepHour)
        saveConfig()
        updateSnapshot()
    }

    public func updateWakeHour(_ hour: Int) {
        config.wakeHour = max(0, min(23, hour))
        config.sections = DayProgressConfig.defaultSections(wakeHour: config.wakeHour, sleepHour: config.sleepHour)
        saveConfig()
        updateSnapshot()
    }

    private func saveConfig() {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: storeKey)
        }
    }
}

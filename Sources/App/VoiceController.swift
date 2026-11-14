// Sources/App/VoiceController.swift
import Foundation
import AppKit
import AVFoundation
import AgentPetCore

public struct VoiceOption: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let language: String
    public let quality: String

    public var displayName: String {
        "\(name) (\(language))"
    }
}

/// Manages native macOS text-to-speech verbal announcements using AVSpeechSynthesizer.
@MainActor
public final class VoiceController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = VoiceController()

    @Published public private(set) var isSpeaking: Bool = false
    @Published public var config: VoiceConfig {
        didSet {
            saveConfig()
        }
    }
    @Published public private(set) var availableVoices: [VoiceOption] = []

    private let synthesizer = AVSpeechSynthesizer()
    private let storeKey = "agentpet.voice_config"

    private override init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "agentpet.voice_config"),
           let loaded = try? JSONDecoder().decode(VoiceConfig.self, from: data) {
            self.config = loaded
        } else {
            self.config = VoiceConfig()
        }

        super.init()
        synthesizer.delegate = self
        loadAvailableVoices()
    }

    private func loadAvailableVoices() {
        let systemVoices = AVSpeechSynthesisVoice.speechVoices()
        // Filter primarily English and localized voices for pleasant output
        let options = systemVoices
            .filter { $0.language.starts(with: "en") || $0.language.starts(with: "kn") || $0.language.starts(with: "hi") }
            .map { v in
                VoiceOption(
                    id: v.identifier,
                    name: v.name,
                    language: v.language,
                    quality: v.quality == .enhanced ? "Enhanced" : "Standard"
                )
            }
            .sorted { $0.name < $1.name }

        self.availableVoices = options
    }

    public func toggleMaster() {
        config.masterEnabled.toggle()
        if !config.masterEnabled {
            stop()
        }
    }

    public func toggleItem(_ item: VoiceSpeechItem) {
        if config.enabledItems.contains(item) {
            config.enabledItems.remove(item)
        } else {
            config.enabledItems.insert(item)
        }
    }

    public func isItemEnabled(_ item: VoiceSpeechItem) -> Bool {
        config.enabledItems.contains(item)
    }

    public func setVoice(identifier: String) {
        config.selectedVoiceIdentifier = identifier
    }

    public func setRate(_ rate: Float) {
        config.speechRate = max(0.1, min(1.0, rate))
    }

    public func setVolume(_ volume: Float) {
        config.volume = max(0.0, min(1.0, volume))
    }

    /// Primary utterance dispatcher.
    public func speak(_ text: String, for item: VoiceSpeechItem? = nil, force: Bool = false) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // If not forced test, enforce master toggle and item enablement
        if !force {
            guard config.masterEnabled else { return }
            if let item = item {
                guard config.enabledItems.contains(item) else { return }
            }
        }

        let utterance = AVSpeechUtterance(string: text)

        // Select voice
        if !config.selectedVoiceIdentifier.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: config.selectedVoiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        // Apply rate: AVSpeechUtteranceDefaultSpeechRate is ~0.5
        let mappedRate = AVSpeechUtteranceMinimumSpeechRate + (config.speechRate * (AVSpeechUtteranceDefaultSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * 1.5)
        utterance.rate = max(AVSpeechUtteranceMinimumSpeechRate, min(AVSpeechUtteranceMaximumSpeechRate, mappedRate))
        utterance.volume = config.volume
        utterance.pitchMultiplier = 1.0

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    public func testSpeech(item: VoiceSpeechItem) {
        speak(item.testPhrase, for: item, force: true)
    }

    // MARK: - Specialized Verbal Communicator Intakes

    public func speakQuote(_ quote: QuoteItem) {
        guard config.masterEnabled && isItemEnabled(.quotes) else { return }

        // For Sanskrit or Kannada, prioritize speaking the English meaning or transliteration cleanly
        let cleanText: String
        if quote.category == .shloka || quote.category == .kannada {
            if !quote.authorOrMeaning.isEmpty {
                cleanText = "Wisdom note: \(quote.authorOrMeaning)"
            } else {
                cleanText = "Shloka: \(quote.text)"
            }
        } else {
            cleanText = "Quote: “\(quote.text)”\(quote.authorOrMeaning.isEmpty ? "" : " by \(quote.authorOrMeaning)")"
        }

        speak(cleanText, for: .quotes)
    }

    public func speakAgentCompletion(agent: String, project: String, line: String) {
        guard config.masterEnabled && isItemEnabled(.agentCompletion) else { return }
        let text = "\(agent) completed task on \(project). \(line.isEmpty ? "All done!" : line)"
        speak(text, for: .agentCompletion)
    }

    public func speakHourlyChime(snapshot: DayProgressSnapshot) {
        guard config.masterEnabled && isItemEnabled(.hourlyChime) else { return }
        let percent = Int(snapshot.percentPassed * 100)
        let hoursLeft = Int(snapshot.remainingHoursInDay)
        let text = "It is \(snapshot.currentTimeFormatted). \(percent) percent of your day has passed, with \(hoursLeft) hours remaining."
        speak(text, for: .hourlyChime)
    }

    public func speakReminder(title: String, isWater: Bool) {
        let item: VoiceSpeechItem = isWater ? .waterReminder : .customReminder
        guard config.masterEnabled && isItemEnabled(item) else { return }

        let text = isWater
            ? "Hydration check: Time to drink a glass of fresh water and stay focused."
            : "Reminder: \(title)."
        speak(text, for: item)
    }

    public func speakBreak(message: String) {
        guard config.masterEnabled && isItemEnabled(.breakReminder) else { return }
        let text = "Break reminder: \(message.isEmpty ? "Take a 2-minute break to rest your eyes and stretch." : message)"
        speak(text, for: .breakReminder)
    }

    public func speakFocusPhase(phase: PomodoroPhase) {
        guard config.masterEnabled && isItemEnabled(.focusPhase) else { return }
        let text: String
        switch phase {
        case .focus:
            text = "Focus session started. Silence distractions and dive in."
        case .shortBreak:
            text = "Focus session complete. Time for a refreshing 5-minute break."
        case .longBreak:
            text = "Cycle complete. Enjoy your extended restorative break."
        case .idle:
            text = "Focus timer reset to standby."
        }
        speak(text, for: .focusPhase)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }
}

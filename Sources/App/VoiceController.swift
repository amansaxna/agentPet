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
    public let isEnhancedOrNatural: Bool

    public var displayName: String {
        if isEnhancedOrNatural {
            return "✨ \(name) (\(language)) [\(quality)]"
        }
        return "\(name) (\(language))"
    }
}

/// Manages frontier neural models (Gemini, ChatGPT) and native macOS speech synthesis.
@MainActor
public final class VoiceController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    public static let shared = VoiceController()

    @Published public private(set) var isSpeaking: Bool = false
    @Published public private(set) var isFetchingFrontier: Bool = false
    @Published public private(set) var lastErrorMessage: String? = nil
    @Published public var config: VoiceConfig {
        didSet {
            saveConfig()
        }
    }
    @Published public private(set) var availableVoices: [VoiceOption] = []

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private let storeKey = "agentpet.voice_config"

    // Frontier Voice Presets
    public static let geminiVoices: [(id: String, name: String, desc: String)] = [
        ("Aoede", "Aoede", "Warm, expressive, natural, and engaging (Recommended)"),
        ("Kore", "Kore", "Soothing, gentle, calm, and conversational"),
        ("Puck", "Puck", "Playful, bright, dynamic, and upbeat"),
        ("Charon", "Charon", "Deep, resonant, authoritative, and steady"),
        ("Fenrir", "Fenrir", "Crisp, clear, direct, and energetic")
    ]

    public static let openaiVoices: [(id: String, name: String, desc: String)] = [
        ("nova", "Nova", "Warm, energetic, and engaging (ChatGPT Default Favorite)"),
        ("shimmer", "Shimmer", "Clear, expressive, bright, and cheerful"),
        ("alloy", "Alloy", "Balanced, neutral, and clear"),
        ("echo", "Echo", "Smooth, well-rounded, and natural"),
        ("fable", "Fable", "Expressive, storytelling with British cadence"),
        ("onyx", "Onyx", "Deep, confident, and resonant")
    ]

    public static let elevenlabsVoices: [(id: String, name: String, desc: String)] = [
        ("21m00Tcm4TlvDq8ikWAM", "Rachel", "Calm, professional, natural American voice"),
        ("AZnzlk1XvdvUeBnXmlld", "Domi", "Energetic, clear, and friendly"),
        ("EXAVITQu4vr4xnSDxMaL", "Bella", "Expressive, warm, and highly engaging"),
        ("ErXwobaYiN019PkySvjV", "Antoni", "Smooth, pleasant, and articulate")
    ]

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
        let options = systemVoices
            .filter { $0.language.starts(with: "en") || $0.language.starts(with: "kn") || $0.language.starts(with: "hi") }
            .map { v -> VoiceOption in
                let isNatural = v.quality == .enhanced || v.identifier.contains("siri")
                let qualityLabel: String
                if v.quality == .enhanced {
                    qualityLabel = "Enhanced Neural"
                } else if v.identifier.contains("siri") {
                    qualityLabel = "Siri Natural"
                } else {
                    qualityLabel = "Standard"
                }
                return VoiceOption(
                    id: v.identifier,
                    name: v.name,
                    language: v.language,
                    quality: qualityLabel,
                    isEnhancedOrNatural: isNatural
                )
            }
            .sorted { (a, b) in
                if a.isEnhancedOrNatural != b.isEnhancedOrNatural {
                    return a.isEnhancedOrNatural && !b.isEnhancedOrNatural
                }
                return a.name < b.name
            }

        self.availableVoices = options

        if config.selectedVoiceIdentifier.isEmpty,
           let naturalVoice = options.first(where: { $0.isEnhancedOrNatural }) {
            config.selectedVoiceIdentifier = naturalVoice.id
        }
    }

    public func openMacOSVoiceSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?SpokenContent") {
            NSWorkspace.shared.open(url)
        }
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

    /// Primary utterance dispatcher with frontier model support and offline fallback.
    public func speak(_ text: String, for item: VoiceSpeechItem? = nil, force: Bool = false) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if !force {
            guard config.masterEnabled else { return }
            if let item = item {
                guard config.enabledItems.contains(item) else { return }
            }
        }

        stop()
        lastErrorMessage = nil

        // If frontier provider is active, use high-fidelity neural audio
        if config.provider.isFrontier {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isFetchingFrontier = true
                do {
                    let audioData = try await FrontierVoiceService.shared.fetchAudio(text: text, config: self.config)
                    self.isFetchingFrontier = false
                    self.playAudioData(audioData)
                } catch {
                    self.isFetchingFrontier = false
                    self.lastErrorMessage = error.localizedDescription
                    // Fall back cleanly to system TTS so announcement is never lost
                    self.speakWithSystemSynthesizer(text: text)
                }
            }
        } else {
            speakWithSystemSynthesizer(text: text)
        }
    }

    private func playAudioData(_ data: Data) {
        do {
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.volume = config.volume
            player.prepareToPlay()
            self.audioPlayer = player
            self.isSpeaking = true
            player.play()
        } catch {
            lastErrorMessage = "Audio player error: \(error.localizedDescription)"
            speakWithSystemSynthesizer(text: "")
        }
    }

    private func speakWithSystemSynthesizer(text: String) {
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)

        if !config.selectedVoiceIdentifier.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: config.selectedVoiceIdentifier) {
            utterance.voice = voice
        } else if let best = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.quality == .enhanced || $0.identifier.contains("siri") }) {
            utterance.voice = best
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        let mappedRate = AVSpeechUtteranceMinimumSpeechRate + (config.speechRate * (AVSpeechUtteranceDefaultSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * 1.5)
        utterance.rate = max(AVSpeechUtteranceMinimumSpeechRate, min(AVSpeechUtteranceMaximumSpeechRate, mappedRate))
        utterance.volume = config.volume

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if let player = audioPlayer, player.isPlaying {
            player.stop()
        }
        audioPlayer = nil
        isSpeaking = false
        isFetchingFrontier = false
    }

    public func testSpeech(item: VoiceSpeechItem) {
        speak(item.testPhrase, for: item, force: true)
    }

    // MARK: - Specialized Verbal Communicator Intakes

    public func speakQuote(_ quote: QuoteItem) {
        guard config.masterEnabled && isItemEnabled(.quotes) else { return }

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

    // MARK: - Delegates

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isSpeaking = false
            self.audioPlayer = nil
        }
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }
}

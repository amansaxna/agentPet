// Sources/AgentPetCore/VoiceEngine.swift
import Foundation

/// Voice generation backends: Frontier AI models (Gemini, OpenAI ChatGPT, ElevenLabs) or native offline system.
public enum VoiceProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case gemini
    case openai
    case elevenlabs
    case system

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gemini:
            return "Google Gemini Neural (100% Free Tier · 1,500 req/day)"
        case .openai:
            return "OpenAI ChatGPT Voice (Nova / Shimmer / Alloy)"
        case .elevenlabs:
            return "ElevenLabs Studio Voice (Free Tier: 10,000 chars/mo)"
        case .system:
            return "Apple Siri / Enhanced Neural (100% Free · Offline)"
        }
    }

    public var shortName: String {
        switch self {
        case .gemini: return "Gemini"
        case .openai: return "ChatGPT"
        case .elevenlabs: return "ElevenLabs"
        case .system: return "Apple System"
        }
    }

    public var isFrontier: Bool {
        self != .system
    }
}

/// Specific notification categories that can produce spoken verbal announcements.
public enum VoiceSpeechItem: String, Codable, CaseIterable, Identifiable, Sendable {
    case quotes
    case agentCompletion
    case hourlyChime
    case waterReminder
    case breakReminder
    case focusPhase
    case customReminder

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .quotes:
            return "Quotes & Shlokas"
        case .agentCompletion:
            return "Agentic Work Completion"
        case .hourlyChime:
            return "Hourly Day Progress & Chime"
        case .waterReminder:
            return "Water & Hydration Reminders"
        case .breakReminder:
            return "Break & Rest Reminders"
        case .focusPhase:
            return "Pomodoro & Focus Phase Changes"
        case .customReminder:
            return "Custom Scheduled Reminders"
        }
    }

    public var description: String {
        switch self {
        case .quotes:
            return "Reads rotating quotes, mantras, or Sanskrit and Kannada shlokas aloud."
        case .agentCompletion:
            return "Announces when an AI coding agent (Claude, Codex, Antigravity) finishes a task."
        case .hourlyChime:
            return "Speaks the current hour, elapsed percentage of the day, and bedtime proximity."
        case .waterReminder:
            return "Reminds you verbally to take a sip of water and stay hydrated."
        case .breakReminder:
            return "Alerts you verbally when continuous screen time reaches the rest threshold."
        case .focusPhase:
            return "Announces focus interval start, break commencement, and session transitions."
        case .customReminder:
            return "Speaks out user-scheduled tasks and milestone deadlines when they fall due."
        }
    }

    public var icon: String {
        switch self {
        case .quotes:
            return "quote.bubble.fill"
        case .agentCompletion:
            return "checkmark.seal.fill"
        case .hourlyChime:
            return "clock.badge.checkmark"
        case .waterReminder:
            return "drop.fill"
        case .breakReminder:
            return "cup.and.saucer.fill"
        case .focusPhase:
            return "timer"
        case .customReminder:
            return "bell.badge.fill"
        }
    }

    public var testPhrase: String {
        switch self {
        case .quotes:
            return "Wisdom for today: Work is worship. Dedicated and honest labor is the highest path to divinity."
        case .agentCompletion:
            return "Antigravity completed task in LogViewer. Base camp reached, all tests passed."
        case .hourlyChime:
            return "It is 11:00 PM. 95% of your day has passed. Bedtime marker has been reached."
        case .waterReminder:
            return "Hydration reminder: Time to take a drink of water and stay energized."
        case .breakReminder:
            return "Rest reminder: Please step away from the screen for 2 minutes to rest your eyes."
        case .focusPhase:
            return "Focus block completed. Outstanding effort! Time for a 5-minute break."
        case .customReminder:
            return "Scheduled reminder: Engineering Mathematics PYQ practice session is due now."
        }
    }
}

/// User configuration for the verbal agent.
public struct VoiceConfig: Codable, Equatable, Sendable {
    public var masterEnabled: Bool
    public var provider: VoiceProvider
    public var selectedVoiceIdentifier: String
    public var speechRate: Float
    public var volume: Float
    public var enabledItems: Set<VoiceSpeechItem>

    // Frontier Neural Voice Keys
    public var geminiApiKey: String
    public var openaiApiKey: String
    public var elevenlabsApiKey: String

    // Frontier Model Selections
    public var geminiVoice: String
    public var openaiVoice: String
    public var elevenlabsVoiceId: String

    public init(
        masterEnabled: Bool = false,
        provider: VoiceProvider = .gemini,
        selectedVoiceIdentifier: String = "",
        speechRate: Float = 0.5,
        volume: Float = 0.85,
        enabledItems: Set<VoiceSpeechItem> = [.agentCompletion, .quotes],
        geminiApiKey: String = "",
        openaiApiKey: String = "",
        elevenlabsApiKey: String = "",
        geminiVoice: String = "Aoede",
        openaiVoice: String = "nova",
        elevenlabsVoiceId: String = "21m00Tcm4TlvDq8ikWAM"
    ) {
        self.masterEnabled = masterEnabled
        self.provider = provider
        self.selectedVoiceIdentifier = selectedVoiceIdentifier
        self.speechRate = speechRate
        self.volume = max(0.0, min(1.0, volume))
        self.enabledItems = enabledItems
        self.geminiApiKey = geminiApiKey
        self.openaiApiKey = openaiApiKey
        self.elevenlabsApiKey = elevenlabsApiKey
        self.geminiVoice = geminiVoice
        self.openaiVoice = openaiVoice
        self.elevenlabsVoiceId = elevenlabsVoiceId
    }
}

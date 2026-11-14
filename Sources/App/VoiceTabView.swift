// Sources/App/VoiceTabView.swift
import SwiftUI
import AgentPetCore

/// Settings tab for Frontier Neural Models (Gemini, ChatGPT) & Verbal Communicator.
struct VoiceTabView: View {
    @ObservedObject private var voice = VoiceController.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                masterSwitchCard
                providerSelectionCard
                frontierVoiceCard
                apiKeyCard
                audioAttributesCard
                notificationItemsCard
            }
            .padding(20)
        }
    }

    // MARK: - 1. Master Verbal Communicator Switch

    private var masterSwitchCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: voice.config.masterEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(voice.config.masterEnabled ? Color.green : Theme.muted)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Verbal Communicator")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)

                            if voice.config.provider.isFrontier {
                                Text("FRONTIER NEURAL")
                                    .font(.system(size: 8.5, weight: .black))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.purple.opacity(0.3)))
                                    .foregroundStyle(Color.purple)
                            }
                        }

                        Text(voice.config.masterEnabled ? "Active — Speaks designated notification items via \(voice.config.provider.shortName)" : "Muted — All verbal speech is disabled")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }

                Spacer()

                if voice.isSpeaking || voice.isFetchingFrontier {
                    Button {
                        voice.stop()
                    } label: {
                        HStack(spacing: 4) {
                            if voice.isFetchingFrontier {
                                ProgressView().controlSize(.mini)
                            }
                            Image(systemName: "stop.fill")
                            Text("Stop Voice")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.red.opacity(0.85)))
                    }
                    .buttonStyle(.plain)
                }

                Toggle("", isOn: $voice.config.masterEnabled)
                    .toggleStyle(.switch)
            }

            if let err = voice.lastErrorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
                    Text(err).font(.caption).foregroundStyle(.orange).lineLimit(2)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.12)))
            }
        }
        .themedCard()
    }

    // MARK: - 2. Provider Selection

    private var providerSelectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel("VOICE SYNTHESIS ENGINE (FRONTIER AI OR OFFLINE)")

            Picker("", selection: $voice.config.provider) {
                ForEach(VoiceProvider.allCases) { prov in
                    Text(prov.displayName).tag(prov)
                }
            }
            .pickerStyle(.radioGroup)
            .padding(.vertical, 2)

            Text(providerDescription(voice.config.provider))
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .themedCard()
        .disabled(!voice.config.masterEnabled)
        .opacity(voice.config.masterEnabled ? 1.0 : 0.6)
    }

    // MARK: - 3. Frontier Voice Model Selection

    private var frontierVoiceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch voice.config.provider {
            case .gemini:
                EyebrowLabel("GOOGLE GEMINI NEURAL VOICE PRESETS")
                VStack(spacing: 6) {
                    ForEach(VoiceController.geminiVoices, id: \.id) { v in
                        frontierVoiceRow(id: v.id, name: v.name, desc: v.desc, isSelected: voice.config.geminiVoice == v.id) {
                            voice.config.geminiVoice = v.id
                        }
                    }
                }

            case .openai:
                EyebrowLabel("OPENAI CHATGPT NEURAL VOICE PRESETS")
                VStack(spacing: 6) {
                    ForEach(VoiceController.openaiVoices, id: \.id) { v in
                        frontierVoiceRow(id: v.id, name: v.name, desc: v.desc, isSelected: voice.config.openaiVoice == v.id) {
                            voice.config.openaiVoice = v.id
                        }
                    }
                }

            case .elevenlabs:
                EyebrowLabel("ELEVENLABS STUDIO VOICE PRESETS")
                VStack(spacing: 6) {
                    ForEach(VoiceController.elevenlabsVoices, id: \.id) { v in
                        frontierVoiceRow(id: v.id, name: v.name, desc: v.desc, isSelected: voice.config.elevenlabsVoiceId == v.id) {
                            voice.config.elevenlabsVoiceId = v.id
                        }
                    }
                }

            case .system:
                EyebrowLabel("APPLE SYSTEM & ENHANCED VOICES")
                HStack {
                    Text("System Voice:")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                    Spacer()
                    Picker("", selection: $voice.config.selectedVoiceIdentifier) {
                        ForEach(voice.availableVoices) { v in
                            Text(v.displayName).tag(v.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 280)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Theme.accent)
                        Text("Want realistic human voices for free offline?")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text("macOS includes free Neural & Enhanced voices (Ava, Zoe, Siri Natural) that sound far more realistic than default robotic voices. You can download them in 1-click inside macOS System Settings.")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)

                    Button {
                        voice.openMacOSVoiceSettings()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Open macOS Settings → Download Free Neural Voices")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
            }
        }
        .themedCard()
        .disabled(!voice.config.masterEnabled)
        .opacity(voice.config.masterEnabled ? 1.0 : 0.6)
    }

    private func frontierVoiceRow(id: String, name: String, desc: String, isSelected: Bool, onSelect: @escaping () -> Void) -> some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.accent : Theme.muted)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                    Text(desc)
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                if isSelected {
                    Text("Active")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.accent.opacity(0.2)))
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? Theme.accent.opacity(0.12) : Color.white.opacity(0.02)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isSelected ? Theme.accent.opacity(0.4) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 4. API Key Configuration

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel("FRONTIER MODEL API CREDENTIALS")

            switch voice.config.provider {
            case .gemini:
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Google Gemini API Key:")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundStyle(.white)

                                Text("100% FREE TIER")
                                    .font(.system(size: 8.5, weight: .black))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.green.opacity(0.25)))
                                    .foregroundStyle(Color.green)
                            }
                            Text("1,500 free requests per day · Zero credit card required")
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)
                        }

                        Spacer()

                        Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "key.fill")
                                Text("Get Free Key (1-Click) ↗")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.accent))
                        }
                    }

                    SecureField("Paste your Gemini API key (AIzaSy...)", text: $voice.config.geminiApiKey)
                        .textFieldStyle(.roundedBorder)

                    if voice.config.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.cyan)
                            Text("To hear the cutting-edge Gemini voice (Aoede, Kore, Puck) for free, tap 'Get Free Key', sign in with Google, copy your key, and paste it here.")
                                .font(.caption2)
                                .foregroundStyle(.cyan.opacity(0.9))
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.cyan.opacity(0.1)))
                    }
                }

            case .openai:
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("OpenAI API Key:")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Link("Get OpenAI Key ↗", destination: URL(string: "https://platform.openai.com/api-keys")!)
                            .font(.caption)
                    }

                    SecureField("Paste your OpenAI API key (sk-...)", text: $voice.config.openaiApiKey)
                        .textFieldStyle(.roundedBorder)

                    Text("Uses OpenAI tts-1 model for the natural voice used in ChatGPT Voice Mode.")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }

            case .elevenlabs:
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("ElevenLabs API Key:")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Link("Get ElevenLabs Key ↗", destination: URL(string: "https://elevenlabs.io")!)
                            .font(.caption)
                    }

                    SecureField("Paste your ElevenLabs API key", text: $voice.config.elevenlabsApiKey)
                        .textFieldStyle(.roundedBorder)
                }

            case .system:
                Text("Offline Apple speech synthesizers require no API keys.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .themedCard()
        .disabled(!voice.config.masterEnabled)
        .opacity(voice.config.masterEnabled ? 1.0 : 0.6)
    }

    // MARK: - 5. Audio Attributes

    private var audioAttributesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel("AUDIO VOLUME")

            HStack {
                Text("Volume:")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(voice.config.volume * 100))%")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.muted)
            }

            Slider(value: $voice.config.volume, in: 0.0...1.0, step: 0.05)
                .tint(Theme.accent)
        }
        .themedCard()
        .disabled(!voice.config.masterEnabled)
        .opacity(voice.config.masterEnabled ? 1.0 : 0.6)
    }

    // MARK: - 6. Notification Items

    private var notificationItemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EyebrowLabel("SPEECH NOTIFICATION TRIGGERS (OPT-IN)")
                Spacer()
                Text("\(voice.config.enabledItems.count) of \(VoiceSpeechItem.allCases.count) enabled")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }

            VStack(spacing: 10) {
                ForEach(VoiceSpeechItem.allCases) { item in
                    speechItemRow(item)
                }
            }
        }
        .themedCard()
        .disabled(!voice.config.masterEnabled)
        .opacity(voice.config.masterEnabled ? 1.0 : 0.6)
    }

    private func speechItemRow(_ item: VoiceSpeechItem) -> some View {
        let isEnabled = voice.isItemEnabled(item)

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 14))
                .foregroundStyle(isEnabled ? Theme.accent : Theme.muted)
                .frame(width: 22, height: 22)
                .background(Circle().fill(isEnabled ? Theme.accent.opacity(0.18) : Color.white.opacity(0.04)))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    // Test Voice preview button
                    Button {
                        voice.testSpeech(item: item)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "play.fill").font(.system(size: 8))
                            Text("Test Voice").font(.system(size: 10.5, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Listen to a sample preview phrase using the chosen voice model")

                    Toggle("", isOn: Binding(
                        get: { voice.isItemEnabled(item) },
                        set: { _ in voice.toggleItem(item) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(isEnabled ? 0.04 : 0.02)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isEnabled ? Theme.accent.opacity(0.3) : Theme.cardStroke, lineWidth: 1))
    }

    private func providerDescription(_ prov: VoiceProvider) -> String {
        switch prov {
        case .gemini:
            return "Google Gemini Flash Audio produces rich, warm, dynamic human speech with authentic inflection."
        case .openai:
            return "OpenAI ChatGPT Speech models (tts-1) generate the warm, conversational voice heard in ChatGPT."
        case .elevenlabs:
            return "ElevenLabs creates ultra-realistic studio quality voices with hyper-nuanced intonation."
        case .system:
            return "Uses Apple's built-in offline speech synthesizer with zero latency and zero network access."
        }
    }
}

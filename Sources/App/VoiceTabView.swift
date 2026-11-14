// Sources/App/VoiceTabView.swift
import SwiftUI
import AgentPetCore

/// Dedicated settings tab for Text-to-Voice Verbal Communicator.
struct VoiceTabView: View {
    @ObservedObject private var voice = VoiceController.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                masterSwitchCard
                voiceAttributesCard
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
                        Text("Verbal Communicator")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)

                        Text(voice.config.masterEnabled ? "Active — Speaks designated notification items" : "Muted — All verbal speech is disabled")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }

                Spacer()

                if voice.isSpeaking {
                    Button {
                        voice.stop()
                    } label: {
                        HStack(spacing: 4) {
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
        }
        .themedCard()
    }

    // MARK: - 2. Voice & Tone Controls

    private var voiceAttributesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel("VOICE SELECTION & ATTRIBUTES")

            // Voice selection
            HStack {
                Text("Voice Model:")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)

                Spacer()

                if voice.availableVoices.isEmpty {
                    Text("System Default").font(.system(size: 12)).foregroundStyle(Theme.muted)
                } else {
                    Picker("", selection: $voice.config.selectedVoiceIdentifier) {
                        Text("System Recommended Voice").tag("")
                        ForEach(voice.availableVoices) { v in
                            Text("\(v.name) (\(v.language)) · \(v.quality)").tag(v.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 260)
                }
            }

            Divider().overlay(Theme.cardStroke)

            // Speed / Rate slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Speaking Pace:")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(rateLabel(voice.config.speechRate))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                }

                Slider(value: $voice.config.speechRate, in: 0.1...1.0, step: 0.05)
                    .tint(Theme.accent)
            }

            Divider().overlay(Theme.cardStroke)

            // Volume slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Speech Volume:")
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
        }
        .themedCard()
        .disabled(!voice.config.masterEnabled)
        .opacity(voice.config.masterEnabled ? 1.0 : 0.6)
    }

    // MARK: - 3. Granular Notification Speech Items

    private var notificationItemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EyebrowLabel("GRANULAR SPEECH NOTIFICATIONS (OPT-IN)")
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
                    .help("Listen to a sample preview phrase for this notification")

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

    private func rateLabel(_ rate: Float) -> String {
        if rate < 0.35 { return "Slow" }
        if rate < 0.65 { return "Normal" }
        if rate < 0.85 { return "Fast" }
        return "Very Fast"
    }
}

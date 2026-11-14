// Sources/AgentPetCore/FrontierVoiceService.swift
import Foundation
import CommonCrypto

/// Asynchronously fetches frontier neural speech audio from Gemini, OpenAI ChatGPT, and ElevenLabs.
public final class FrontierVoiceService: @unchecked Sendable {
    public static let shared = FrontierVoiceService()

    private let cacheDir: URL

    private init() {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("agentpet_voice_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        self.cacheDir = temp
    }

    /// Fetches audio data (MP3/WAV) for given text and configuration.
    public func fetchAudio(text: String, config: VoiceConfig) async throws -> Data {
        let cacheKey = hashKey(text: text, provider: config.provider, voice: currentVoice(for: config))
        let cachedFile = cacheDir.appendingPathComponent("\(cacheKey).audio")

        if let cached = try? Data(contentsOf: cachedFile), !cached.isEmpty {
            return cached
        }

        let audioData: Data
        switch config.provider {
        case .gemini:
            audioData = try await fetchGeminiSpeech(text: text, voice: config.geminiVoice, apiKey: resolvedKey(config.geminiApiKey, env: "GEMINI_API_KEY"))
        case .openai:
            audioData = try await fetchOpenAISpeech(text: text, voice: config.openaiVoice, apiKey: resolvedKey(config.openaiApiKey, env: "OPENAI_API_KEY"))
        case .elevenlabs:
            audioData = try await fetchElevenLabsSpeech(text: text, voiceId: config.elevenlabsVoiceId, apiKey: resolvedKey(config.elevenlabsApiKey, env: "ELEVENLABS_API_KEY"))
        case .system:
            throw NSError(domain: "FrontierVoice", code: -1, userInfo: [NSLocalizedDescriptionKey: "System voice does not use frontier network audio"])
        }

        try? audioData.write(to: cachedFile)
        return audioData
    }

    // MARK: - 1. Google Gemini Neural TTS

    private func fetchGeminiSpeech(text: String, voice: String, apiKey: String) async throws -> Data {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GeminiVoice", code: 401, userInfo: [NSLocalizedDescriptionKey: "Gemini API Key is missing. Enter your key in Settings → Voice."])
        }

        let selectedVoice = voice.isEmpty ? "Aoede" : voice
        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=\(apiKey)")!

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": text]
                    ]
                ]
            ],
            "generationConfig": [
                "responseModalities": ["AUDIO"],
                "speechConfig": [
                    "voiceConfig": [
                        "prebuiltVoiceConfig": [
                            "voiceName": selectedVoice
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown HTTP error"
            throw NSError(domain: "GeminiVoice", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Gemini API error: \(errorMsg)"])
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let inlineData = firstPart["inlineData"] as? [String: Any],
              let base64 = inlineData["data"] as? String,
              let pcmData = Data(base64Encoded: base64) else {
            throw NSError(domain: "GeminiVoice", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse audio from Gemini response"])
        }

        let mimeType = inlineData["mimeType"] as? String ?? ""
        if mimeType.contains("L16") || mimeType.contains("pcm") || mimeType.isEmpty {
            let sampleRate = extractSampleRate(from: mimeType) ?? 24000
            return createWavData(pcmData: pcmData, sampleRate: sampleRate)
        }

        return pcmData
    }

    private func extractSampleRate(from mimeType: String) -> Int? {
        let parts = mimeType.components(separatedBy: ";")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "rate=") {
                let rateStr = trimmed.replacingOccurrences(of: "rate=", with: "")
                return Int(rateStr)
            }
        }
        return nil
    }

    private func createWavData(pcmData: Data, sampleRate: Int = 24000, channels: Int = 1, bitDepth: Int = 16) -> Data {
        var header = Data()
        let byteRate = sampleRate * channels * (bitDepth / 8)
        let blockAlign = channels * (bitDepth / 8)
        let subchunk2Size = pcmData.count
        let chunkSize = 36 + subchunk2Size

        header.append(contentsOf: "RIFF".utf8)
        var chunkSize32 = UInt32(chunkSize).littleEndian
        header.append(Data(bytes: &chunkSize32, count: 4))
        header.append(contentsOf: "WAVE".utf8)

        header.append(contentsOf: "fmt ".utf8)
        var subchunk1Size = UInt32(16).littleEndian
        header.append(Data(bytes: &subchunk1Size, count: 4))
        var audioFormat = UInt16(1).littleEndian
        header.append(Data(bytes: &audioFormat, count: 2))
        var numChannels = UInt16(channels).littleEndian
        header.append(Data(bytes: &numChannels, count: 2))
        var sampleRate32 = UInt32(sampleRate).littleEndian
        header.append(Data(bytes: &sampleRate32, count: 4))
        var byteRate32 = UInt32(byteRate).littleEndian
        header.append(Data(bytes: &byteRate32, count: 4))
        var blockAlign16 = UInt16(blockAlign).littleEndian
        header.append(Data(bytes: &blockAlign16, count: 2))
        var bitsPerSample = UInt16(bitDepth).littleEndian
        header.append(Data(bytes: &bitsPerSample, count: 2))

        header.append(contentsOf: "data".utf8)
        var subchunk2Size32 = UInt32(subchunk2Size).littleEndian
        header.append(Data(bytes: &subchunk2Size32, count: 4))

        return header + pcmData
    }

    // MARK: - 2. OpenAI ChatGPT Speech

    private func fetchOpenAISpeech(text: String, voice: String, apiKey: String) async throws -> Data {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "OpenAIVoice", code: 401, userInfo: [NSLocalizedDescriptionKey: "OpenAI API Key is missing. Enter your key in Settings → Voice."])
        }

        let selectedVoice = voice.isEmpty ? "nova" : voice.lowercased()
        let endpoint = URL(string: "https://api.openai.com/v1/audio/speech")!

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": selectedVoice,
            "response_format": "mp3"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown HTTP error"
            throw NSError(domain: "OpenAIVoice", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "OpenAI API error: \(errorMsg)"])
        }

        return data
    }

    // MARK: - 3. ElevenLabs Studio Speech

    private func fetchElevenLabsSpeech(text: String, voiceId: String, apiKey: String) async throws -> Data {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "ElevenLabsVoice", code: 401, userInfo: [NSLocalizedDescriptionKey: "ElevenLabs API Key is missing. Enter your key in Settings → Voice."])
        }

        let selectedId = voiceId.isEmpty ? "21m00Tcm4TlvDq8ikWAM" : voiceId
        let endpoint = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(selectedId)")!

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let payload: [String: Any] = [
            "text": text,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown HTTP error"
            throw NSError(domain: "ElevenLabsVoice", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "ElevenLabs API error: \(errorMsg)"])
        }

        return data
    }

    // MARK: - Helpers

    private func resolvedKey(_ configured: String, env: String) -> String {
        let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return ProcessInfo.processInfo.environment[env]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func currentVoice(for config: VoiceConfig) -> String {
        switch config.provider {
        case .gemini: return config.geminiVoice
        case .openai: return config.openaiVoice
        case .elevenlabs: return config.elevenlabsVoiceId
        case .system: return config.selectedVoiceIdentifier
        }
    }

    private func hashKey(text: String, provider: VoiceProvider, voice: String) -> String {
        let raw = "\(provider.rawValue):\(voice):\(text)"
        let data = Data(raw.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

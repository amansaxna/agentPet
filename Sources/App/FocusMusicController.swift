// Sources/App/FocusMusicController.swift
import Foundation
import AppKit
import AVFoundation
import AgentPetCore

/// Drives ambient focus music & soundscapes playback using AVPlayer.
@MainActor
public final class FocusMusicController: ObservableObject {
    public static let shared = FocusMusicController()

    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentStation: FocusMusicStation
    @Published public var volume: Float = 0.6 {
        didSet {
            player?.volume = volume
            config.volume = volume
            saveConfig()
        }
    }
    @Published public var config: FocusMusicConfig

    private var player: AVPlayer?
    private let storeKey = "agentpet.focus_music_config"

    private init() {
        let defaults = UserDefaults.standard
        let loadedConfig: FocusMusicConfig
        if let data = defaults.data(forKey: "agentpet.focus_music_config"),
           let loaded = try? JSONDecoder().decode(FocusMusicConfig.self, from: data) {
            loadedConfig = loaded
        } else {
            loadedConfig = FocusMusicConfig()
        }

        let initialStation = FocusMusicStation.stations.first(where: { $0.id == loadedConfig.selectedStationId })
            ?? FocusMusicStation.stations[0]

        self.config = loadedConfig
        self.currentStation = initialStation
        self.volume = loadedConfig.volume
    }

    public func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        guard let url = URL(string: currentStation.streamURL) else { return }

        if player == nil {
            let item = AVPlayerItem(url: url)
            let p = AVPlayer(playerItem: item)
            p.volume = volume
            self.player = p
        }

        player?.play()
        isPlaying = true

        PetController.shared.flashReactiveLine("Focus Music: \(currentStation.title) 🎵")
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func pause() {
        player?.pause()
        isPlaying = false
        PetController.shared.flashReactiveLine("Focus Music stopped ⏹")
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func stop() {
        pause()
        player = nil
    }

    public func selectStation(_ station: FocusMusicStation) {
        let wasPlaying = isPlaying
        if isPlaying {
            player?.pause()
            player = nil
        }
        self.currentStation = station
        self.config.selectedStationId = station.id
        saveConfig()

        if wasPlaying {
            play()
        } else {
            PetController.shared.flashReactiveLine("Selected: \(station.title) 🎧")
        }
    }

    public func nextStation() {
        let all = FocusMusicStation.stations
        guard let idx = all.firstIndex(where: { $0.id == currentStation.id }) else {
            selectStation(all[0])
            return
        }
        let nextIdx = (idx + 1) % all.count
        selectStation(all[nextIdx])
    }

    private func saveConfig() {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: storeKey)
        }
    }
}

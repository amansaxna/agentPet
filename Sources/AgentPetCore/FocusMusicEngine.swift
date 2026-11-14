// Sources/AgentPetCore/FocusMusicEngine.swift
import Foundation

/// Focus music soundscapes / streaming stations for deep work and study.
public struct FocusMusicStation: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let icon: String
    public let streamURL: String

    public init(id: String, title: String, description: String, icon: String, streamURL: String) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.streamURL = streamURL
    }

    /// Default curated high-uptime chill & ambient study streams.
    public static let stations: [FocusMusicStation] = [
        FocusMusicStation(
            id: "violin_classical",
            title: "Classical Violin & Strings",
            description: "Soothing violin concertos, sonatas & string ensembles",
            icon: "music.quarternote.3",
            streamURL: "https://stream.srg-ssr.ch/m/rsc_de/mp3_128"
        ),
        FocusMusicStation(
            id: "violin_acoustic",
            title: "Acoustic Violin & Fiddle",
            description: "Melodic Celtic & acoustic violin strings for focus",
            icon: "waveform",
            streamURL: "https://ice2.somafm.com/thistle-128-mp3"
        ),
        FocusMusicStation(
            id: "groove_salad",
            title: "Lofi & Downtempo Chill",
            description: "Ambient electronic & chill grooves for coding",
            icon: "headphones",
            streamURL: "https://ice2.somafm.com/groovesalad-128-mp3"
        ),
        FocusMusicStation(
            id: "drone_zone",
            title: "Deep Space Drone",
            description: "Atmospheric ambient for deep immersion",
            icon: "sparkles",
            streamURL: "https://ice2.somafm.com/dronezone-128-mp3"
        ),
        FocusMusicStation(
            id: "lush",
            title: "Lush Mellow Beats",
            description: "Sensuous acoustic & mellow electronica",
            icon: "leaf.fill",
            streamURL: "https://ice2.somafm.com/lush-128-mp3"
        ),
        FocusMusicStation(
            id: "defcon",
            title: "Cyberpunk Focus Chill",
            description: "Electronic study beats from DEF CON",
            icon: "waveform.path.ecg",
            streamURL: "https://ice2.somafm.com/defcon-128-mp3"
        ),
        FocusMusicStation(
            id: "space_station",
            title: "Space Station Soma",
            description: "Mid-tempo ambient electronica & space chill",
            icon: "moon.stars.fill",
            streamURL: "https://ice2.somafm.com/spacestation-128-mp3"
        )
    ]
}

/// Persistent user configuration for focus audio.
public struct FocusMusicConfig: Codable, Equatable, Sendable {
    public var selectedStationId: String
    public var volume: Float
    public var autoPlayOnFocus: Bool

    public init(
        selectedStationId: String = "groove_salad",
        volume: Float = 0.6,
        autoPlayOnFocus: Bool = false
    ) {
        self.selectedStationId = selectedStationId
        self.volume = max(0.0, min(1.0, volume))
        self.autoPlayOnFocus = autoPlayOnFocus
    }
}

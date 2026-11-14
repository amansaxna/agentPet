// Sources/App/QuoteController.swift
import Foundation
import AppKit
import AgentPetCore

/// Manages active quotes across the 7 categories, rotation schedules,
/// favorites, and custom quotes.
@MainActor
public final class QuoteController: ObservableObject {
    public static let shared = QuoteController()

    @Published public private(set) var currentQuote: QuoteItem
    @Published public private(set) var isDismissed: Bool = false
    @Published public private(set) var isFetchingLive: Bool = false
    @Published public var config: QuoteConfig {
        didSet {
            engine.config = config
            store.save(config: config, customQuotes: customQuotes, favorites: favorites)
            refreshCurrentQuote()
        }
    }
    @Published public private(set) var customQuotes: [QuoteItem] = []
    @Published public private(set) var favorites: Set<String> = []

    private let engine: QuoteEngine
    private let store = QuoteStore.shared
    private var rotationTimer: Timer?

    private init() {
        let snapshot = store.load()
        self.config = snapshot.config
        self.customQuotes = snapshot.customQuotes
        self.favorites = snapshot.favorites

        self.engine = QuoteEngine(
            config: snapshot.config,
            customQuotes: snapshot.customQuotes,
            favorites: snapshot.favorites
        )
        self.currentQuote = engine.quote()
        startRotationTimer()
    }

    public func startRotationTimer() {
        rotationTimer?.invalidate()
        let interval = TimeInterval(max(1, config.rotationMinutes) * 60)
        let t = Timer(timeInterval: interval, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.nextQuote()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.rotationTimer = t
    }

    public func nextQuote() {
        self.isDismissed = false

        // If live quotes from FavQs/ZenQuotes are enabled and category is enabled,
        // periodically fetch a live quote every few rotations.
        if config.fetchLiveQuotes && config.enabledCategories.contains(.api) && Int.random(in: 1...3) == 1 {
            Task { @MainActor [weak self] in
                await self?.fetchLiveQuote()
            }
            return
        }

        self.currentQuote = engine.nextQuote()
        PetController.shared.relocalize()
        VoiceController.shared.speakQuote(self.currentQuote)
    }

    /// Fetches a structured quote from FavQs API or ZenQuotes live and presents it.
    public func fetchLiveQuote() async {
        isFetchingLive = true
        defer { isFetchingLive = false }

        if let liveItem = await QuoteAPIService.shared.fetchLiveQuote() {
            self.isDismissed = false
            // Check if already in custom quotes; if not, store it so it enriches the library
            if !customQuotes.contains(where: { $0.text == liveItem.text }) {
                customQuotes.append(liveItem)
                _ = engine.addCustomQuote(text: liveItem.text, authorOrMeaning: liveItem.authorOrMeaning, category: liveItem.category)
                store.save(config: config, customQuotes: customQuotes, favorites: favorites)
            }
            self.currentQuote = liveItem
            PetController.shared.relocalize()
            PetController.shared.flashReactiveLine("FavQs Live Quote updated ✨")
            VoiceController.shared.speakQuote(liveItem)
        } else {
            self.currentQuote = engine.nextQuote()
            PetController.shared.relocalize()
            VoiceController.shared.speakQuote(self.currentQuote)
        }
    }

    public var allItems: [QuoteItem] {
        engine.allItems
    }

    public func selectQuote(_ item: QuoteItem) {
        self.currentQuote = item
        self.isDismissed = false
        PetController.shared.relocalize()
        PetController.shared.flashReactiveLine("Quote: \(item.category.displayName) ✨")
        VoiceController.shared.speakQuote(item)
    }

    public func dismiss() {
        self.isDismissed = true
        PetController.shared.update(sessions: AppDaemon.shared.sessions)
    }

    public func toggleFavorite(id: String) {
        _ = engine.toggleFavorite(id: id)
        self.favorites = engine.favorites
        if currentQuote.id == id {
            var copy = currentQuote
            copy.isFavorite = favorites.contains(id)
            self.currentQuote = copy
        }
        store.save(config: config, customQuotes: customQuotes, favorites: favorites)
    }

    public func addCustomQuote(text: String, authorOrMeaning: String, category: QuoteCategory) {
        let item = engine.addCustomQuote(text: text, authorOrMeaning: authorOrMeaning, category: category)
        self.customQuotes = engine.customQuotes
        store.save(config: config, customQuotes: customQuotes, favorites: favorites)
        self.currentQuote = item
    }

    public func deleteCustomQuote(id: String) {
        engine.deleteCustomQuote(id: id)
        self.customQuotes = engine.customQuotes
        self.favorites = engine.favorites
        store.save(config: config, customQuotes: customQuotes, favorites: favorites)
        refreshCurrentQuote()
    }

    public func toggleCategory(_ cat: QuoteCategory) {
        if config.enabledCategories.contains(cat) {
            if config.enabledCategories.count > 1 {
                config.enabledCategories.remove(cat)
            }
        } else {
            config.enabledCategories.insert(cat)
        }
    }

    private func refreshCurrentQuote() {
        self.currentQuote = engine.quote()
    }
}

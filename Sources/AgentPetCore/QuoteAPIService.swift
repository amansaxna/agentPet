// Sources/AgentPetCore/QuoteAPIService.swift
import Foundation

/// Structured response models for FavQs API
private struct FavQsResponse: Codable {
    struct QuotePayload: Codable {
        let id: Int
        let body: String
        let author: String
        let tags: [String]?
    }
    let quote: QuotePayload
}

/// Structured response models for ZenQuotes API
private struct ZenQuotePayload: Codable {
    let q: String
    let a: String
}

/// Service to fetch live, structured quotes from public APIs (FavQs / ZenQuotes).
public final class QuoteAPIService: Sendable {
    public static let shared = QuoteAPIService()

    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 8.0
        self.session = URLSession(configuration: config)
    }

    /// Fetches a daily or curated quote from FavQs API, falling back to ZenQuotes.
    public func fetchLiveQuote() async -> QuoteItem? {
        // 1. Try FavQs Quote of the Day
        if let item = await fetchFromFavQs() {
            return item
        }

        // 2. Fallback to ZenQuotes
        if let item = await fetchFromZenQuotes() {
            return item
        }

        return nil
    }

    private func fetchFromFavQs() async -> QuoteItem? {
        guard let url = URL(string: "https://favqs.com/api/qotd") else { return nil }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("AgentPet/1.17", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }

            let decoded = try JSONDecoder().decode(FavQsResponse.self, from: data)
            let q = decoded.quote
            let cleanText = q.body.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanAuthor = q.author.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanText.isEmpty else { return nil }

            return QuoteItem(
                id: "favqs-\(q.id)",
                text: cleanText,
                authorOrMeaning: cleanAuthor.isEmpty ? "FavQs Quote of the Day" : cleanAuthor,
                category: .api,
                isFavorite: false,
                isCustom: false
            )
        } catch {
            return nil
        }
    }

    private func fetchFromZenQuotes() async -> QuoteItem? {
        guard let url = URL(string: "https://zenquotes.io/api/random") else { return nil }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("AgentPet/1.17", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }

            let decoded = try JSONDecoder().decode([ZenQuotePayload].self, from: data)
            guard let first = decoded.first else { return nil }

            let cleanText = first.q.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanAuthor = first.a.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanText.isEmpty else { return nil }

            return QuoteItem(
                id: "zen-\(abs(cleanText.hashValue))",
                text: cleanText,
                authorOrMeaning: cleanAuthor.isEmpty ? "ZenQuotes Live" : cleanAuthor,
                category: .api,
                isFavorite: false,
                isCustom: false
            )
        } catch {
            return nil
        }
    }
}

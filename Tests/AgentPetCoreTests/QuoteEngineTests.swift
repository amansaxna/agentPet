// Tests/AgentPetCoreTests/QuoteEngineTests.swift
import XCTest
@testable import AgentPetCore

final class QuoteEngineTests: XCTestCase {

    func testCatalogContainsAtLeast8QuotesPerCategory() {
        for category in QuoteCategory.allCases {
            let matches = QuoteCatalog.items.filter { $0.category == category }
            XCTAssertGreaterThanOrEqual(
                matches.count,
                8,
                "Category \(category.rawValue) must have >= 8 items in QuoteCatalog"
            )
        }
    }

    func testCategoryFiltering() {
        let config = QuoteConfig(enabledCategories: [.gateExam, .idioms])
        let engine = QuoteEngine(config: config)
        let eligible = engine.eligibleItems

        XCTAssertFalse(eligible.isEmpty)
        for item in eligible {
            XCTAssertTrue(item.category == .gateExam || item.category == .idioms)
        }
    }

    func testFavoriteFiltering() {
        let sampleId = QuoteCatalog.items[0].id
        var config = QuoteConfig()
        config.onlyFavorites = true

        let engine = QuoteEngine(config: config, favorites: [sampleId])
        let eligible = engine.eligibleItems
        XCTAssertEqual(eligible.count, 1)
        XCTAssertEqual(eligible.first?.id, sampleId)
    }

    func testDeterministicQuoteSelection() {
        let engine = QuoteEngine()
        let t1 = Date(timeIntervalSince1970: 1000)
        let q1 = engine.quote(at: t1)
        let q2 = engine.quote(at: t1)
        XCTAssertEqual(q1.id, q2.id)
    }

    func testCustomQuoteCRUD() {
        let engine = QuoteEngine()
        let custom = engine.addCustomQuote(
            text: "Consistency over intensity.",
            authorOrMeaning: "Personal Mantra",
            category: .goal
        )
        XCTAssertEqual(engine.customQuotes.count, 1)
        XCTAssertTrue(engine.allItems.contains { $0.id == custom.id })

        engine.deleteCustomQuote(id: custom.id)
        XCTAssertTrue(engine.customQuotes.isEmpty)
    }
}

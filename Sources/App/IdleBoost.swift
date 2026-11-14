// Sources/App/IdleBoost.swift
import Foundation
import AgentPetCore

enum IdleBoost {
    static let lines = [
        "Let's grill some bugs.",
        "I miss you. Open a branch for me.",
        "Tiny commit, tiny dopamine.",
        "The build is quiet. Too quiet.",
        "Ship something small. Future you is watching.",
        "Your TODOs are pretending not to see us.",
        "No agents running. The keyboard has entered standby drama.",
        "Turn coffee into code. Carefully.",
        "Open one file. Intimidate it professionally.",
        "The repo is calm. Suspicious, but calm.",
        "Refactor lightly. Leave with dignity.",
        "One clean diff can fix the whole afternoon.",
    ]

    @MainActor
    static func line(at date: Date = Date()) -> String {
        let quoteCtrl = QuoteController.shared
        if quoteCtrl.config.showInPetBubble {
            let q = quoteCtrl.currentQuote
            if q.category == .idioms {
                return "\(q.text) — \(q.authorOrMeaning)"
            }
            return "\"\(q.text)\""
        }
        let minute = max(0, Int(date.timeIntervalSince1970 / 60))
        return NSLocalizedString(lines[minute % lines.count], comment: "idle message")
    }
}

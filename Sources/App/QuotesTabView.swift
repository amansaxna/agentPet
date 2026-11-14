// Sources/App/QuotesTabView.swift
import SwiftUI
import AppKit
import AgentPetCore

/// Tab view for managing Tailored Quotes, Sanskrit & Kannada shlokas, favorites, and custom mantras.
struct QuotesTabView: View {
    @ObservedObject private var quoteCtrl = QuoteController.shared

    @State private var newText: String = ""
    @State private var newAuthor: String = ""
    @State private var newCategory: QuoteCategory = .shloka
    @State private var libraryFilter: QuoteCategory? = nil
    @State private var searchQuery: String = ""
    @State private var copiedId: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                activeQuoteCard
                quoteLibraryCard
                categoryFilterCard
                rotationSettingsCard
                customQuotesCard
                addQuoteCard
            }
            .padding(20)
        }
    }

    // MARK: - Active Quote Showcase

    private var activeQuoteCard: some View {
        let item = quoteCtrl.currentQuote
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: item.category.icon)
                    Text(item.category.displayName.uppercased())
                }
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(Capsule().fill(Theme.accent.opacity(0.25)))
                .foregroundStyle(Theme.accent)

                Spacer()

                Button {
                    copyToClipboard(text: "“\(item.text)”\n— \(item.authorOrMeaning)", id: item.id)
                } label: {
                    Label(copiedId == item.id ? "Copied!" : "Copy", systemImage: copiedId == item.id ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    quoteCtrl.toggleFavorite(id: item.id)
                } label: {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(item.isFavorite ? Color.yellow : .white.opacity(0.4))
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await quoteCtrl.fetchLiveQuote()
                    }
                } label: {
                    if quoteCtrl.isFetchingLive {
                        ProgressView().controlSize(.mini)
                    } else {
                        Label("Fetch FavQs Live", systemImage: "globe")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Fetch daily structured quote from FavQs API")

                Button {
                    quoteCtrl.nextQuote()
                } label: {
                    Label("Next Quote", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("“\(item.text)”")
                .font(.system(size: 16.5, weight: .medium, design: .serif))
                .foregroundStyle(.white)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)

            if !item.authorOrMeaning.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.category == .idioms ? "Meaning & Context:" : "Author & Translation:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.accent.opacity(0.85))

                    Text(item.authorOrMeaning)
                        .font(.system(size: 12.5, design: .serif))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.cardStroke, lineWidth: 1))
            }
        }
        .themedCard()
    }

    // MARK: - Quotes & Shlokas Library Explorer

    private var quoteLibraryCard: some View {
        let all = quoteCtrl.allItems
        let filtered = all.filter { item in
            let matchesCat = libraryFilter == nil || item.category == libraryFilter
            let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesSearch = q.isEmpty || item.text.lowercased().contains(q) || item.authorOrMeaning.lowercased().contains(q)
            return matchesCat && matchesSearch
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                EyebrowLabel("BROWSE QUOTES & SHLOKAS LIBRARY (\(filtered.count) OF \(all.count))")
                Spacer()
            }

            // Category filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    categoryFilterChip(title: "All Categories", category: nil)
                    ForEach(QuoteCategory.allCases, id: \.self) { cat in
                        categoryFilterChip(title: cat.displayName, category: cat)
                    }
                }
                .padding(.vertical, 2)
            }

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.muted)
                    .font(.system(size: 12))
                TextField("Search quotes, shlokas, authors, or translations...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.cardStroke, lineWidth: 1))

            // Quotes list
            VStack(spacing: 8) {
                ForEach(filtered.prefix(40)) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            HStack(spacing: 4) {
                                Image(systemName: item.category.icon)
                                Text(item.category.displayName)
                            }
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(Theme.accent)

                            Spacer()

                            Button {
                                quoteCtrl.selectQuote(item)
                            } label: {
                                Text(quoteCtrl.currentQuote.id == item.id ? "Active on Pet" : "Set Active")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(quoteCtrl.currentQuote.id == item.id ? Color.green : Theme.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(quoteCtrl.currentQuote.id == item.id ? Color.green.opacity(0.18) : Theme.accent.opacity(0.15)))
                            }
                            .buttonStyle(.plain)

                            Button {
                                quoteCtrl.toggleFavorite(id: item.id)
                            } label: {
                                Image(systemName: item.isFavorite ? "star.fill" : "star")
                                    .font(.system(size: 12))
                                    .foregroundStyle(item.isFavorite ? Color.yellow : .white.opacity(0.35))
                            }
                            .buttonStyle(.plain)

                            Button {
                                copyToClipboard(text: "“\(item.text)”\n— \(item.authorOrMeaning)", id: item.id)
                            } label: {
                                Image(systemName: copiedId == item.id ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11))
                                    .foregroundStyle(copiedId == item.id ? Color.green : Theme.muted)
                            }
                            .buttonStyle(.plain)
                        }

                        Text("“\(item.text)”")
                            .font(.system(size: 13.5, weight: .medium, design: .serif))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        if !item.authorOrMeaning.isEmpty {
                            Text(item.category == .idioms ? "Meaning: \(item.authorOrMeaning)" : "— \(item.authorOrMeaning)")
                                .font(.system(size: 11.5, design: .serif))
                                .foregroundStyle(Theme.muted)
                                .lineSpacing(1.5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(item.id == quoteCtrl.currentQuote.id ? Theme.accent.opacity(0.5) : Theme.cardStroke, lineWidth: 1))
                }
            }
        }
        .themedCard()
    }

    private func categoryFilterChip(title: String, category: QuoteCategory?) -> some View {
        let isSelected = libraryFilter == category
        return Button {
            libraryFilter = category
        } label: {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(isSelected ? Theme.accent : Color.white.opacity(0.08)))
                .foregroundStyle(isSelected ? .white : Theme.muted)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Filters

    private var categoryFilterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel("CATEGORY PREFERENCES (10 CATEGORIES — INCL. SANSKRIT & KANNADA)")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(QuoteCategory.allCases, id: \.self) { cat in
                    let isEnabled = quoteCtrl.config.enabledCategories.contains(cat)
                    Button {
                        quoteCtrl.toggleCategory(cat)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: cat.icon).font(.system(size: 11))
                            Text(cat.displayName).font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(isEnabled ? Theme.accent.opacity(0.3) : Color.white.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isEnabled ? Theme.accent : Theme.cardStroke, lineWidth: 1))
                        .foregroundStyle(isEnabled ? .white : Theme.muted)
                    }
                    .buttonStyle(.plain)
                }
            }

            Toggle("Show only favorited quotes", isOn: $quoteCtrl.config.onlyFavorites)
                .font(.system(size: 12))
                .padding(.top, 4)
        }
        .themedCard()
    }

    // MARK: - Rotation & Presentation

    private var rotationSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel("ROTATION & DISPLAY")

            Toggle("Display rotating quote in Desktop Pet bubble", isOn: $quoteCtrl.config.showInPetBubble)
                .font(.system(size: 13))

            Toggle("Include Live FavQs & ZenQuotes API quotes in rotation", isOn: $quoteCtrl.config.fetchLiveQuotes)
                .font(.system(size: 13))

            Divider().overlay(Theme.cardStroke)

            HStack {
                Text("Auto-rotate quote every:")
                    .font(.system(size: 13))
                Spacer()
                Stepper(value: $quoteCtrl.config.rotationMinutes, in: 5...120, step: 5) {
                    Text("\(quoteCtrl.config.rotationMinutes) minutes")
                        .font(.system(size: 13, design: .monospaced))
                }
            }
        }
        .themedCard()
    }

    // MARK: - Custom Quotes List

    private var customQuotesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel("YOUR CUSTOM MANTRAS (\(quoteCtrl.customQuotes.count))")

            if quoteCtrl.customQuotes.isEmpty {
                Text("No personal mantras added yet. Write your favorite exam strategy or quote below.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(quoteCtrl.customQuotes) { q in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\"\(q.text)\"")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                            Text("\(q.category.displayName) · \(q.authorOrMeaning)")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            quoteCtrl.deleteCustomQuote(id: q.id)
                        } label: {
                            Image(systemName: "trash").foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    Divider().overlay(Theme.cardStroke)
                }
            }
        }
        .themedCard()
    }

    // MARK: - Add Custom Quote

    private var addQuoteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel("ADD CUSTOM QUOTE / MANTRA")

            TextField("Quote or mantra text", text: $newText)
                .textFieldStyle(.roundedBorder)

            TextField("Author or meaning note", text: $newAuthor)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Category:").font(.system(size: 12))
                Picker("", selection: $newCategory) {
                    ForEach(QuoteCategory.allCases, id: \.self) { cat in
                        Text(cat.displayName).tag(cat)
                    }
                }
            }

            Button("Save Mantra") {
                guard !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                quoteCtrl.addCustomQuote(
                    text: newText,
                    authorOrMeaning: newAuthor,
                    category: newCategory
                )
                newText = ""
                newAuthor = ""
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .themedCard()
    }

    private func copyToClipboard(text: String, id: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedId = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedId == id {
                copiedId = nil
            }
        }
    }
}

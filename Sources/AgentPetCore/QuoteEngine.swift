// Sources/AgentPetCore/QuoteEngine.swift
import Foundation

/// The 10 distinct quote, shloka, and wisdom categories.
public enum QuoteCategory: String, Codable, CaseIterable, Sendable {
    case dream
    case passion
    case life
    case saying
    case idioms
    case goal
    case gateExam
    case shloka
    case kannada
    case api

    public var displayName: String {
        switch self {
        case .dream: return "Dream"
        case .passion: return "Passion"
        case .life: return "Life"
        case .saying: return "Saying"
        case .idioms: return "Idioms"
        case .goal: return "Goal"
        case .gateExam: return "GATE Exam"
        case .shloka: return "Sanskrit Shloka"
        case .kannada: return "Kannada Shloka"
        case .api: return "FavQs / Live Daily"
        }
    }

    public var icon: String {
        switch self {
        case .dream: return "sparkles"
        case .passion: return "flame.fill"
        case .life: return "leaf.fill"
        case .saying: return "quote.bubble.fill"
        case .idioms: return "text.book.closed.fill"
        case .goal: return "target"
        case .gateExam: return "graduationcap.fill"
        case .shloka: return "sun.max.fill"
        case .kannada: return "book.closed.fill"
        case .api: return "globe"
        }
    }
}

/// A single quote, proverb, or idiom item.
public struct QuoteItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var text: String
    public var authorOrMeaning: String
    public var category: QuoteCategory
    public var isFavorite: Bool
    public var isCustom: Bool

    public init(
        id: String = UUID().uuidString,
        text: String,
        authorOrMeaning: String,
        category: QuoteCategory,
        isFavorite: Bool = false,
        isCustom: Bool = false
    ) {
        self.id = id
        self.text = text
        self.authorOrMeaning = authorOrMeaning
        self.category = category
        self.isFavorite = isFavorite
        self.isCustom = isCustom
    }
}

/// User configuration for quote rotation and presentation.
public struct QuoteConfig: Codable, Equatable, Sendable {
    public var enabledCategories: Set<QuoteCategory>
    public var rotationMinutes: Int
    public var showInPetBubble: Bool
    public var onlyFavorites: Bool
    public var fetchLiveQuotes: Bool

    public init(
        enabledCategories: Set<QuoteCategory> = Set(QuoteCategory.allCases),
        rotationMinutes: Int = 15,
        showInPetBubble: Bool = true,
        onlyFavorites: Bool = false,
        fetchLiveQuotes: Bool = true
    ) {
        self.enabledCategories = enabledCategories.isEmpty ? Set(QuoteCategory.allCases) : enabledCategories
        self.rotationMinutes = max(1, rotationMinutes)
        self.showInPetBubble = showInPetBubble
        self.onlyFavorites = onlyFavorites
        self.fetchLiveQuotes = fetchLiveQuotes
    }
}

/// Curated offline catalog containing >= 8 items per category.
public enum QuoteCatalog {
    public static let items: [QuoteItem] = [
        // MARK: - 1. Dream (Vision, Audacity, Building Big)
        QuoteItem(id: "dream-1", text: "The future belongs to those who believe in the beauty of their dreams.", authorOrMeaning: "Eleanor Roosevelt", category: .dream),
        QuoteItem(id: "dream-2", text: "Every great dream begins with a dreamer. Always remember, you have within you the strength to reach for the stars.", authorOrMeaning: "Harriet Tubman", category: .dream),
        QuoteItem(id: "dream-3", text: "Dream big and dare to fail.", authorOrMeaning: "Norman Vaughan", category: .dream),
        QuoteItem(id: "dream-4", text: "Nothing happens unless first we dream.", authorOrMeaning: "Carl Sandburg", category: .dream),
        QuoteItem(id: "dream-5", text: "You are never too old to set another goal or to dream a new dream.", authorOrMeaning: "C.S. Lewis", category: .dream),
        QuoteItem(id: "dream-6", text: "Hold fast to dreams, for if dreams die, life is a broken-winged bird that cannot fly.", authorOrMeaning: "Langston Hughes", category: .dream),
        QuoteItem(id: "dream-7", text: "Build your own dreams, or someone else will hire you to build theirs.", authorOrMeaning: "Farrah Gray", category: .dream),
        QuoteItem(id: "dream-8", text: "A dream does not become reality through magic; it takes sweat, determination, and hard work.", authorOrMeaning: "Colin Powell", category: .dream),
        QuoteItem(id: "dream-9", text: "Do not follow where the path may lead. Go instead where there is no path and leave a trail.", authorOrMeaning: "Ralph Waldo Emerson", category: .dream),
        QuoteItem(id: "dream-10", text: "Shoot for the moon. Even if you miss, you'll land among the stars.", authorOrMeaning: "Les Brown", category: .dream),

        // MARK: - 2. Passion (Craft, Curiosity, Intrinsic Drive)
        QuoteItem(id: "passion-1", text: "The only way to do great work is to love what you do.", authorOrMeaning: "Steve Jobs", category: .passion),
        QuoteItem(id: "passion-2", text: "Passion is energy. Feel the power that comes from focusing on what excites you.", authorOrMeaning: "Oprah Winfrey", category: .passion),
        QuoteItem(id: "passion-3", text: "I have no special talents. I am only passionately curious.", authorOrMeaning: "Albert Einstein", category: .passion),
        QuoteItem(id: "passion-4", text: "Develop a passion for learning. If you do, you will never cease to grow.", authorOrMeaning: "Anthony J. D'Angelo", category: .passion),
        QuoteItem(id: "passion-5", text: "Without passion you don't have energy, without energy you have nothing.", authorOrMeaning: "Warren Buffett", category: .passion),
        QuoteItem(id: "passion-6", text: "Chase your passion, not your pension.", authorOrMeaning: "Denis Waitley", category: .passion),
        QuoteItem(id: "passion-7", text: "If you feel like there's something out there that you're supposed to be doing, go after it.", authorOrMeaning: "Chrissy Metz", category: .passion),
        QuoteItem(id: "passion-8", text: "When you have passion, work feels like play, and mastery becomes inevitable.", authorOrMeaning: "Robert Greene", category: .passion),
        QuoteItem(id: "passion-9", text: "Enthusiasm is the mother of effort, and without it nothing great was ever achieved.", authorOrMeaning: "Ralph Waldo Emerson", category: .passion),
        QuoteItem(id: "passion-10", text: "Mastery begins with a single deliberate hour of deep, joyful immersion.", authorOrMeaning: "Cal Newport", category: .passion),

        // MARK: - 3. Life (Perspective, Resilience, Calm Living)
        QuoteItem(id: "life-1", text: "Life is what happens when you're busy making other plans.", authorOrMeaning: "John Lennon", category: .life),
        QuoteItem(id: "life-2", text: "In the middle of every difficulty lies opportunity.", authorOrMeaning: "Albert Einstein", category: .life),
        QuoteItem(id: "life-3", text: "The unexamined life is not worth living.", authorOrMeaning: "Socrates", category: .life),
        QuoteItem(id: "life-4", text: "Peace comes from within. Do not seek it without.", authorOrMeaning: "Buddha", category: .life),
        QuoteItem(id: "life-5", text: "Life is 10% what happens to you and 90% how you react to it.", authorOrMeaning: "Charles R. Swindoll", category: .life),
        QuoteItem(id: "life-6", text: "Do not spoil what you have by desiring what you have not.", authorOrMeaning: "Epicurus", category: .life),
        QuoteItem(id: "life-7", text: "It is not death that a man should fear, but never beginning to live.", authorOrMeaning: "Marcus Aurelius", category: .life),
        QuoteItem(id: "life-8", text: "Breathe. Let go. And remind yourself that this very moment is the only one you know you have.", authorOrMeaning: "Oprah Winfrey", category: .life),
        QuoteItem(id: "life-9", text: "Simplicity is the ultimate sophistication in both life and code.", authorOrMeaning: "Leonardo da Vinci", category: .life),
        QuoteItem(id: "life-10", text: "You have power over your mind - not outside events. Realize this, and you will find strength.", authorOrMeaning: "Marcus Aurelius", category: .life),

        // MARK: - 4. Saying (Timeless Proverbs & Crisp Wisdom)
        QuoteItem(id: "saying-1", text: "A journey of a thousand miles begins with a single step.", authorOrMeaning: "Lao Tzu", category: .saying),
        QuoteItem(id: "saying-2", text: "Smooth seas never made a skilled sailor.", authorOrMeaning: "African Proverb", category: .saying),
        QuoteItem(id: "saying-3", text: "Drop by drop is the water pot filled.", authorOrMeaning: "Dhammapada", category: .saying),
        QuoteItem(id: "saying-4", text: "Still waters run deep.", authorOrMeaning: "Latin Proverb", category: .saying),
        QuoteItem(id: "saying-5", text: "The best time to plant a tree was 20 years ago. The second best time is now.", authorOrMeaning: "Chinese Proverb", category: .saying),
        QuoteItem(id: "saying-6", text: "Actions speak louder than words.", authorOrMeaning: "English Proverb", category: .saying),
        QuoteItem(id: "saying-7", text: "He who moves a mountain begins by carrying away small stones.", authorOrMeaning: "Confucius", category: .saying),
        QuoteItem(id: "saying-8", text: "Where there is a will, there is a way.", authorOrMeaning: "English Proverb", category: .saying),
        QuoteItem(id: "saying-9", text: "Patience is bitter, but its fruit is sweet.", authorOrMeaning: "Jean-Jacques Rousseau", category: .saying),
        QuoteItem(id: "saying-10", text: "Fall seven times, stand up eight.", authorOrMeaning: "Japanese Proverb", category: .saying),

        // MARK: - 5. Idioms (High-Signal English Idioms with Concise Meaning)
        QuoteItem(id: "idiom-1", text: "Burn the midnight oil", authorOrMeaning: "Study or work late into the night with dedication", category: .idioms),
        QuoteItem(id: "idiom-2", text: "Hit the nail on the head", authorOrMeaning: "Describe or solve a problem with exact precision", category: .idioms),
        QuoteItem(id: "idiom-3", text: "Cut corners", authorOrMeaning: "Do something hastily or poorly to save time, compromising quality", category: .idioms),
        QuoteItem(id: "idiom-4", text: "Bite the bullet", authorOrMeaning: "Face a tough, inevitable challenge with courage and resolve", category: .idioms),
        QuoteItem(id: "idiom-5", text: "Through thick and thin", authorOrMeaning: "Staying steadfast and committed through all circumstances", category: .idioms),
        QuoteItem(id: "idiom-6", text: "The ball is in your court", authorOrMeaning: "It is now your turn and responsibility to take action", category: .idioms),
        QuoteItem(id: "idiom-7", text: "Keep your eyes on the prize", authorOrMeaning: "Stay focused on the ultimate long-term objective", category: .idioms),
        QuoteItem(id: "idiom-8", text: "Back to the drawing board", authorOrMeaning: "Start over with fresh insight after an approach didn't work", category: .idioms),
        QuoteItem(id: "idiom-9", text: "Practice makes perfect", authorOrMeaning: "Repeated deliberate effort leads to mastery and fluency", category: .idioms),
        QuoteItem(id: "idiom-10", text: "Leave no stone unturned", authorOrMeaning: "Investigate and prepare every possible angle thoroughly", category: .idioms),

        // MARK: - 6. Goal (Execution, Milestones, Compounding Effort)
        QuoteItem(id: "goal-1", text: "A goal without a plan is just a wish.", authorOrMeaning: "Antoine de Saint-Exupéry", category: .goal),
        QuoteItem(id: "goal-2", text: "Discipline is the bridge between goals and accomplishment.", authorOrMeaning: "Jim Rohn", category: .goal),
        QuoteItem(id: "goal-3", text: "Setting goals is the first step in turning the invisible into the visible.", authorOrMeaning: "Tony Robbins", category: .goal),
        QuoteItem(id: "goal-4", text: "Small daily improvements over time lead to stunning results.", authorOrMeaning: "Robin Sharma", category: .goal),
        QuoteItem(id: "goal-5", text: "You don't rise to the level of your goals, you fall to the level of your systems.", authorOrMeaning: "James Clear", category: .goal),
        QuoteItem(id: "goal-6", text: "Focus on the process, not the outcome. The score takes care of itself.", authorOrMeaning: "Bill Walsh", category: .goal),
        QuoteItem(id: "goal-7", text: "One day or day one. You decide.", authorOrMeaning: "Paulo Coelho", category: .goal),
        QuoteItem(id: "goal-8", text: "Success is the sum of small efforts repeated day in and day out.", authorOrMeaning: "Robert Collier", category: .goal),
        QuoteItem(id: "goal-9", text: "What you get by achieving your goals is not as important as what you become by achieving your goals.", authorOrMeaning: "Zig Ziglar", category: .goal),
        QuoteItem(id: "goal-10", text: "Compound effort: 1% better each day compounds into a 37x leap across a year.", authorOrMeaning: "James Clear", category: .goal),

        // MARK: - 7. GATE Exam (Concept Mastery, PYQs, Mock Analysis, Rank Mindset)
        QuoteItem(id: "gate-1", text: "Concepts clarify doubts; PYQs reveal patterns; mock analysis builds rank.", authorOrMeaning: "GATE Topper Wisdom", category: .gateExam),
        QuoteItem(id: "gate-2", text: "Don't just solve problems; master the underlying principles and edge cases.", authorOrMeaning: "Concept Mastery", category: .gateExam),
        QuoteItem(id: "gate-3", text: "An unanalyzed mock test is an opportunity wasted. Log every negative mark.", authorOrMeaning: "Test Series Discipline", category: .gateExam),
        QuoteItem(id: "gate-4", text: "Accuracy first, speed second. Negative marking penalizes arrogance, rewards composure.", authorOrMeaning: "Exam Strategy", category: .gateExam),
        QuoteItem(id: "gate-5", text: "Solve 15 years of previous year questions until the question pattern feels like second nature.", authorOrMeaning: "PYQ Protocol", category: .gateExam),
        QuoteItem(id: "gate-6", text: "Revise short notes daily. Formula retention without conceptual clarity is brittle.", authorOrMeaning: "Revision Habit", category: .gateExam),
        QuoteItem(id: "gate-7", text: "The syllabus is finite; your focus determines how deep you go.", authorOrMeaning: "Rank Mindset", category: .gateExam),
        QuoteItem(id: "gate-8", text: "Every challenging NAT question solved with clean math is a rank booster.", authorOrMeaning: "Numerical Focus", category: .gateExam),
        QuoteItem(id: "gate-9", text: "Consistency beats brilliance in GATE. 4 focused hours every day beats weekend heroics.", authorOrMeaning: "Consistency Rule", category: .gateExam),
        QuoteItem(id: "gate-10", text: "Remain calm under exam pressure. The top ranks are decided by temperament in the last hour.", authorOrMeaning: "Composure on Exam Day", category: .gateExam),

        // MARK: - 8. Sanskrit Shlokas (Bhagavad Gita, Upanishads & Indian Mythology)
        QuoteItem(id: "shloka-1", text: "कर्मण्येवाधिकारस्ते मा फलेषु कदाचन। मा कर्मफलहेतुर्भूर्मा ते सङ्गोऽस्त्वकर्मणि॥", authorOrMeaning: "You have a right only to work, never to its fruits. Let not the fruit of action be your motive, nor let there be attachment to inaction. — Bhagavad Gita 2.47", category: .shloka),
        QuoteItem(id: "shloka-2", text: "उद्धरेदात्मनात्मानं नात्मानमवसादयेत्। आत्मैव ह्यात्मनो बन्धुरात्मैव रिपुरात्मनः॥", authorOrMeaning: "Elevate yourself through your own mind; do not degrade yourself. For the mind can be your greatest friend or worst enemy. — Bhagavad Gita 6.5", category: .shloka),
        QuoteItem(id: "shloka-3", text: "योगः कर्मसु कौशलम्॥", authorOrMeaning: "Yoga is supreme skill, excellence, and equanimity in action. — Bhagavad Gita 2.50", category: .shloka),
        QuoteItem(id: "shloka-4", text: "न हि ज्ञानेन सदृशं पवित्रमिह विद्यते। तत्स्वयं योगसंसिद्धः कालेनात्मनि विन्दति॥", authorOrMeaning: "There is nothing in this world as purifying as knowledge. One perfected in selfless work finds this truth within. — Bhagavad Gita 4.38", category: .shloka),
        QuoteItem(id: "shloka-5", text: "उद्यमेन हि सिध्यन्ति कार्याणि न मनोरथैः। न हि सुप्तस्य सिंहस्य प्रविशन्ति मुखे मृगाः॥", authorOrMeaning: "Tasks are accomplished through industrious effort, never by wishing alone. Prey does not walk into the mouth of a sleeping lion. — Hitopadesha", category: .shloka),
        QuoteItem(id: "shloka-6", text: "असतो मा सद्गमय। तमसो मा ज्योतिर्गमय। मृत्योर्मा अमृतं गमय॥", authorOrMeaning: "Lead me from ignorance to truth, from darkness to light, from mortality to the eternal. — Brihadaranyaka Upanishad (Pavamana Mantra)", category: .shloka),
        QuoteItem(id: "shloka-7", text: "सत्यं वद। धर्मं चर। स्वाध्यायान्मा प्रमदः॥", authorOrMeaning: "Speak the truth. Practice righteous duty. Never neglect daily self-study and learning. — Taittiriya Upanishad 1.11.1", category: .shloka),
        QuoteItem(id: "shloka-8", text: "विद्या ददाति विनयं विनयाद्याति पात्रताम्। पात्रत्वाद्धनमाप्नोति धनाद्धर्मं ततः सुखम्॥", authorOrMeaning: "Knowledge bestows humility; humility creates worthiness; worthiness brings righteous means; through dharma comes enduring bliss. — Subhashita", category: .shloka),
        QuoteItem(id: "shloka-9", text: "क्षणशः कणशश्चैव विद्यामर्थं च साधयेत्। क्षणे नष्टे कुतो विद्या कणे नष्टे कुतो धनम्॥", authorOrMeaning: "Knowledge should be gained moment by moment, and wealth grain by grain. Lost time yields no wisdom; lost particles yield no treasure. — Chanakya Neeti", category: .shloka),
        QuoteItem(id: "shloka-10", text: "यथा ह्येकेन चक्रेण न रथस्य गतिर्भवेत्। एवं पुरुषकारेण विना दैवं न सिध्यति॥", authorOrMeaning: "Just as a chariot cannot advance on one wheel, destiny cannot fulfill itself without dedicated human effort. — Chanakya Neeti", category: .shloka),
        QuoteItem(id: "shloka-11", text: "आ नो भद्राः क्रतवो यन्तु विश्वतः॥", authorOrMeaning: "May auspicious, noble, and expansive thoughts flow to us from every corner of the universe. — Rigveda 1.89.1", category: .shloka),
        QuoteItem(id: "shloka-12", text: "सत्यमेವ जयते नानृतम्॥", authorOrMeaning: "Truth alone triumphs, never falsehood. — Mundaka Upanishad 3.1.6", category: .shloka),
        QuoteItem(id: "shloka-13", text: "तस्मादसक्तः सततं कार्यं कर्म समाचर। असक्तो ह्याचरन्कर्म परमाप्नोति पूरुषः॥", authorOrMeaning: "Therefore, always perform your duties with detachment; by performing duties free of attachment, one reaches the supreme state. — Bhagavad Gita 3.19", category: .shloka),
        QuoteItem(id: "shloka-14", text: "नाप्राप्यमभिकाङ्क्षन्ति नष्टं नेच्छन्ति शोचितुम्। आपत्सु च न मुह्यन्ति नराः पण्डितबुद्धयः॥", authorOrMeaning: "The truly wise do not yearn for the unobtainable, do not grieve over what is gone, and maintain complete composure in crises. — Vidura Niti", category: .shloka),
        QuoteItem(id: "shloka-15", text: "ईशा वास्यमिदं सर्वं यत्किञ्च जगत्यां जगत्। तेन त्यक्तेन भुञ्जीथा मा गृधः कस्यस्विद्धनम्॥", authorOrMeaning: "All this is enveloped by divine consciousness. Enjoy with a spirit of renunciation, and covet no one's wealth. — Isha Upanishad 1", category: .shloka),

        // MARK: - 9. Kannada Shlokas & Vachana / Dasa Sahitya
        QuoteItem(id: "kan-1", text: "ಕಾಯಕವೇ ಕೈಲಾಸ (Kayakave Kailasa)", authorOrMeaning: "Work is worship; honest, dedicated labor itself is the celestial abode of God. — Jagadjyothi Basavanna", category: .kannada),
        QuoteItem(id: "kan-2", text: "ಉಳ್ಳವರು ಶಿವಾಲಯ ಮಾಡುವರು, ನಾನೇನು ಮಾಡಲಿ ಬಡವನಯ್ಯಾ? ಎನ್ನ ಕಾಲೇ ಕಂಬ, ದೇಹವೇ ದೇಗುಲ, ಶಿರವೇ ಹೊನ್ನ ಕಳಶವಯ್ಯಾ...", authorOrMeaning: "The wealthy build temples; my legs are the pillars, body the shrine, and head the golden kalasha. The static shall fall, the moving remains forever. — Basavanna", category: .kannada),
        QuoteItem(id: "kan-3", text: "ಮಾನವ ಜನ್ಮ ದೊಡ್ಡದು, ಇದ ಹಾಳು ಮಾಡಬೇಡಿ ಹುಚ್ಚಪ್ಪಗಳಿರಾ (Maanava Janma Doddadu)", authorOrMeaning: "Human birth is rare and noble, do not squander it in foolishness. Cleanse your mind and pursue righteous wisdom. — Purandara Dasa", category: .kannada),
        QuoteItem(id: "kan-4", text: "ತಲ್ಲಣಿಸದಿರು ಕಂಡ್ಯ ತಾಳು ಮನವೇ, ಎಲ್ಲರನು ಕಾಯುವನು ಪೊರೆವನಿಹನೊಬ್ಬ (Tallanisadiru Kandya Thalu Manave)", authorOrMeaning: "Do not despair or tremble, have patience, O mind! There is one divine protector who nurtures every living creation. — Kanaka Dasa", category: .kannada),
        QuoteItem(id: "kan-5", text: "ಬೆಟ್ಟದ ಮೇಲೊಂದು ಹುಟ್ಟಿದ ವೃಕ್ಷಕೆ ಕಟ್ಟೆಯ ಕಟ್ಟಿ ನೀರೆರೆದವರಾರು? (Bettada Melondhu Huttida Vrikshake)", authorOrMeaning: "Who built an embankment and watered the sapling that grew on a barren rock? He who gave life will sustain it. Have steady faith. — Kanaka Dasa", category: .kannada),
        QuoteItem(id: "kan-6", text: "ಅರಿವೇ ಗುರು, ಜ್ಯೋತಿಯೇ ಲಿಂಗ (Arive Guru, Jyothiye Linga)", authorOrMeaning: "True self-awareness is the highest teacher; the inner light of consciousness is the supreme divinity. — Allama Prabhu", category: .kannada),
        QuoteItem(id: "kan-7", text: "ಬೆಟ್ಟದ ಮೇಲೊಂದು ಮನೆಯ ಮಾಡಿ ಮೃಗಂಗಳಿಗಂಜಿದೊಡೆಂತಯ್ಯಾ? (Bettada Melondhu Maneya Maadi)", authorOrMeaning: "Having built a house on a mountain, can one fear the beasts? Having stepped into the arena of life, meet praise and blame with poise. — Akka Mahadevi", category: .kannada),
        QuoteItem(id: "kan-8", text: "ಬದುಕು ಜಟಕಾಬಂಡಿ, ವಿಧಿ ಅದರ ಸಾಹೇಬ, ಕುದುರೆ ನೀನ್, ಅವನು ಹೇಳಿದಂತೆ ಪಯಣಿಗರು... (Baduku Jatakabandi)", authorOrMeaning: "Life is a horse cart, destiny its driver, you are the horse; passengers ride as ordained. Stride steadily with dignity, O Timma. — D.V.G. Mankuthimmana Kagga", category: .kannada),
        QuoteItem(id: "kan-9", text: "ಹುಲ್ಲಾಗು ಬೆಟ್ಟದಡಿ, ಮನೆಗೆ ಮಲ್ಲಿಗೆಯಾಗು, ಕಲ್ಲಾಗು ಕಷ್ಟಗಳ ಮಳೆಯ ವಿಧಿ ಸುರಿಯೆ... (Hullagu Bettadadi, Manege Malligeyagu)", authorOrMeaning: "Be humble like grass at the foot of the hill; fragrant like jasmine at home; enduring like granite when hardships rain down. — D.V.G. Mankuthimmana Kagga", category: .kannada),
        QuoteItem(id: "kan-10", text: "ಎಲ್ಲ ಬಲ್ಲವರಿಲ್ಲ ಬಲ್ಲವರು ಕೆಲವರೇ, ಬಲ್ಲವರಿಗಾಗುವುದು ಆನಂದ... (Ella Ballavarilla)", authorOrMeaning: "No one knows everything in the universe; those who genuinely attain true insight are rare, and their wisdom brings joy. — Sarvajna", category: .kannada),
        QuoteItem(id: "kan-11", text: "ಕೊಟ್ಟದ್ದು ತನಗೆ, ಬಚ್ಚಿಟ್ಟದ್ದು ಪರರಿಗೆ... (Kottaddu Tanage, Bacchittaddu Pararige)", authorOrMeaning: "What you give selflessly in charity remains yours spiritually; what you hoard greedily belongs to others. — Sarvajna", category: .kannada),
        QuoteItem(id: "kan-12", text: "ಭಾಗ್ಯದ ಲಕ್ಷ್ಮಿ ಬಾರಮ್ಮಾ, ನಮ್ಮಮ್ಮಾ ನೀ ಸೌಭಾಗ್ಯದ ಲಕ್ಷ್ಮಿ ಬಾರಮ್ಮಾ (Bhagyada Lakshmi Baramma)", authorOrMeaning: "Come, O auspicious Mother Lakshmi, bringer of wisdom, virtue, and sacred well-being into our homes and minds. — Purandara Dasa", category: .kannada),
        QuoteItem(id: "kan-13", text: "ಮನದ ಸಂಕಲ್ಪವೇ ಸೃಷ್ಟಿ, ಮನದ ನಿಃಸಂಕಲ್ಪವೇ ಮುಕ್ತಿ (Manada Sankalpave Srushti)", authorOrMeaning: "The restless wandering of thoughts creates bondage; the tranquil stillness of the mind is true liberation. — Channabasavanna", category: .kannada),
        QuoteItem(id: "kan-14", text: "ಸತ್ಯವೇ ತಾಯಿ, ಸದ್ಗುಣವೇ ತಂದೆ, ಸತ್ಕರ್ಮವೇ ಬಂಧು (Satyave Taayi, Sadgunave Tande)", authorOrMeaning: "Truth is our mother, noble virtue is our father, and righteous action is our true kinsman. — Siddharama Shivayogi", category: .kannada),

        // MARK: - 10. Live API & Structured Quotes (FavQs / ZenQuotes)
        QuoteItem(id: "api-seed-1", text: "A good leader inspires other people to have confidence in them. A great leader inspires people to have confidence in themselves.", authorOrMeaning: "Arnold H. Glasow (FavQs QOTD)", category: .api),
        QuoteItem(id: "api-seed-2", text: "To lead the people, walk behind them.", authorOrMeaning: "Lao Tzu (ZenQuotes Live)", category: .api),
        QuoteItem(id: "api-seed-3", text: "Simplicity is the prerequisite for reliability.", authorOrMeaning: "Edsger W. Dijkstra (FavQs Architecture)", category: .api)
    ]
}

/// Pure deterministic quote selection and management engine.
public final class QuoteEngine: @unchecked Sendable {
    public var config: QuoteConfig
    public private(set) var customQuotes: [QuoteItem]
    public private(set) var favorites: Set<String>
    private var currentIndex: Int = 0

    public init(
        config: QuoteConfig = QuoteConfig(),
        customQuotes: [QuoteItem] = [],
        favorites: Set<String> = []
    ) {
        self.config = config
        self.customQuotes = customQuotes
        self.favorites = favorites
    }

    /// All items combining the curated catalog and user custom quotes.
    public var allItems: [QuoteItem] {
        let catalog = QuoteCatalog.items.map { item in
            var copy = item
            copy.isFavorite = favorites.contains(item.id)
            return copy
        }
        let customs = customQuotes.map { item in
            var copy = item
            copy.isFavorite = favorites.contains(item.id)
            return copy
        }
        return catalog + customs
    }

    /// Items filtered by enabled categories and optional favorite-only constraint.
    public var eligibleItems: [QuoteItem] {
        allItems.filter { item in
            guard config.enabledCategories.contains(item.category) else { return false }
            if config.onlyFavorites {
                return item.isFavorite
            }
            return true
        }
    }

    /// Selects a quote deterministically for a given timestamp.
    public func quote(at date: Date = Date()) -> QuoteItem {
        let items = eligibleItems
        guard !items.isEmpty else {
            return QuoteCatalog.items[0]
        }
        let interval = max(1, config.rotationMinutes * 60)
        let slot = Int(date.timeIntervalSince1970) / interval
        let index = abs(slot + currentIndex) % items.count
        return items[index]
    }

    /// Advances to the next quote in the eligible set.
    @discardableResult
    public func nextQuote() -> QuoteItem {
        let items = eligibleItems
        guard !items.isEmpty else {
            return QuoteCatalog.items[0]
        }
        currentIndex = (currentIndex + 1) % items.count
        return items[currentIndex]
    }

    /// Toggles favorite status for a given quote ID.
    @discardableResult
    public func toggleFavorite(id: String) -> Bool {
        if favorites.contains(id) {
            favorites.remove(id)
            return false
        } else {
            favorites.insert(id)
            return true
        }
    }

    public func addCustomQuote(text: String, authorOrMeaning: String, category: QuoteCategory) -> QuoteItem {
        let item = QuoteItem(
            id: UUID().uuidString,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            authorOrMeaning: authorOrMeaning.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            isFavorite: false,
            isCustom: true
        )
        customQuotes.append(item)
        return item
    }

    public func deleteCustomQuote(id: String) {
        customQuotes.removeAll(where: { $0.id == id })
        favorites.remove(id)
    }
}

/// Stores quote configuration, custom quotes, and favorites in `~/.agentpet/quotes.json`.
public final class QuoteStore: @unchecked Sendable {
    public static let shared = QuoteStore()

    public struct Snapshot: Codable, Sendable {
        public var config: QuoteConfig
        public var customQuotes: [QuoteItem]
        public var favorites: Set<String>

        public init(config: QuoteConfig, customQuotes: [QuoteItem], favorites: Set<String>) {
            self.config = config
            self.customQuotes = customQuotes
            self.favorites = favorites
        }
    }

    public let fileURL: URL
    private let queue = DispatchQueue(label: "com.agentpet.QuoteStore")

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.fileURL = home.appendingPathComponent(".agentpet/quotes.json")
        }
        ensureDirectoryExists()
    }

    private func ensureDirectoryExists() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    public func load() -> Snapshot {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let snapshot = try? Self.decoder.decode(Snapshot.self, from: data) else {
                return Snapshot(config: QuoteConfig(), customQuotes: [], favorites: [])
            }
            return snapshot
        }
    }

    public func save(config: QuoteConfig, customQuotes: [QuoteItem], favorites: Set<String>) {
        queue.sync {
            let snapshot = Snapshot(config: config, customQuotes: customQuotes, favorites: favorites)
            guard let data = try? Self.encoder.encode(snapshot) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

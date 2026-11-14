// Tailored Quote & Idiom Engine for AgentPet
// Covers 10 curated categories: dream, passion, life, saying, idioms, goal, gateExam, shloka, kannada, api.

export type QuoteCategory = "dream" | "passion" | "life" | "saying" | "idioms" | "goal" | "gateExam" | "shloka" | "kannada" | "api";

export interface QuoteItem {
  id: string;
  text: string;
  authorOrMeaning?: string;
  category: QuoteCategory;
  isFavorite?: boolean;
  isCustom?: boolean;
}

export interface QuoteConfig {
  enabledCategories: QuoteCategory[];
  rotationMinutes: number;
  showInPetBubble: boolean;
  onlyFavorites: boolean;
  currentQuoteId?: string;
  lastRotatedAt?: number;
}

export const CATEGORY_LABELS: Record<QuoteCategory, string> = {
  dream: "Dream",
  passion: "Passion",
  life: "Life",
  saying: "Saying",
  idioms: "Idioms",
  goal: "Goal",
  gateExam: "GATE Exam",
  shloka: "Sanskrit Shloka",
  kannada: "Kannada Shloka",
  api: "FavQs Live",
};

export const CATEGORY_COLORS: Record<QuoteCategory, string> = {
  dream: "#8b5cf6",     // purple
  passion: "#ec4899",   // pink
  life: "#10b981",      // emerald
  saying: "#06b6d4",    // cyan
  idioms: "#f59e0b",    // amber
  goal: "#3b82f6",      // blue
  gateExam: "#ef4444",  // red
  shloka: "#eab308",    // gold / saffron
  kannada: "#14b8a6",   // teal / green
  api: "#6366f1",       // indigo
};

export const DEFAULT_QUOTES: QuoteItem[] = [
  // 1. Dream
  { id: "d1", category: "dream", text: "The future belongs to those who believe in the beauty of their dreams.", authorOrMeaning: "Eleanor Roosevelt" },
  { id: "d2", category: "dream", text: "Shoot for the moon. Even if you miss, you will land among the stars.", authorOrMeaning: "Norman Vincent Peale" },
  { id: "d3", category: "dream", text: "All our dreams can come true, if we have the courage to pursue them.", authorOrMeaning: "Walt Disney" },
  { id: "d4", category: "dream", text: "A dream does not become reality through magic; it takes sweat, determination and hard work.", authorOrMeaning: "Colin Powell" },
  { id: "d5", category: "dream", text: "Dare to dream, but even more importantly, dare to put action behind your dreams.", authorOrMeaning: "Anonymous" },
  { id: "d6", category: "dream", text: "Every great dream begins with a dreamer. Always remember you have within you the strength to reach for the stars.", authorOrMeaning: "Harriet Tubman" },
  { id: "d7", category: "dream", text: "Keep your eyes on the stars, and your feet on the ground.", authorOrMeaning: "Theodore Roosevelt" },
  { id: "d8", category: "dream", text: "Never limit yourself because of others' limited imagination; never limit others because of your own limited imagination.", authorOrMeaning: "Mae Jemison" },
  { id: "d9", category: "dream", text: "The biggest adventure you can take is to live the life of your dreams.", authorOrMeaning: "Oprah Winfrey" },
  { id: "d10", category: "dream", text: "You are never too old to set another goal or to dream a new dream.", authorOrMeaning: "C.S. Lewis" },

  // 2. Passion
  { id: "p1", category: "passion", text: "The only way to do great work is to love what you do.", authorOrMeaning: "Steve Jobs" },
  { id: "p2", category: "passion", text: "Passion is energy. Feel the power that comes from focusing on what excites you.", authorOrMeaning: "Oprah Winfrey" },
  { id: "p3", category: "passion", text: "Develop a passion for learning. If you do, you will never cease to grow.", authorOrMeaning: "Anthony J. D'Angelo" },
  { id: "p4", category: "passion", text: "Nothing is as contagious as passion; it moves stones, it charms brutes.", authorOrMeaning: "Edmond Rostand" },
  { id: "p5", category: "passion", text: "Without passion you don't have energy, without energy you have nothing.", authorOrMeaning: "Warren Buffett" },
  { id: "p6", category: "passion", text: "Chase your passion, not your pension.", authorOrMeaning: "Denis Waitley" },
  { id: "p7", category: "passion", text: "Curiosity is the wick in the candle of learning.", authorOrMeaning: "William Arthur Ward" },
  { id: "p8", category: "passion", text: "Enthusiasm is common. Endurance is rare.", authorOrMeaning: "Angela Duckworth" },
  { id: "p9", category: "passion", text: "When you have passion, work feels like play, and mastery becomes inevitable.", authorOrMeaning: "Anonymous" },
  { id: "p10", category: "passion", text: "Mastery comes not from passive consumption, but from passionate creation.", authorOrMeaning: "Cal Newport" },

  // 3. Life
  { id: "l1", category: "life", text: "Smooth seas do not make skillful sailors.", authorOrMeaning: "African Proverb" },
  { id: "l2", category: "life", text: "Life is what happens when you're busy making other plans.", authorOrMeaning: "John Lennon" },
  { id: "l3", category: "life", text: "In the middle of difficulty lies opportunity.", authorOrMeaning: "Albert Einstein" },
  { id: "l4", category: "life", text: "It does not matter how slowly you go as long as you do not stop.", authorOrMeaning: "Confucius" },
  { id: "l5", category: "life", text: "Do not dwell in the past, do not dream of the future, concentrate the mind on the present moment.", authorOrMeaning: "Buddha" },
  { id: "l6", category: "life", text: "We suffer more often in imagination than in reality.", authorOrMeaning: "Seneca" },
  { id: "l7", category: "life", text: "He who has a why to live can bear almost any how.", authorOrMeaning: "Friedrich Nietzsche" },
  { id: "l8", category: "life", text: "Peace is the result of retraining your mind to process life as it is, rather than as you think it should be.", authorOrMeaning: "Wayne Dyer" },
  { id: "l9", category: "life", text: "You cannot control the wind, but you can always adjust your sails.", authorOrMeaning: "Anonymous" },
  { id: "l10", category: "life", text: "The happiness of your life depends upon the quality of your thoughts.", authorOrMeaning: "Marcus Aurelius" },

  // 4. Saying
  { id: "s1", category: "saying", text: "A journey of a thousand miles begins with a single step.", authorOrMeaning: "Lao Tzu" },
  { id: "s2", category: "saying", text: "Still waters run deep.", authorOrMeaning: "Classic Proverb" },
  { id: "s3", category: "saying", text: "Fortune favors the bold.", authorOrMeaning: "Latin Proverb" },
  { id: "s4", category: "saying", text: "A stitch in time saves nine.", authorOrMeaning: "English Proverb" },
  { id: "s5", category: "saying", text: "Action speaks louder than words.", authorOrMeaning: "Classic Saying" },
  { id: "s6", category: "saying", text: "Where there's a will, there's a way.", authorOrMeaning: "Timeless Adage" },
  { id: "s7", category: "saying", text: "Strike while the iron is hot.", authorOrMeaning: "Traditional Proverb" },
  { id: "s8", category: "saying", text: "The pen is mightier than the sword.", authorOrMeaning: "Edward Bulwer-Lytton" },
  { id: "s9", category: "saying", text: "Every cloud has a silver lining.", authorOrMeaning: "Traditional Saying" },
  { id: "s10", category: "saying", text: "Patience is a bitter plant, but its fruit is sweet.", authorOrMeaning: "Persian Proverb" },

  // 5. Idioms (with concise meanings)
  { id: "i1", category: "idioms", text: "Bite the bullet", authorOrMeaning: "Face a tough situation with courage and resolve." },
  { id: "i2", category: "idioms", text: "Burn the midnight oil", authorOrMeaning: "Work or study diligently late into the night." },
  { id: "i3", category: "idioms", text: "Hit the ground running", authorOrMeaning: "Begin a project immediately with maximum momentum." },
  { id: "i4", category: "idioms", text: "Cut to the chase", authorOrMeaning: "Focus on the core matter without wasting time on fluff." },
  { id: "i5", category: "idioms", text: "Leave no stone unturned", authorOrMeaning: "Examine every possibility and exhaust all resources." },
  { id: "i6", category: "idioms", text: "Keep your eye on the ball", authorOrMeaning: "Maintain strict focus on your primary objective." },
  { id: "i7", category: "idioms", text: "Cross the Rubicon", authorOrMeaning: "Take an irreversible step committing completely to your path." },
  { id: "i8", category: "idioms", text: "Steel sharpens steel", authorOrMeaning: "High-level competition and rigorous challenge hone elite skill." },
  { id: "i9", category: "idioms", text: "Rome wasn't built in a day", authorOrMeaning: "Substantial, world-class results require patient compounding." },
  { id: "i10", category: "idioms", text: "Through thick and thin", authorOrMeaning: "Remaining steadfast regardless of obstacles and setbacks." },

  // 6. Goal
  { id: "g1", category: "goal", text: "Discipline is the bridge between goals and accomplishment.", authorOrMeaning: "Jim Rohn" },
  { id: "g2", category: "goal", text: "We are what we repeatedly do. Excellence, then, is not an act, but a habit.", authorOrMeaning: "Will Durant" },
  { id: "g3", category: "goal", text: "Small disciplines repeated with consistency every day lead to great achievements.", authorOrMeaning: "John C. Maxwell" },
  { id: "g4", category: "goal", text: "A goal without a timeline is just a wish.", authorOrMeaning: "Antoine de Saint-Exupéry" },
  { id: "g5", category: "goal", text: "Success is the sum of small efforts, repeated day in and day out.", authorOrMeaning: "Robert Collier" },
  { id: "g6", category: "goal", text: "You don't have to be great to start, but you have to start to be great.", authorOrMeaning: "Zig Ziglar" },
  { id: "g7", category: "goal", text: "Focus on the process, and the outcomes will take care of themselves.", authorOrMeaning: "Nick Saban" },
  { id: "g8", category: "goal", text: "Set your goals high, and don't stop till you get there.", authorOrMeaning: "Bo Jackson" },
  { id: "g9", category: "goal", text: "Clarity of vision combined with uncompromising daily execution creates victory.", authorOrMeaning: "Anonymous" },
  { id: "g10", category: "goal", text: "Deep work is the superpower of the 21st century.", authorOrMeaning: "Cal Newport" },

  // 7. GATE Exam
  { id: "ge1", category: "gateExam", text: "Master the fundamentals; every complex GATE question is just three basic concepts layered together.", authorOrMeaning: "GATE Prep Principle" },
  { id: "ge2", category: "gateExam", text: "Don't just solve PYQs—diagnose why the incorrect options were chosen as distractors.", authorOrMeaning: "PYQ Analysis Guide" },
  { id: "ge3", category: "gateExam", text: "Accuracy beats raw speed. Negative marking is what separates AIR single-digits from the rest.", authorOrMeaning: "Rank Strategy" },
  { id: "ge4", category: "gateExam", text: "Analyze your mock test errors the same day. An unanalyzed mock exam is wasted effort.", authorOrMeaning: "Mock Discipline" },
  { id: "ge5", category: "gateExam", text: "Engineering Mathematics and General Aptitude are guaranteed 28 marks—master them early.", authorOrMeaning: "High-Yield Strategy" },
  { id: "ge6", category: "gateExam", text: "Formula revision is your daily bread. Keep short notes within arm's reach of your desk.", authorOrMeaning: "Retention Rule" },
  { id: "ge7", category: "gateExam", text: "Consistency on low-motivation days is where the top 100 ranks are forged.", authorOrMeaning: "Discipline Mantra" },
  { id: "ge8", category: "gateExam", text: "Derive key formulas once by hand. Rote memorization collapses under examination stress.", authorOrMeaning: "Concept Clarity" },
  { id: "ge9", category: "gateExam", text: "Revise weak topics within 24 hours of receiving test feedback. Never allow doubts to compound.", authorOrMeaning: "Feedback Loop" },
  { id: "ge10", category: "gateExam", text: "Time-box your problem sets during practice. The actual GATE exam is a race of high-speed clarity.", authorOrMeaning: "Exam Readiness" },

  // 8. Sanskrit Shlokas (Bhagavad Gita & Indian Mythology)
  { id: "sh1", category: "shloka", text: "कर्मण्येवाधिकारस्ते मा फलेषु कदाचन। मा कर्मफलहेतुर्भूर्मा ते सङ्गोऽस्त्वकर्मणि॥", authorOrMeaning: "You have a right only to work, never to its fruits. Let not the fruit of action be your motive. — Bhagavad Gita 2.47" },
  { id: "sh2", category: "shloka", text: "उद्धरेदात्मनात्मानं नात्मानमवसादयेत्। आत्मैव ह्यात्मनो बन्धुरात्मैव रिपुरात्मनः॥", authorOrMeaning: "Elevate yourself through your mind; do not degrade yourself. The mind can be your friend or foe. — Bhagavad Gita 6.5" },
  { id: "sh3", category: "shloka", text: "योगः कर्मसु कौशलम्॥", authorOrMeaning: "Yoga is supreme skill, excellence, and equanimity in action. — Bhagavad Gita 2.50" },
  { id: "sh4", category: "shloka", text: "उद्यमेन हि सिध्यन्ति कार्याणि न मनोरथैः। न हि सुप्तस्य सिंहस्य प्रविशन्ति मुखे मृगाः॥", authorOrMeaning: "Success is achieved through diligent effort, never by idle wishing alone. — Hitopadesha" },
  { id: "sh5", category: "shloka", text: "असतो मा सद्गमय। तमसो मा ज्योतिर्गमय। मृत्योर्मा अमृतं गमय॥", authorOrMeaning: "Lead me from ignorance to truth, darkness to light, mortality to the eternal. — Pavamana Mantra" },
  { id: "sh6", category: "shloka", text: "सत्यं वद। धर्मं चर। स्वाध्यायान्मा प्रमदः॥", authorOrMeaning: "Speak truth. Abide by righteous duty. Never neglect daily learning and self-study. — Taittiriya Upanishad" },
  { id: "sh7", category: "shloka", text: "विद्या ददाति विनयं विनयाद्याति पात्रताम्॥", authorOrMeaning: "Knowledge bestows humility, humility brings worthiness, and worthiness leads to righteous joy. — Subhashita" },
  { id: "sh8", category: "shloka", text: "यथा ह्येकेन चक्रेण न रथस्य गतिर्भवेत्। एवं पुरुषकारेण विना दैवं न सिध्यति॥", authorOrMeaning: "Just as a chariot cannot move on one wheel, destiny cannot fulfill itself without human effort. — Chanakya Neeti" },
  { id: "sh9", category: "shloka", text: "आ नो भद्राः क्रतवो यन्तु विश्वतः॥", authorOrMeaning: "May auspicious and noble thoughts flow to us from all directions of the universe. — Rigveda" },

  // 9. Kannada Shlokas & Vachana / Dasa Sahitya
  { id: "kn1", category: "kannada", text: "ಕಾಯಕವೇ ಕೈಲಾಸ (Kayakave Kailasa)", authorOrMeaning: "Work is worship; honest, dedicated labor itself is the celestial abode of God. — Jagadjyothi Basavanna" },
  { id: "kn2", category: "kannada", text: "ಉಳ್ಳವರು ಶಿವಾಲಯ ಮಾಡುವರು, ನಾನೇನು ಮಾಡಲಿ ಬಡವನಯ್ಯಾ? ಎನ್ನ ಕಾಲೇ ಕಂಬ, ದೇಹವೇ ದೇಗುಲ, ಶಿರವೇ ಹೊನ್ನ ಕಳಶವಯ್ಯಾ...", authorOrMeaning: "The wealthy build temples; my legs are pillars, body the shrine, head the golden pinnacle. — Basavanna" },
  { id: "kn3", category: "kannada", text: "ಮಾನವ ಜನ್ಮ ದೊಡ್ಡದು, ಇದ ಹಾಳು ಮಾಡಬೇಡಿ ಹುಚ್ಚಪ್ಪಗಳಿರಾ", authorOrMeaning: "Human birth is rare and noble, do not squander it in foolishness. Cleanse your mind and pursue wisdom. — Purandara Dasa" },
  { id: "kn4", category: "kannada", text: "ತಲ್ಲಣಿಸದಿರು ಕಂಡ್ಯ ತಾಳು ಮನವೇ, ಎಲ್ಲರನು ಕಾಯುವನು ಪೊರೆವನಿಹನೊಬ್ಬ", authorOrMeaning: "Do not despair or tremble, have patience, O mind! There is one divine protector for all creation. — Kanaka Dasa" },
  { id: "kn5", category: "kannada", text: "ಬೆಟ್ಟದ ಮೇಲೊಂದು ಹುಟ್ಟಿದ ವೃಕ್ಷಕೆ ಕಟ್ಟೆಯ ಕಟ್ಟಿ ನೀರೆರೆದವರಾರು?", authorOrMeaning: "Who watered the tree that grew on a barren rock? He who gave life will sustain it. Have faith. — Kanaka Dasa" },
  { id: "kn6", category: "kannada", text: "ಅರಿವೇ ಗುರು, ಜ್ಯೋತಿಯೇ ಲಿಂಗ", authorOrMeaning: "True self-awareness is the highest teacher; the inner light is supreme reality. — Allama Prabhu" },
  { id: "kn7", category: "kannada", text: "ಬದುಕು ಜಟಕಾಬಂಡಿ, ವಿಧಿ ಅದರ ಸಾಹೇಬ, ಕುದುರೆ ನೀನ್, ಅವನು ಹೇಳಿದಂತೆ ಪಯಣಿಗರು...", authorOrMeaning: "Life is a horse cart, destiny its driver, you are the horse; walk steadily with dignity. — DVG Mankuthimmana Kagga" },
  { id: "kn8", category: "kannada", text: "ಹುಲ್ಲಾಗು ಬೆಟ್ಟದಡಿ, ಮನೆಗೆ ಮಲ್ಲಿಗೆಯಾಗು, ಕಲ್ಲಾಗು ಕಷ್ಟಗಳ ಮಳೆಯ ವಿಧಿ ಸುರಿಯೆ...", authorOrMeaning: "Be humble like grass at the hill, fragrant like jasmine at home, enduring like stone in storms. — DVG Mankuthimmana Kagga" },
  { id: "kn9", category: "kannada", text: "ಭಾಗ್ಯದ ಲಕ್ಷ್ಮಿ ಬಾರಮ್ಮಾ, ನಮ್ಮಮ್ಮಾ ನೀ ಸೌಭಾಗ್ಯದ ಲಕ್ಷ್ಮಿ ಬಾರಮ್ಮಾ", authorOrMeaning: "Come into our hearts as radiant wisdom, noble conduct, and divine well-being. — Purandara Dasa" },

  // 10. Live FavQs & ZenQuotes
  { id: "api1", category: "api", text: "A good leader inspires other people to have confidence in them. A great leader inspires people to have confidence in themselves.", authorOrMeaning: "Arnold H. Glasow (FavQs QOTD)" },
  { id: "api2", category: "api", text: "To lead the people, walk behind them.", authorOrMeaning: "Lao Tzu (ZenQuotes Live)" },
];

const STORAGE_KEY = "ap_quotes_v1";

export interface StoredQuotesData {
  config: QuoteConfig;
  customQuotes: QuoteItem[];
  favorites: string[]; // ids
}

function getDefaultConfig(): QuoteConfig {
  return {
    enabledCategories: ["dream", "passion", "life", "saying", "idioms", "goal", "gateExam", "shloka", "kannada", "api"],
    rotationMinutes: 15,
    showInPetBubble: true,
    onlyFavorites: false,
    currentQuoteId: "ge1",
    lastRotatedAt: Date.now(),
  };
}

function loadStore(): StoredQuotesData {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { config: getDefaultConfig(), customQuotes: [], favorites: [] };
    const parsed = JSON.parse(raw);
    return {
      config: { ...getDefaultConfig(), ...(parsed.config || {}) },
      customQuotes: Array.isArray(parsed.customQuotes) ? parsed.customQuotes : [],
      favorites: Array.isArray(parsed.favorites) ? parsed.favorites : [],
    };
  } catch {
    return { config: getDefaultConfig(), customQuotes: [], favorites: [] };
  }
}

function saveStore(data: StoredQuotesData) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  window.dispatchEvent(new CustomEvent("quotes-changed"));
}

/** Get all quotes including defaults and custom ones, with favorite state marked */
export function getAllQuotes(): QuoteItem[] {
  const store = loadStore();
  const favSet = new Set(store.favorites);
  const items = [...DEFAULT_QUOTES, ...store.customQuotes];
  return items.map((q) => ({
    ...q,
    isFavorite: favSet.has(q.id),
  }));
}

/** Get current configuration */
export function getQuoteConfig(): QuoteConfig {
  return loadStore().config;
}

/** Update quote config */
export function updateQuoteConfig(patch: Partial<QuoteConfig>): QuoteConfig {
  const store = loadStore();
  store.config = { ...store.config, ...patch };
  saveStore(store);
  return store.config;
}

/** Toggle favorite status of a quote */
export function toggleQuoteFavorite(id: string): boolean {
  const store = loadStore();
  const favSet = new Set(store.favorites);
  let isNowFav = false;
  if (favSet.has(id)) {
    favSet.delete(id);
    isNowFav = false;
  } else {
    favSet.add(id);
    isNowFav = true;
  }
  store.favorites = Array.from(favSet);
  saveStore(store);
  return isNowFav;
}

/** Add a custom user quote */
export function addCustomQuote(text: string, authorOrMeaning: string, category: QuoteCategory): QuoteItem {
  const store = loadStore();
  const item: QuoteItem = {
    id: `custom_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
    text: text.trim(),
    authorOrMeaning: authorOrMeaning.trim(),
    category,
    isCustom: true,
  };
  store.customQuotes.unshift(item);
  saveStore(store);
  return item;
}

/** Delete a custom quote */
export function deleteCustomQuote(id: string): boolean {
  const store = loadStore();
  const len = store.customQuotes.length;
  store.customQuotes = store.customQuotes.filter((q) => q.id !== id);
  store.favorites = store.favorites.filter((fid) => fid !== id);
  if (store.customQuotes.length !== len) {
    saveStore(store);
    return true;
  }
  return false;
}

/** Get candidate quotes based on enabled categories and favorite filter */
export function getEligibleQuotes(): QuoteItem[] {
  const store = loadStore();
  const all = getAllQuotes();
  const enabled = new Set(store.config.enabledCategories);
  return all.filter((q) => {
    if (!enabled.has(q.category)) return false;
    if (store.config.onlyFavorites && !q.isFavorite) return false;
    return true;
  });
}

/** Get current active quote or pick a new one */
export function getCurrentQuote(): QuoteItem {
  const store = loadStore();
  const eligible = getEligibleQuotes();
  if (eligible.length === 0) {
    return DEFAULT_QUOTES[0];
  }
  if (store.config.currentQuoteId) {
    const hit = eligible.find((q) => q.id === store.config.currentQuoteId);
    if (hit) return hit;
  }
  // If not found or rotated out, pick first eligible
  return eligible[0];
}

/** Pick the next quote from eligible pool */
export function getNextQuote(): QuoteItem {
  const store = loadStore();
  const eligible = getEligibleQuotes();
  if (eligible.length === 0) return DEFAULT_QUOTES[0];

  const curId = store.config.currentQuoteId;
  const curIdx = eligible.findIndex((q) => q.id === curId);
  const nextIdx = (curIdx + 1) % eligible.length;
  const next = eligible[nextIdx];

  store.config.currentQuoteId = next.id;
  store.config.lastRotatedAt = Date.now();
  saveStore(store);
  return next;
}

/** Check if rotation timer is due and advance quote if so */
export function checkQuoteRotation(): QuoteItem {
  const store = loadStore();
  const now = Date.now();
  const intervalMs = Math.max(1, store.config.rotationMinutes) * 60_000;
  const last = store.config.lastRotatedAt || 0;

  if (now - last >= intervalMs) {
    return getNextQuote();
  }
  return getCurrentQuote();
}

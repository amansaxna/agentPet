// windows/src/voice.ts
// Native Web Speech API verbal communicator for AgentPet

export type VoiceSpeechItem =
  | "quotes"
  | "agentCompletion"
  | "hourlyChime"
  | "waterReminder"
  | "breakReminder"
  | "focusPhase"
  | "customReminder";

export interface VoiceItemMeta {
  id: VoiceSpeechItem;
  title: string;
  description: string;
  icon: string;
  testPhrase: string;
}

export const VOICE_ITEMS: VoiceItemMeta[] = [
  {
    id: "quotes",
    title: "Quotes & Shlokas",
    description: "Reads rotating quotes, mantras, or Sanskrit and Kannada shlokas aloud.",
    icon: "💬",
    testPhrase: "Wisdom note: Work is worship. Dedicated and honest labor is the highest path to divinity.",
  },
  {
    id: "agentCompletion",
    title: "Agentic Work Completion",
    description: "Announces when an AI coding agent (Claude, Codex, Antigravity) finishes a task.",
    icon: "✅",
    testPhrase: "Antigravity completed task in LogViewer. Base camp reached, all tests passed.",
  },
  {
    id: "hourlyChime",
    title: "Hourly Day Progress & Chime",
    description: "Speaks the current hour, elapsed percentage of the day, and bedtime proximity.",
    icon: "⏰",
    testPhrase: "It is 11:00 PM. 95% of your day has passed. Bedtime marker has been reached.",
  },
  {
    id: "waterReminder",
    title: "Water & Hydration Reminders",
    description: "Reminds you verbally to take a sip of water and stay hydrated.",
    icon: "💧",
    testPhrase: "Hydration reminder: Time to take a drink of water and stay energized.",
  },
  {
    id: "breakReminder",
    title: "Break & Rest Reminders",
    description: "Alerts you verbally when continuous screen time reaches the rest threshold.",
    icon: "☕",
    testPhrase: "Rest reminder: Please step away from the screen for 2 minutes to rest your eyes.",
  },
  {
    id: "focusPhase",
    title: "Pomodoro & Focus Phase Changes",
    description: "Announces focus interval start, break commencement, and session transitions.",
    icon: "⏱",
    testPhrase: "Focus block completed. Outstanding effort! Time for a 5-minute break.",
  },
  {
    id: "customReminder",
    title: "Custom Scheduled Reminders",
    description: "Speaks out user-scheduled tasks and milestone deadlines when they fall due.",
    icon: "🔔",
    testPhrase: "Scheduled reminder: Engineering Mathematics revision is due now.",
  },
];

export interface VoiceConfig {
  masterEnabled: boolean;
  selectedVoiceURI: string;
  speechRate: number; // 0.5 to 1.5
  volume: number; // 0.0 to 1.0
  enabledItems: VoiceSpeechItem[];
}

const DEFAULT_CONFIG: VoiceConfig = {
  masterEnabled: false,
  selectedVoiceURI: "",
  speechRate: 1.0,
  volume: 0.85,
  enabledItems: ["agentCompletion", "quotes"],
};

class VoiceService {
  private config: VoiceConfig = { ...DEFAULT_CONFIG };
  private synth: SpeechSynthesis | null = null;
  private voices: SpeechSynthesisVoice[] = [];

  constructor() {
    if (typeof window !== "undefined" && "speechSynthesis" in window) {
      this.synth = window.speechSynthesis;
      this.loadVoices();
      if (this.synth.onvoiceschanged !== undefined) {
        this.synth.onvoiceschanged = () => this.loadVoices();
      }
    }
    this.loadConfig();
  }

  private loadConfig() {
    try {
      const saved = localStorage.getItem("ap_voice_config");
      if (saved) {
        this.config = { ...DEFAULT_CONFIG, ...JSON.parse(saved) };
      }
    } catch {}
  }

  private saveConfig() {
    try {
      localStorage.setItem("ap_voice_config", JSON.stringify(this.config));
    } catch {}
  }

  private loadVoices() {
    if (!this.synth) return;
    this.voices = this.synth.getVoices().filter((v) => v.lang.startsWith("en") || v.lang.startsWith("kn") || v.lang.startsWith("hi"));
  }

  getVoices(): SpeechSynthesisVoice[] {
    return this.voices;
  }

  getConfig(): VoiceConfig {
    return { ...this.config };
  }

  updateConfig(patch: Partial<VoiceConfig>) {
    this.config = { ...this.config, ...patch };
    this.saveConfig();
  }

  toggleMaster(): boolean {
    this.config.masterEnabled = !this.config.masterEnabled;
    this.saveConfig();
    if (!this.config.masterEnabled) {
      this.stop();
    }
    return this.config.masterEnabled;
  }

  toggleItem(item: VoiceSpeechItem): boolean {
    const set = new Set(this.config.enabledItems);
    if (set.has(item)) {
      set.delete(item);
    } else {
      set.add(item);
    }
    this.config.enabledItems = Array.from(set);
    this.saveConfig();
    return set.has(item);
  }

  isItemEnabled(item: VoiceSpeechItem): boolean {
    return this.config.enabledItems.includes(item);
  }

  speak(text: string, item?: VoiceSpeechItem, force = false) {
    if (!this.synth) return;
    if (!force) {
      if (!this.config.masterEnabled) return;
      if (item && !this.isItemEnabled(item)) return;
    }

    if (this.synth.speaking) {
      this.synth.cancel();
    }

    const utter = new SpeechSynthesisUtterance(text);
    if (this.config.selectedVoiceURI) {
      const matched = this.voices.find((v) => v.voiceURI === this.config.selectedVoiceURI);
      if (matched) utter.voice = matched;
    }
    utter.rate = this.config.speechRate;
    utter.volume = this.config.volume;
    this.synth.speak(utter);
  }

  testSpeech(item: VoiceSpeechItem) {
    const meta = VOICE_ITEMS.find((v) => v.id === item);
    if (meta) {
      this.speak(meta.testPhrase, item, true);
    }
  }

  stop() {
    if (this.synth) {
      this.synth.cancel();
    }
  }
}

export const voiceService = new VoiceService();

<div align="center">
  <img src="assets/banner.png" alt="AgentPet" width="100%" />
  <p>
    <img src="https://img.shields.io/badge/platform-macOS%2013%2B-black" alt="macOS 13+" />
    <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT" />
    <img src="https://img.shields.io/badge/Swift-SwiftUI-orange" alt="Swift" />
    <img src="https://img.shields.io/badge/Frontier%20AI%20Voice-Gemini%20%7C%20Kokoro%20%7C%20ChatGPT-purple" alt="AI Voice" />
    <img src="https://img.shields.io/badge/Local%20Neural%20TTS-Kokoro--82M%20(INT8)-success" alt="Kokoro Local" />
  </p>
  <p><b>An ambient desktop companion that reacts while your AI coding agents work, speaks with frontier neural voices, and keeps you focused throughout your day.</b></p>
</div>

---

## Overview

When you run multiple coding agents (Claude Code, Codex, Gemini CLI, Cursor, Antigravity, and more), it is easy to lose track of who is **working**, who is **finished**, and who is **waiting for your input**.

**AgentPet** solves this at a glance:
- A lightweight **menu-bar monitor** tracks every agent's live state and active runtime.
- An animated **desktop pixel companion** floats unobtrusively on your screen and reacts dynamically to your work.
- An intelligent **Verbal Communicator** announces completions, focus phase shifts, and daily milestones using frontier AI neural voices (Google Gemini, OpenAI ChatGPT, ElevenLabs) or 100% offline local neural voices (Kokoro-82M).
- A complete **Day Progress & Focus Suite** with 24-hour sleep/wake arcs, target exam/project countdowns, ambient audio, and motivational quotes.

---

## Key Capabilities

### 🎙️ Frontier & Offline Neural Voice Communicator
- **Google Gemini 2.5 Flash Neural Speech**: Expressive cloud voices (`Aoede`, `Kore`, `Puck`, `Charon`, `Fenrir`) using Gemini's official 100% free tier (1,500 requests/day, zero credit card required).
- **Kokoro-82M Local Neural TTS**: Pre-bundled, quantized INT8 neural model (~88 MB) running 100% locally on your Mac. Studio quality, zero API keys, and zero cloud latency.
- **OpenAI ChatGPT Voice**: High-energy conversational voices (`Nova`, `Shimmer`, `Alloy`, `Echo`, `Fable`, `Onyx`).
- **ElevenLabs Studio**: Ultra-realistic voices (`Rachel`, `Domi`, `Bella`, `Antoni`).
- **Apple System & Enhanced Voices**: Offline macOS neural voices with automatic detection of Siri Natural / Enhanced packages.
- **Inline Preview & Auditioning**: Every voice preset includes a dedicated `▶ Test` button to preview any voice instantly before selecting it.
- **Configurable Speech Intakes**: Choose exactly what your pet announces: agent task completions, focus timer intervals, hydration reminders, hourly day chimes, and wisdom quotes.

### 🐾 Ambient Desktop Companion (Tamagotchi Engine)
- **State-Aware Reactions**: Idles quietly when coding, types excitedly when an agent works, and perks up with an alert bubble when an agent needs user input.
- **Token-Fed Progression**: The companion eats real tokens burned by your coding agents and sessions completed, earning XP to evolve through 5 distinct growth stages.
- **Achievements & Streaks**: 14 unlockable achievements, feeding streaks, and hunger meters.
- **Customizable Sprites**: Supports the open Codex/Petdex pet-pack format (`pet.json` + spritesheet).

### 🎯 Companion Dashboard & Productivity Suite
- **24-Hour Day Progress & Sleep Arc**: Visual daylight/nighttime tracker with customizable bedtime chime reminders.
- **Target Countdown Tracker**: Pin your primary milestone (e.g., target exam, product release, thesis deadline) with elapsed and remaining day counters.
- **Focus Clock & Suite**: Integrated Pomodoro timer, stopwatch, and countdown clock.
- **Ambient Focus Audio**: Built-in soundscapes (Lofi, White noise, Rain) to maintain deep work flow.
- **Dream Quotes & Wisdom Engine**: Automated rotation of philosophical quotes, shlokas, and wisdom notes.

### 🔌 Multi-Agent Hook System
Supports all major autonomous and interactive coding agents out of the box:

| Agent | Detection & State |
|---|---|
| **Claude Code** | Working · Waiting for Input · Done |
| **OpenAI Codex** | Working · Waiting for Input · Done |
| **Google Gemini CLI** | Working · Waiting for Input · Done |
| **opencode / Factory Droid** | Working · Waiting for Input · Done |
| **Cursor / Windsurf / Antigravity** | Working · Done |
| **GitHub Copilot / Kiro CLI** | Working · Done |
| **Universal CLI Wrapper** | `agentpet run -- <command>` |

---

## Getting Started

### Prerequisites
- macOS 13.0 (Ventura) or later (Apple Silicon or Intel).
- Xcode 16 / Swift 6 or Xcode Command Line Tools.

### Building from Source

```bash
# 1. Clone the repository
git clone https://github.com/amansaxna/agentPet.git
cd agentPet

# 2. Build the release application bundle
./scripts/build-app.sh release

# 3. Launch AgentPet
open build/AgentPet.app
```

To install permanently into your system applications:
```bash
cp -R build/AgentPet.app /Applications/
open /Applications/AgentPet.app
```

---

## Voice Configuration

1. Click the **AgentPet** menu bar icon and select **Settings** (or press `⌘,`).
2. Navigate to the **Voice** tab.
3. Turn on the **Verbal Communicator** master switch.
4. Select your preferred engine:
   - **Kokoro-82M Local Neural**: 100% offline, zero setup required.
   - **Google Gemini Neural**: Paste your Gemini API key (free tier available at [Google AI Studio](https://aistudio.google.com/)).
   - **OpenAI ChatGPT**: Paste your OpenAI API key.
   - **Apple System**: Select any installed macOS voice.
5. Click the **`▶ Test`** button beside any voice row to audition it immediately.

---

## Project Structure

```
AgentPet/
├── Sources/
│   ├── AgentPetCore/        # Core models, socket daemon, hooks, FrontierVoiceService
│   └── App/                 # SwiftUI interface, MenuBar, PetWindow, Settings, VoiceController
├── scripts/
│   ├── build-app.sh         # App bundle assembly & packaging script
│   ├── kokoro_tts.py        # Kokoro ONNX local neural inference runner
│   └── setup-kokoro.sh      # Automated local neural model downloader
├── Assets/                  # App icons, sound effects, sprite animations
└── Tests/                   # Unit test suite
```

---

## 🌟 Upstream Credits & Acknowledgements

This software is an enhanced fork of the open-source **[AgentPet](https://github.com/ntd4996/agentpet)** project initially created by **[Nguyễn Thành Đạt (@ntd4996)](https://github.com/ntd4996)** and community contributors.

We express our sincere gratitude to the original authors and the open-source ecosystem for establishing the initial multi-agent monitoring foundation, Unix-socket IPC daemon, and pixel sprite animation engine.

### Enhancements in this Fork:
- **Integrated Frontier & Local Neural Voice Engine**: Support for Google Gemini 2.5 Flash TTS, pre-bundled Kokoro-82M INT8 offline neural speech, ChatGPT TTS, and ElevenLabs.
- **Inline Voice Auditioning**: Dedicated test buttons on all voice presets for quick evaluation.
- **Unified Companion Dashboard**: 24-hour day progress arc, bedtime reminders, milestone target tracker, dream quotes/shlokas engine, and ambient sound player.
- **Privacy & Sandbox Hardening**: Model and script resolution strictly confined to app resources and `Application Support`, preventing unnecessary macOS permission alerts.

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
Pet sprite packs belong to their respective creators under their own licenses.

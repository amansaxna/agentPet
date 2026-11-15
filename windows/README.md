# AgentPet for Windows

A lightweight, hardware-accelerated desktop pet that floats on your screen and reacts in real time to your AI coding agents (**Claude Code**, **Codex**, **Gemini CLI**, **Cursor**, **opencode**, **Windsurf**, **Antigravity**, **GitHub Copilot**, **Kiro CLI**).

Built with **Rust** and **[Tauri v2](https://tauri.app)**, keeping runtime memory small (~15 MB) while utilizing native Win32 layered window APIs for transparent click-through.

---

## Installation

Download the latest production installers from the **[GitHub Releases Page](https://github.com/amansaxna/agentPet/releases/latest)**.

### Method 1: Standard NSIS Setup Installer (`.exe`) — Recommended
1. Download **`AgentPet_1.18.1_x64-setup.exe`**.
2. Run the executable. It installs per-user into `%LOCALAPPDATA%\Programs\AgentPet` without requiring Administrator rights.
3. **SmartScreen Bypass**:
   > Because open-source community releases are not signed with an expensive corporate EV certificate, Windows SmartScreen may show *"Windows protected your PC"*.
   > 1. Click **More info**.
   > 2. Click **Run anyway**.
4. AgentPet will launch immediately and place an icon in your Windows system tray.

### Method 2: Enterprise / Automated MSI Package (`.msi`)
1. Download **`AgentPet_1.18.1_x64_en-US.msi`**.
2. Double-click to run the standard Windows Installer, or deploy silently across machines:
   ```powershell
   msiexec.exe /i AgentPet_1.18.1_x64_en-US.msi /qn
   ```

### Method 3: Portable Standalone (`.zip`)
1. Download **`AgentPet-portable-x64.zip`**.
2. Extract anywhere (e.g. `C:\Tools\AgentPet\`).
3. Launch `agentpet.exe` directly. Leaves zero registry traces.

---

## How It Works

```
AI Agent Hook ──(stdin JSON)──► agentpet.exe hook --agent <kind>
                                       │ POST /event
                                       ▼
                           localhost:47628 (Rust HTTP Listener in running app)
                                       │ emit "agent-event"
                                       ▼
                           Pet Overlay Window (Tauri WebView2 Canvas Sprite)
```

1. **Lightweight IPC**: The same `agentpet.exe` binary serves both as the graphical companion and the hook CLI dispatcher. Running `agentpet hook --agent claude` reads the agent's JSON event from stdin and dispatches an HTTP POST to the local listener.
2. **Fail-Safe Exit**: Hook calls always exit with status code `0`, ensuring that an agent tool execution (e.g. Copilot PreToolUse) is never blocked even if the desktop pet is closed.
3. **True Click-Through Transparency**: Utilizes native Win32 window styles (`WS_EX_LAYERED` | `WS_EX_TRANSPARENT`). Only opaque sprite pixels capture mouse clicks; all transparent window margins allow direct interaction with IDEs and editors underneath.

---

## Agent Hook Setup

Register hooks with your coding agents automatically:

```powershell
# In PowerShell:
.\agentpet.exe hook --agent claude
.\agentpet.exe hook --agent codex
.\agentpet.exe hook --agent gemini
```

Or configure manually in `%USERPROFILE%\.claude\settings.json`:
```json
{
  "hooks": {
    "postToolExecution": "agentpet hook --agent claude",
    "notification": "agentpet hook --agent claude"
  }
}
```

---

## Local Development & Compilation

### Prerequisites
- Node.js 20+
- Rust toolchain (`stable-x86_64-pc-windows-msvc`)
- Visual Studio C++ Build Tools (with Windows 10/11 SDK)

### Run in Development
```bash
npm install
npm run dev        # Starts Vite dev server with hot reload
npm run tauri dev  # Runs live Tauri window
```

### Production Build
```bash
npm run build      # Typechecks with tsc and bundles Vite assets
npm run tauri build # Packages NSIS .exe and WiX .msi installers
```

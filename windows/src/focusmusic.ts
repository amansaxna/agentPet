// windows/src/focusmusic.ts
// Focus music & ambient soundscapes engine for deep work
// Synchronized across all Tauri windows via events; audio element runs exclusively in the host pet window.

import { emit, listen } from "@tauri-apps/api/event";

export interface FocusMusicStation {
  id: string;
  title: string;
  description: string;
  icon: string;
  streamURL: string;
}

export interface FocusMusicState {
  isPlaying: boolean;
  currentStationId: string;
  volume: number;
}

export const STATIONS: FocusMusicStation[] = [
  {
    id: "violin_classical",
    title: "Classical Violin & Strings",
    description: "Soothing violin concertos, sonatas & string ensembles",
    icon: "🎻",
    streamURL: "https://stream.wqxr.org/wqxr",
  },
  {
    id: "violin_acoustic",
    title: "Acoustic Violin & Fiddle",
    description: "Melodic Celtic & acoustic violin strings for focus",
    icon: "🎻",
    streamURL: "https://ice2.somafm.com/thistle-128-mp3",
  },
  {
    id: "groove_salad",
    title: "Lofi & Downtempo Chill",
    description: "Ambient electronic & chill grooves for coding",
    icon: "🎧",
    streamURL: "https://ice2.somafm.com/groovesalad-128-mp3",
  },
  {
    id: "drone_zone",
    title: "Deep Space Drone",
    description: "Atmospheric ambient for deep immersion",
    icon: "✨",
    streamURL: "https://ice2.somafm.com/dronezone-128-mp3",
  },
  {
    id: "lush",
    title: "Lush Mellow Beats",
    description: "Sensuous acoustic & mellow electronica",
    icon: "🌿",
    streamURL: "https://ice2.somafm.com/lush-128-mp3",
  },
  {
    id: "defcon",
    title: "Cyberpunk Focus Chill",
    description: "Electronic study beats from DEF CON",
    icon: "⚡",
    streamURL: "https://ice2.somafm.com/defcon-128-mp3",
  },
  {
    id: "space_station",
    title: "Space Station Soma",
    description: "Mid-tempo ambient electronica & space chill",
    icon: "🌙",
    streamURL: "https://ice2.somafm.com/spacestation-128-mp3",
  },
];

function isPetHostWindow(): boolean {
  if (typeof window === "undefined" || typeof document === "undefined") return false;
  return !!document.getElementById("pet") ||
         !!document.getElementById("pet-root") ||
         location.pathname.endsWith("index.html") ||
         location.pathname === "/" ||
         location.pathname === "";
}

class FocusMusicService {
  private audio: HTMLAudioElement | null = null;
  private currentStationId = "groove_salad";
  private isPlaying = false;
  private volume = 0.6;
  private isHost = false;
  private isHostInitialized = false;

  constructor() {
    this.isHost = isPetHostWindow();

    try {
      const saved = localStorage.getItem("ap_focus_music_station");
      if (saved && STATIONS.some((s) => s.id === saved)) {
        this.currentStationId = saved;
      }
      const savedVol = localStorage.getItem("ap_focus_music_volume");
      if (savedVol) {
        this.volume = Math.max(0, Math.min(1, parseFloat(savedVol)));
      }
    } catch {
      // ignore
    }

    if (this.isHost) {
      this.initHost();
    } else {
      this.initClient();
    }
  }

  public startHost() {
    this.isHost = true;
    this.initHost();
  }

  private initHost() {
    if (this.isHostInitialized) return;
    this.isHostInitialized = true;
    try {
      listen<{ action: string; stationId?: string; volume?: number }>("ap-music-cmd", (event) => {
        const payload = event.payload;
        if (!payload) return;
        switch (payload.action) {
          case "play":
            this.playInternal();
            break;
          case "stop":
            this.stopInternal();
            break;
          case "toggle":
            this.toggleInternal();
            break;
          case "next":
            this.nextStationInternal();
            break;
          case "select":
            if (payload.stationId) this.selectStationInternal(payload.stationId);
            break;
          case "volume":
            if (typeof payload.volume === "number") this.setVolumeInternal(payload.volume);
            break;
        }
      }).catch(() => {});

      listen("ap-music-request-state", () => {
        this.broadcastState();
      }).catch(() => {});
    } catch {}
  }

  private initClient() {
    try {
      listen<FocusMusicState>("ap-music-state", (event) => {
        if (!event.payload) return;
        this.isPlaying = event.payload.isPlaying;
        this.currentStationId = event.payload.currentStationId;
        this.volume = event.payload.volume;
        this.notifyChange();
      }).catch(() => {});

      emit("ap-music-request-state", null).catch(() => {});
    } catch {}
  }

  private getState(): FocusMusicState {
    return {
      isPlaying: this.isPlaying,
      currentStationId: this.currentStationId,
      volume: this.volume,
    };
  }

  private broadcastState() {
    const state = this.getState();
    try {
      emit("ap-music-state", state).catch(() => {});
    } catch {}
    this.notifyChange();
  }

  private notifyChange() {
    if (typeof window !== "undefined") {
      window.dispatchEvent(new CustomEvent("focusmusic-changed", { detail: this.getState() }));
    }
  }

  getPlaying(): boolean {
    return this.isPlaying;
  }

  getCurrentStation(): FocusMusicStation {
    return STATIONS.find((s) => s.id === this.currentStationId) || STATIONS[0];
  }

  getVolume(): number {
    return this.volume;
  }

  setVolume(vol: number) {
    if (!this.isHost) {
      this.volume = Math.max(0, Math.min(1, vol));
      emit("ap-music-cmd", { action: "volume", volume: this.volume }).catch(() => {});
      return;
    }
    this.setVolumeInternal(vol);
  }

  private setVolumeInternal(vol: number) {
    this.volume = Math.max(0, Math.min(1, vol));
    if (this.audio) this.audio.volume = this.volume;
    try {
      localStorage.setItem("ap_focus_music_volume", this.volume.toString());
    } catch {}
    this.broadcastState();
  }

  selectStation(stationId: string) {
    if (!this.isHost) {
      this.currentStationId = stationId;
      emit("ap-music-cmd", { action: "select", stationId }).catch(() => {});
      return;
    }
    this.selectStationInternal(stationId);
  }

  private selectStationInternal(stationId: string) {
    const wasPlaying = this.isPlaying;
    if (this.isPlaying) this.stopInternal();
    this.currentStationId = stationId;
    try {
      localStorage.setItem("ap_focus_music_station", stationId);
    } catch {}
    if (wasPlaying) {
      this.playInternal();
    } else {
      this.broadcastState();
    }
  }

  nextStation() {
    if (!this.isHost) {
      emit("ap-music-cmd", { action: "next" }).catch(() => {});
      return;
    }
    this.nextStationInternal();
  }

  private nextStationInternal() {
    const currentIndex = STATIONS.findIndex((s) => s.id === this.currentStationId);
    const nextIndex = (currentIndex + 1) % STATIONS.length;
    this.selectStationInternal(STATIONS[nextIndex].id);
  }

  toggle(): boolean {
    if (!this.isHost) {
      emit("ap-music-cmd", { action: "toggle" }).catch(() => {});
      return !this.isPlaying;
    }
    return this.toggleInternal();
  }

  private toggleInternal(): boolean {
    if (this.isPlaying) {
      this.stopInternal();
    } else {
      this.playInternal();
    }
    return this.isPlaying;
  }

  play() {
    if (!this.isHost) {
      emit("ap-music-cmd", { action: "play" }).catch(() => {});
      return;
    }
    this.playInternal();
  }

  private playInternal() {
    const station = this.getCurrentStation();
    if (!this.audio) {
      this.audio = new Audio(station.streamURL);
      // Do NOT set crossOrigin = "anonymous" because shoutcast/icecast servers don't serve CORS headers
    } else {
      this.audio.src = station.streamURL;
    }
    this.audio.volume = this.volume;

    this.audio.onerror = () => {
      this.isPlaying = false;
      this.broadcastState();
    };

    this.audio.onended = () => {
      this.isPlaying = false;
      this.broadcastState();
    };

    this.audio.play().then(() => {
      this.isPlaying = true;
      this.broadcastState();
    }).catch(() => {
      this.isPlaying = false;
      this.broadcastState();
    });

    this.isPlaying = true;
    this.broadcastState();
  }

  stop() {
    if (!this.isHost) {
      emit("ap-music-cmd", { action: "stop" }).catch(() => {});
      return;
    }
    this.stopInternal();
  }

  private stopInternal() {
    if (this.audio) {
      try {
        this.audio.pause();
        this.audio.src = "";
      } catch {}
    }
    this.isPlaying = false;
    this.broadcastState();
  }
}

export const focusMusic = new FocusMusicService();

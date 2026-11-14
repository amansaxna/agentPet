// windows/src/focusmusic.ts
// Focus music & ambient soundscapes engine for deep work

export interface FocusMusicStation {
  id: string;
  title: string;
  description: string;
  icon: string;
  streamURL: string;
}

export const STATIONS: FocusMusicStation[] = [
  {
    id: "violin_classical",
    title: "Classical Violin & Strings",
    description: "Soothing violin concertos, sonatas & string ensembles",
    icon: "🎻",
    streamURL: "https://stream.srg-ssr.ch/m/rsc_de/mp3_128",
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

class FocusMusicService {
  private audio: HTMLAudioElement | null = null;
  private currentStationId = "groove_salad";
  private isPlaying = false;
  private volume = 0.6;

  constructor() {
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
    this.volume = Math.max(0, Math.min(1, vol));
    if (this.audio) this.audio.volume = this.volume;
    try {
      localStorage.setItem("ap_focus_music_volume", this.volume.toString());
    } catch {}
  }

  selectStation(stationId: string) {
    const wasPlaying = this.isPlaying;
    if (this.isPlaying) this.stop();
    this.currentStationId = stationId;
    try {
      localStorage.setItem("ap_focus_music_station", stationId);
    } catch {}
    if (wasPlaying) this.play();
  }

  toggle(): boolean {
    if (this.isPlaying) {
      this.stop();
    } else {
      this.play();
    }
    return this.isPlaying;
  }

  play() {
    const station = this.getCurrentStation();
    if (!this.audio) {
      this.audio = new Audio(station.streamURL);
      this.audio.crossOrigin = "anonymous";
    } else {
      this.audio.src = station.streamURL;
    }
    this.audio.volume = this.volume;
    this.audio.play().catch(() => {
      this.isPlaying = false;
    });
    this.isPlaying = true;
  }

  stop() {
    if (this.audio) {
      this.audio.pause();
      this.audio.src = "";
    }
    this.isPlaying = false;
  }
}

export const focusMusic = new FocusMusicService();

// windows/src/focusclock.ts
// Focus Clock Engine: Countdown Timer & Stopwatch
// Synchronized across Tauri windows with PetCare XP and WorkTracker integration.

import { emit, listen } from "@tauri-apps/api/event";
import * as care from "./care";
import { savedSlug } from "./catalog";
import * as worktracker from "./worktracker";
import { getPrimaryGoal } from "./goals";

export type FocusClockState = "idle" | "running" | "paused" | "completed";
export type FocusMode = "pomodoro" | "timer" | "stopwatch";

export interface CountdownTimerState {
  state: FocusClockState;
  targetSeconds: number;
  secondsRemaining: number;
  activeSubject: string;
  lastTick: number | null;
}

export interface StopwatchState {
  state: FocusClockState;
  elapsedSeconds: number;
  activeSubject: string;
  laps: number[];
  lastTick: number | null;
}

export interface FocusClockFullState {
  timer: CountdownTimerState;
  stopwatch: StopwatchState;
  activeMode: FocusMode;
}

const STORAGE_TIMER_KEY = "ap_focus_timer_v1";
const STORAGE_STOPWATCH_KEY = "ap_focus_stopwatch_v1";
const STORAGE_ACTIVE_MODE_KEY = "ap_focus_mode_v1";

export const TIMER_PRESETS = [5, 10, 15, 25, 45, 60];

export function formatFocusTime(totalSeconds: number): string {
  const total = Math.max(0, Math.floor(totalSeconds));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  if (h > 0) {
    return `${h.toString().padStart(2, "0")}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
  }
  return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
}

export function playClockSound(type: "start" | "done" | "lap" | "tick") {
  try {
    const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    if (!AudioCtx) return;
    const ctx = new AudioCtx();
    const now = ctx.currentTime;

    if (type === "start") {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "sine";
      osc.frequency.setValueAtTime(523.25, now); // C5
      osc.frequency.exponentialRampToValueAtTime(659.25, now + 0.12); // E5
      gain.gain.setValueAtTime(0.12, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.25);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now);
      osc.stop(now + 0.25);
    } else if (type === "done") {
      const notes = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6
      notes.forEach((freq, idx) => {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = "triangle";
        osc.frequency.setValueAtTime(freq, now + idx * 0.12);
        gain.gain.setValueAtTime(0.18, now + idx * 0.12);
        gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.12 + 0.35);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(now + idx * 0.12);
        osc.stop(now + idx * 0.12 + 0.35);
      });
    } else if (type === "lap") {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "sine";
      osc.frequency.setValueAtTime(880, now); // A5
      gain.gain.setValueAtTime(0.1, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now);
      osc.stop(now + 0.15);
    }
  } catch {}
}

function isPetHostWindow(): boolean {
  if (typeof window === "undefined" || typeof document === "undefined") return false;
  return !!document.getElementById("pet") ||
         !!document.getElementById("pet-root") ||
         location.pathname.endsWith("index.html") ||
         location.pathname === "/" ||
         location.pathname === "";
}

class FocusClockService {
  private timer: CountdownTimerState = {
    state: "idle",
    targetSeconds: 15 * 60,
    secondsRemaining: 15 * 60,
    activeSubject: "Focus Session",
    lastTick: null,
  };

  private stopwatch: StopwatchState = {
    state: "idle",
    elapsedSeconds: 0,
    activeSubject: "Study Session",
    laps: [],
    lastTick: null,
  };

  private activeMode: FocusMode = "pomodoro";
  private isHost = false;
  private tickInterval: number | null = null;
  private isHostInitialized = false;

  constructor() {
    this.isHost = isPetHostWindow();
    this.loadPersisted();

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

  private loadPersisted() {
    try {
      const rawMode = localStorage.getItem(STORAGE_ACTIVE_MODE_KEY);
      if (rawMode === "pomodoro" || rawMode === "timer" || rawMode === "stopwatch") {
        this.activeMode = rawMode;
      }
      const rawTimer = localStorage.getItem(STORAGE_TIMER_KEY);
      if (rawTimer) {
        this.timer = { ...this.timer, ...JSON.parse(rawTimer) };
      }
      const rawStopwatch = localStorage.getItem(STORAGE_STOPWATCH_KEY);
      if (rawStopwatch) {
        this.stopwatch = { ...this.stopwatch, ...JSON.parse(rawStopwatch) };
      }
    } catch {}
  }

  private persist() {
    try {
      localStorage.setItem(STORAGE_ACTIVE_MODE_KEY, this.activeMode);
      localStorage.setItem(STORAGE_TIMER_KEY, JSON.stringify(this.timer));
      localStorage.setItem(STORAGE_STOPWATCH_KEY, JSON.stringify(this.stopwatch));
    } catch {}
  }

  private initHost() {
    if (this.isHostInitialized) return;
    this.isHostInitialized = true;

    try {
      listen<{ action: string; [key: string]: unknown }>("ap-focusclock-cmd", (event) => {
        const payload = event.payload;
        if (!payload) return;
        switch (payload.action) {
          case "set-mode":
            if (typeof payload.mode === "string") this.setActiveMode(payload.mode as FocusMode);
            break;
          case "start-timer":
            this.startTimerInternal(Number(payload.minutes) || 15, payload.subject as string | undefined);
            break;
          case "pause-timer":
            this.pauseTimerInternal();
            break;
          case "resume-timer":
            this.resumeTimerInternal();
            break;
          case "add-timer-minutes":
            this.addTimerMinutesInternal(Number(payload.minutes) || 5);
            break;
          case "stop-timer":
            this.stopTimerInternal();
            break;
          case "reset-timer":
            this.resetTimerInternal();
            break;
          case "start-stopwatch":
            this.startStopwatchInternal(payload.subject as string | undefined);
            break;
          case "pause-stopwatch":
            this.pauseStopwatchInternal();
            break;
          case "resume-stopwatch":
            this.resumeStopwatchInternal();
            break;
          case "lap-stopwatch":
            this.lapStopwatchInternal();
            break;
          case "stop-stopwatch":
            this.stopStopwatchInternal();
            break;
          case "reset-stopwatch":
            this.resetStopwatchInternal();
            break;
        }
      }).catch(() => {});

      listen("ap-focusclock-request-state", () => {
        this.broadcastState();
      }).catch(() => {});
    } catch {}

    this.startHeartbeat();
  }

  private initClient() {
    try {
      listen<FocusClockFullState>("ap-focusclock-state", (event) => {
        if (!event.payload) return;
        this.timer = event.payload.timer;
        this.stopwatch = event.payload.stopwatch;
        this.activeMode = event.payload.activeMode;
        this.notifyChange();
      }).catch(() => {});

      emit("ap-focusclock-request-state", null).catch(() => {});
    } catch {}
  }

  private startHeartbeat() {
    if (this.tickInterval) clearInterval(this.tickInterval);
    this.tickInterval = window.setInterval(() => {
      this.tick();
    }, 1000);
  }

  private tick() {
    let changed = false;
    const now = Date.now();

    // Reload persisted state
    this.loadPersisted();

    // Timer tick
    if (this.timer.state === "running") {
      const delta = this.timer.lastTick ? Math.min(10, Math.max(0.5, (now - this.timer.lastTick) / 1000)) : 1;
      this.timer.lastTick = now;
      this.timer.secondsRemaining = Math.max(0, this.timer.secondsRemaining - delta);
      changed = true;

      if (this.timer.secondsRemaining <= 0) {
        this.timer.state = "completed";
        this.timer.secondsRemaining = 0;
        this.timer.lastTick = null;
        playClockSound("done");
        this.onTimerCompleted();
      }
    }

    // Stopwatch tick
    if (this.stopwatch.state === "running") {
      const delta = this.stopwatch.lastTick ? Math.min(10, Math.max(0.5, (now - this.stopwatch.lastTick) / 1000)) : 1;
      this.stopwatch.lastTick = now;
      this.stopwatch.elapsedSeconds += delta;
      changed = true;
    }

    if (changed) {
      this.persist();
      this.broadcastState();
    }
  }

  private onTimerCompleted() {
    const elapsed = Math.floor(this.timer.targetSeconds);
    if (elapsed >= 30) {
      const slug = savedSlug();
      if (slug) {
        care.mutate(slug, (s) => care.recordFocus(s, elapsed));
        emit("care-updated", null).catch(() => {});
      }
      const now = new Date();
      worktracker.logSegment({
        source: "pomodoro",
        category: this.timer.activeSubject || "Focus Timer",
        startedAt: now.getTime() - elapsed * 1000,
        endedAt: now.getTime(),
        kind: "focus",
        note: `Completed ${Math.round(elapsed / 60)}m Countdown Timer`,
      });
    }
  }

  private broadcastState() {
    const fullState: FocusClockFullState = {
      timer: this.timer,
      stopwatch: this.stopwatch,
      activeMode: this.activeMode,
    };
    try {
      emit("ap-focusclock-state", fullState).catch(() => {});
    } catch {}
    this.notifyChange();
  }

  private notifyChange() {
    if (typeof window !== "undefined") {
      window.dispatchEvent(new CustomEvent("focusclock-changed", { detail: this.getState() }));
    }
  }

  getState(): FocusClockFullState {
    return {
      timer: { ...this.timer },
      stopwatch: { ...this.stopwatch },
      activeMode: this.activeMode,
    };
  }

  getTimerState(): CountdownTimerState {
    this.loadPersisted();
    return { ...this.timer };
  }

  getStopwatchState(): StopwatchState {
    this.loadPersisted();
    return { ...this.stopwatch };
  }

  getActiveMode(): FocusMode {
    this.loadPersisted();
    return this.activeMode;
  }

  setActiveMode(mode: FocusMode) {
    this.activeMode = mode;
    this.persist();
    if (!this.isHost) {
      emit("ap-focusclock-cmd", { action: "set-mode", mode }).catch(() => {});
    }
    this.broadcastState();
  }

  isTimerActive(): boolean {
    this.loadPersisted();
    return this.timer.state === "running" || this.timer.state === "paused";
  }

  isStopwatchActive(): boolean {
    this.loadPersisted();
    return this.stopwatch.state === "running" || this.stopwatch.state === "paused";
  }

  isAnyActive(): boolean {
    return this.isTimerActive() || this.isStopwatchActive();
  }

  // --- Timer Actions ---

  startTimer(minutes = 15, subject?: string) {
    this.startTimerInternal(minutes, subject);
    if (!this.isHost) {
      emit("ap-focusclock-cmd", { action: "start-timer", minutes, subject }).catch(() => {});
    }
  }

  private startTimerInternal(minutes = 15, subject?: string) {
    const primary = getPrimaryGoal();
    const resolvedSubject = subject || (primary ? primary.title : "Focus Timer");
    const duration = Math.max(1, minutes) * 60;
    this.timer = {
      state: "running",
      targetSeconds: duration,
      secondsRemaining: duration,
      activeSubject: resolvedSubject,
      lastTick: Date.now(),
    };
    this.activeMode = "timer";
    playClockSound("start");
    this.persist();
    this.broadcastState();
  }

  pauseTimer() {
    this.pauseTimerInternal();
    if (!this.isHost) {
      emit("ap-focusclock-cmd", { action: "pause-timer" }).catch(() => {});
    }
  }

  private pauseTimerInternal() {
    if (this.timer.state !== "running") return;
    this.timer.state = "paused";
    this.timer.lastTick = null;
    this.persist();
    this.broadcastState();
  }

  resumeTimer() {
    this.resumeTimerInternal();
    if (!this.isHost) {
      emit("ap-focusclock-cmd", { action: "resume-timer" }).catch(() => {});
    }
  }

  private resumeTimerInternal() {
    if (this.timer.state !== "paused") return;
    this.timer.state = "running";
    this.timer.lastTick = Date.now();
    this.persist();
    this.broadcastState();
  }

  addTimerMinutes(minutes = 5) {
    this.addTimerMinutesInternal(minutes);
    if (!this.isHost) {
      emit("ap-focusclock-cmd", { action: "add-timer-minutes", minutes }).catch(() => {});
    }
  }

  private addTimerMinutesInternal(minutes = 5) {
    const added = minutes * 60;
    this.timer.targetSeconds += added;
    this.timer.secondsRemaining += added;
    this.persist();
    this.broadcastState();
  }

  stopTimer() {
    this.stopTimerInternal();
    if (!this.isHost) {
      emit("ap-focusclock-cmd", { action: "stop-timer" }).catch(() => {});
    }
  }

  private stopTimerInternal() {
    const elapsed = Math.max(0, Math.floor(this.timer.targetSeconds - this.timer.secondsRemaining));
    if (elapsed >= 30) {
      const slug = savedSlug();
      if (slug) {
        care.mutate(slug, (s) => care.recordFocus(s, elapsed));
        emit("care-updated", null).catch(() => {});
      }
      const now = new Date();
      worktracker.logSegment({
        source: "pomodoro",
        category: this.timer.activeSubject || "Focus Timer",
        startedAt: now.getTime() - elapsed * 1000,
        endedAt: now.getTime(),
        kind: "focus",
        note: "Countdown Timer (Stopped)",
      });
    }
    this.resetTimerInternal();
  }

  resetTimer() {
    this.resetTimerInternal();
    if (!this.isHost) {
      emit("ap-focusclock-cmd", { action: "reset-timer" }).catch(() => {});
    }
  }

  private resetTimerInternal() {
    this.timer = {
      state: "idle",
      targetSeconds: this.timer.targetSeconds || 15 * 60,
      secondsRemaining: this.timer.targetSeconds || 15 * 60,
      activeSubject: this.timer.activeSubject || "Focus Session",
      lastTick: null,
    };
    this.persist();
    this.broadcastState();
  }

  // --- Stopwatch Actions ---

  startStopwatch(subject?: string) {
    this.startStopwatchInternal(subject);
    if (!this.isHost) {
      emit("ap-focusclock-cmd", { action: "start-stopwatch", subject }).catch(() => {});
    }
  }

  private startStopwatchInternal(subject?: string) {
    const primary = getPrimaryGoal();
    const resolvedSubject = subject || (primary ? primary.title : "Stopwatch Session");
    this.stopwatch = {
      state: "running",
      elapsedSeconds: 0,
      activeSubject: resolvedSubject,
      laps: [],
      lastTick: Date.now(),
    };
    this.activeMode = "stopwatch";
    playClockSound("start");
    this.persist();
    this.broadcastState();
  }

  pauseStopwatch() {
    this.pauseStopwatchInternal();
    if (!this.isHost) {
      emit("ap-focusclock-cmd", { action: "pause-stopwatch" }).catch(() => {});
    }
  }

  private pauseStopwatchInternal() {
    if (this.stopwatch.state !== "running") return;
    this.stopwatch.state = "paused";
    this.stopwatch.lastTick = null;
    this.persist();
    this.broadcastState();
  }

  resumeStopwatch() {
    this.resumeStopwatchInternal();
    if (!this.isHost) {
      emit("ap-focusclock-cmd", { action: "resume-stopwatch" }).catch(() => {});
    }
  }

  private resumeStopwatchInternal() {
    if (this.stopwatch.state !== "paused") return;
    this.stopwatch.state = "running";
    this.stopwatch.lastTick = Date.now();
    this.persist();
    this.broadcastState();
  }

  lapStopwatch() {
    this.lapStopwatchInternal();
    if (!this.isHost) {
      emit("ap-focusclock-cmd", { action: "lap-stopwatch" }).catch(() => {});
    }
  }

  private lapStopwatchInternal() {
    if (this.stopwatch.state !== "running") return;
    this.stopwatch.laps.unshift(this.stopwatch.elapsedSeconds);
    playClockSound("lap");
    this.persist();
    this.broadcastState();
  }

  stopStopwatch() {
    this.stopStopwatchInternal();
    if (!this.isHost) {
      emit("ap-focusclock-cmd", { action: "stop-stopwatch" }).catch(() => {});
    }
  }

  private stopStopwatchInternal() {
    const elapsed = Math.max(0, Math.floor(this.stopwatch.elapsedSeconds));
    if (elapsed >= 10) {
      const slug = savedSlug();
      if (slug) {
        care.mutate(slug, (s) => care.recordFocus(s, elapsed));
        emit("care-updated", null).catch(() => {});
      }
      const now = new Date();
      worktracker.logSegment({
        source: "manual",
        category: this.stopwatch.activeSubject || "Stopwatch Focus",
        startedAt: now.getTime() - elapsed * 1000,
        endedAt: now.getTime(),
        kind: "focus",
        note: "Stopwatch Focus Session",
      });
    }
    this.resetStopwatchInternal();
  }

  resetStopwatch() {
    this.resetStopwatchInternal();
    if (!this.isHost) {
      emit("ap-focusclock-cmd", { action: "reset-stopwatch" }).catch(() => {});
    }
  }

  private resetStopwatchInternal() {
    this.stopwatch = {
      state: "idle",
      elapsedSeconds: 0,
      activeSubject: this.stopwatch.activeSubject || "Study Session",
      laps: [],
      lastTick: null,
    };
    this.persist();
    this.broadcastState();
  }
}

export const focusClock = new FocusClockService();

// Configurable Pomodoro Timer for AgentPet
// Integrates with PetCare (awards XP/meals on focus finish) and WorkTracker.

import * as care from "./care";
import { savedSlug } from "./catalog";
import * as worktracker from "./worktracker";
import { getPrimaryGoal } from "./goals";

export type PomodoroPhase = "focus" | "shortBreak" | "longBreak" | "idle";

export interface PomodoroConfig {
  focusMinutes: number;
  shortBreakMinutes: number;
  longBreakMinutes: number;
  cyclesBeforeLongBreak: number;
  autoStartBreak: boolean;
  autoStartFocus: boolean;
  soundEnabled: boolean;
  defaultSubjectTag: string;
}

export interface PomodoroState {
  phase: PomodoroPhase;
  remainingSeconds: number;
  totalSeconds: number;
  isRunning: boolean;
  cycleCount: number;
  subjectTag: string;
  lastTickAt: number;
}

const STORAGE_CONFIG_KEY = "ap_pomodoro_v1_config";
const STORAGE_STATE_KEY = "ap_pomodoro_v1_state";

export function getDefaultConfig(): PomodoroConfig {
  return {
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    cyclesBeforeLongBreak: 4,
    autoStartBreak: false,
    autoStartFocus: false,
    soundEnabled: true,
    defaultSubjectTag: "Focus",
  };
}

export function getDefaultState(config = getDefaultConfig()): PomodoroState {
  const total = config.focusMinutes * 60;
  return {
    phase: "idle",
    remainingSeconds: total,
    totalSeconds: total,
    isRunning: false,
    cycleCount: 0,
    subjectTag: config.defaultSubjectTag,
    lastTickAt: Date.now(),
  };
}

export function loadConfig(): PomodoroConfig {
  try {
    const raw = localStorage.getItem(STORAGE_CONFIG_KEY);
    if (!raw) return getDefaultConfig();
    return { ...getDefaultConfig(), ...JSON.parse(raw) };
  } catch {
    return getDefaultConfig();
  }
}

export function saveConfig(config: PomodoroConfig) {
  localStorage.setItem(STORAGE_CONFIG_KEY, JSON.stringify(config));
  window.dispatchEvent(new CustomEvent("pomodoro-changed"));
}

export function loadState(): PomodoroState {
  try {
    const raw = localStorage.getItem(STORAGE_STATE_KEY);
    if (!raw) return getDefaultState(loadConfig());
    const parsed = JSON.parse(raw);
    return { ...getDefaultState(loadConfig()), ...parsed };
  } catch {
    return getDefaultState(loadConfig());
  }
}

export function saveState(state: PomodoroState) {
  localStorage.setItem(STORAGE_STATE_KEY, JSON.stringify(state));
  window.dispatchEvent(new CustomEvent("pomodoro-changed"));
}

/** Plays a gentle synth tone via Web Audio API without requiring local media assets */
export function playChime(type: "focus-done" | "break-done" | "tick") {
  try {
    const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    if (!AudioCtx) return;
    const ctx = new AudioCtx();

    if (type === "focus-done") {
      // Pleasant multi-chord arpeggio
      const notes = [523.25, 659.25, 783.99, 1046.5]; // C5, E5, G5, C6
      notes.forEach((freq, idx) => {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = "sine";
        osc.frequency.value = freq;
        const start = ctx.currentTime + idx * 0.12;
        gain.gain.setValueAtTime(0, start);
        gain.gain.linearRampToValueAtTime(0.2, start + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.001, start + 0.6);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(start);
        osc.stop(start + 0.6);
      });
    } else if (type === "break-done") {
      // Soft double chime
      [880, 1174.66].forEach((freq, idx) => {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = "sine";
        osc.frequency.value = freq;
        const start = ctx.currentTime + idx * 0.15;
        gain.gain.setValueAtTime(0, start);
        gain.gain.linearRampToValueAtTime(0.18, start + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.001, start + 0.4);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(start);
        osc.stop(start + 0.4);
      });
    }
  } catch {}
}

/** Resolves subject tag: user provided -> primary goal title -> config default */
export function resolveSubjectTag(providedSubject?: string): string {
  if (providedSubject && providedSubject.trim()) {
    return providedSubject.trim();
  }
  const primary = getPrimaryGoal();
  if (primary && primary.title) {
    return primary.title;
  }
  return loadConfig().defaultSubjectTag || "Focus";
}

/** Start a focus phase */
export function startFocus(subject?: string): PomodoroState {
  const config = loadConfig();
  const state = loadState();
  const subjectTag = resolveSubjectTag(subject || state.subjectTag);
  const total = Math.max(1, config.focusMinutes) * 60;

  state.phase = "focus";
  state.remainingSeconds = total;
  state.totalSeconds = total;
  state.isRunning = true;
  state.subjectTag = subjectTag;
  state.lastTickAt = Date.now();

  saveState(state);
  return state;
}

/** Directly start a break phase */
export function startBreak(isLong = false): PomodoroState {
  const config = loadConfig();
  const state = loadState();
  const breakMinutes = isLong ? config.longBreakMinutes : config.shortBreakMinutes;
  const total = Math.max(1, breakMinutes) * 60;

  state.phase = isLong ? "longBreak" : "shortBreak";
  state.remainingSeconds = total;
  state.totalSeconds = total;
  state.isRunning = true;
  state.lastTickAt = Date.now();

  saveState(state);
  return state;
}

/** Stop timer (alias to reset) */
export function stop(): PomodoroState {
  return reset();
}

/** Pause timer */
export function pause(): PomodoroState {
  const state = loadState();
  state.isRunning = false;
  state.lastTickAt = Date.now();
  saveState(state);
  return state;
}

/** Resume paused timer */
export function resume(): PomodoroState {
  const state = loadState();
  state.isRunning = true;
  state.lastTickAt = Date.now();
  saveState(state);
  return state;
}

/** Reset to idle */
export function reset(): PomodoroState {
  const config = loadConfig();
  const state = getDefaultState(config);
  state.subjectTag = resolveSubjectTag();
  saveState(state);
  return state;
}

/** Skip current phase immediately to the next */
export function skipPhase(): PomodoroState {
  const state = loadState();
  const config = loadConfig();

  if (state.phase === "focus") {
    // Complete focus early
    handleFocusCompleted(state, config, false);
  } else if (state.phase === "shortBreak" || state.phase === "longBreak") {
    // Complete break
    handleBreakCompleted(state, config, false);
  } else {
    // Idle -> start focus
    return startFocus();
  }

  saveState(state);
  return state;
}

function handleFocusCompleted(state: PomodoroState, config: PomodoroConfig, awardRewards = true) {
  const completedDurationSec = state.totalSeconds - Math.max(0, state.remainingSeconds);
  const now = Date.now();

  if (awardRewards && completedDurationSec >= 60) {
    // 1. Record work segment
    worktracker.logSegment({
      source: "pomodoro",
      category: state.subjectTag || "Focus",
      kind: "focus",
      startedAt: now - completedDurationSec * 1000,
      endedAt: now,
    });

    // 2. Award XP / meal credit to active pet
    const slug = savedSlug();
    if (slug) {
      care.mutate(slug, (s) => {
        care.recordMeal(s, new Date(now));
      });
    }

    // 3. Play chime
    if (config.soundEnabled) {
      playChime("focus-done");
    }
  }

  state.cycleCount += 1;
  const isLongBreak = state.cycleCount % config.cyclesBeforeLongBreak === 0;
  const breakMinutes = isLongBreak ? config.longBreakMinutes : config.shortBreakMinutes;
  const totalSec = Math.max(1, breakMinutes) * 60;

  state.phase = isLongBreak ? "longBreak" : "shortBreak";
  state.remainingSeconds = totalSec;
  state.totalSeconds = totalSec;
  state.isRunning = config.autoStartBreak;
  state.lastTickAt = now;
}

function handleBreakCompleted(state: PomodoroState, config: PomodoroConfig, awardRewards = true) {
  const completedDurationSec = state.totalSeconds - Math.max(0, state.remainingSeconds);
  const now = Date.now();

  if (awardRewards && completedDurationSec >= 30) {
    worktracker.logSegment({
      source: "pomodoro",
      category: "Break",
      kind: "break",
      startedAt: now - completedDurationSec * 1000,
      endedAt: now,
    });
    if (config.soundEnabled) {
      playChime("break-done");
    }
  }

  const focusSec = Math.max(1, config.focusMinutes) * 60;
  if (config.autoStartFocus) {
    state.phase = "focus";
    state.remainingSeconds = focusSec;
    state.totalSeconds = focusSec;
    state.isRunning = true;
    state.subjectTag = resolveSubjectTag(state.subjectTag);
    state.lastTickAt = now;
  } else {
    state.phase = "idle";
    state.remainingSeconds = focusSec;
    state.totalSeconds = focusSec;
    state.isRunning = false;
    state.lastTickAt = now;
  }
}

/** Ticks pomodoro timer deterministically based on elapsed time */
export function tickPomodoro(now = Date.now()): PomodoroState {
  const state = loadState();
  if (!state.isRunning || state.phase === "idle") {
    state.lastTickAt = now;
    return state;
  }

  const deltaSeconds = Math.max(0, Math.floor((now - state.lastTickAt) / 1000));
  if (deltaSeconds <= 0) return state;

  state.lastTickAt = now;
  state.remainingSeconds -= deltaSeconds;

  if (state.remainingSeconds <= 0) {
    const config = loadConfig();
    if (state.phase === "focus") {
      handleFocusCompleted(state, config, true);
    } else if (state.phase === "shortBreak" || state.phase === "longBreak") {
      handleBreakCompleted(state, config, true);
    }
  }

  saveState(state);
  return state;
}

/** Format MM:SS */
export function formatTime(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds));
  const m = Math.floor(s / 60);
  const rem = s % 60;
  return `${String(m).padStart(2, "0")}:${String(rem).padStart(2, "0")}`;
}

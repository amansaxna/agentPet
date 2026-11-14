// Unified Reminder Engine with Water, Take Time, Custom Reminders & Snooze for AgentPet.

export type ReminderKind = "water" | "takeTime" | "custom";
export type ReminderScheduleType = "interval" | "daily";

export interface ReminderRule {
  id: string;
  kind: ReminderKind;
  title: string;
  message: string;
  enabled: boolean;
  scheduleType: ReminderScheduleType;
  intervalMinutes: number; // For interval
  dailyTime?: string;      // "HH:mm" for daily
  activeOnly?: boolean;    // Only fire while user is working
  activeHoursStart?: string; // "08:00"
  activeHoursEnd?: string;   // "23:00"
  soundEnabled: boolean;
  defaultSnoozeMinutes: number; // 5, 10, 15, or 30
}

export interface ReminderRuntimeState {
  id: string;
  snoozedUntil: number | null; // ms epoch
  lastTriggeredAt: number | null;
  lastCompletedAt: number | null;
  completedCountToday: number;
  lastCountDayKey: string;
}

export interface DueReminder {
  rule: ReminderRule;
  dueAt: number;
  kind: ReminderKind;
}

export interface RemindersStore {
  rules: ReminderRule[];
  states: Record<string, ReminderRuntimeState>;
  waterCupsToday: number;
  waterCupsDayKey: string;
}

const STORAGE_KEY = "ap_reminders_v1";

function todayKey(now = new Date()): string {
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, "0");
  const d = String(now.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export const DEFAULT_RULES: ReminderRule[] = [
  {
    id: "water_default",
    kind: "water",
    title: "Drink Water",
    message: "Hydrate! Take a sip of water to stay fresh and focused.",
    enabled: true,
    scheduleType: "interval",
    intervalMinutes: 45,
    activeHoursStart: "08:00",
    activeHoursEnd: "23:00",
    soundEnabled: true,
    defaultSnoozeMinutes: 5,
  },
  {
    id: "taketime_default",
    kind: "takeTime",
    title: "Take Time & Breathe",
    message: "Step back for 60 seconds, stretch your neck, and rest your eyes.",
    enabled: true,
    scheduleType: "interval",
    intervalMinutes: 60,
    soundEnabled: true,
    defaultSnoozeMinutes: 10,
  },
];

export function loadStore(): RemindersStore {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return {
        rules: [...DEFAULT_RULES],
        states: {},
        waterCupsToday: 0,
        waterCupsDayKey: todayKey(),
      };
    }
    const parsed = JSON.parse(raw);
    const today = todayKey();
    const waterCupsToday = parsed.waterCupsDayKey === today ? (parsed.waterCupsToday || 0) : 0;

    return {
      rules: Array.isArray(parsed.rules) && parsed.rules.length ? parsed.rules : [...DEFAULT_RULES],
      states: parsed.states || {},
      waterCupsToday,
      waterCupsDayKey: today,
    };
  } catch {
    return {
      rules: [...DEFAULT_RULES],
      states: {},
      waterCupsToday: 0,
      waterCupsDayKey: todayKey(),
    };
  }
}

export function saveStore(store: RemindersStore, emitEvent = true) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(store));
  if (emitEvent) {
    window.dispatchEvent(new CustomEvent("reminders-changed"));
  }
}

export function getRules(): ReminderRule[] {
  return loadStore().rules;
}

export function saveRules(rules: ReminderRule[]) {
  const store = loadStore();
  store.rules = rules;
  saveStore(store);
}

export function updateRule(id: string, patch: Partial<ReminderRule>): ReminderRule | null {
  const store = loadStore();
  const idx = store.rules.findIndex((r) => r.id === id);
  if (idx < 0) return null;

  store.rules[idx] = { ...store.rules[idx], ...patch, id };
  saveStore(store);
  return store.rules[idx];
}

export function addCustomReminder(params: {
  title: string;
  message: string;
  scheduleType: ReminderScheduleType;
  intervalMinutes?: number;
  dailyTime?: string;
  soundEnabled?: boolean;
  defaultSnoozeMinutes?: number;
}): ReminderRule {
  const store = loadStore();
  const id = `custom_rem_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
  const rule: ReminderRule = {
    id,
    kind: "custom",
    title: params.title.trim() || "Reminder",
    message: params.message.trim() || "Time for your reminder!",
    enabled: true,
    scheduleType: params.scheduleType,
    intervalMinutes: Math.max(1, params.intervalMinutes || 30),
    dailyTime: params.dailyTime || "12:00",
    soundEnabled: params.soundEnabled !== false,
    defaultSnoozeMinutes: params.defaultSnoozeMinutes || 10,
  };

  store.rules.push(rule);
  saveStore(store);
  return rule;
}

export function deleteReminder(id: string): boolean {
  const store = loadStore();
  const len = store.rules.length;
  store.rules = store.rules.filter((r) => r.id !== id);
  delete store.states[id];
  if (store.rules.length !== len) {
    saveStore(store);
    return true;
  }
  return false;
}

// ---------------- Water Counter ----------------

export function getWaterCupsToday(): number {
  return loadStore().waterCupsToday;
}

export function incrementWaterCup(): number {
  const store = loadStore();
  const today = todayKey();
  if (store.waterCupsDayKey !== today) {
    store.waterCupsToday = 1;
    store.waterCupsDayKey = today;
  } else {
    store.waterCupsToday += 1;
  }
  saveStore(store);
  return store.waterCupsToday;
}

export function resetWaterCups(): number {
  const store = loadStore();
  store.waterCupsToday = 0;
  store.waterCupsDayKey = todayKey();
  saveStore(store);
  return 0;
}

// ---------------- Evaluation & Snooze Logic ----------------

function isInActiveHours(rule: ReminderRule, now: Date): boolean {
  if (!rule.activeHoursStart || !rule.activeHoursEnd) return true;
  const currentHM = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
  return currentHM >= rule.activeHoursStart && currentHM <= rule.activeHoursEnd;
}

/** Check which reminders are currently due */
export function checkDueReminders(nowMs = Date.now()): DueReminder[] {
  const store = loadStore();
  const now = new Date(nowMs);
  const today = todayKey(now);
  const due: DueReminder[] = [];

  let changed = false;

  for (const rule of store.rules) {
    if (!rule.enabled) continue;
    if (!isInActiveHours(rule, now)) continue;

    let state = store.states[rule.id];
    if (!state) {
      state = {
        id: rule.id,
        snoozedUntil: null,
        lastTriggeredAt: null,
        lastCompletedAt: null,
        completedCountToday: 0,
        lastCountDayKey: today,
      };
      store.states[rule.id] = state;
      changed = true;
    }

    // Reset daily count if day changed
    if (state.lastCountDayKey !== today) {
      state.completedCountToday = 0;
      state.lastCountDayKey = today;
      changed = true;
    }

    // If snoozed and snooze has not expired yet, skip
    if (state.snoozedUntil && nowMs < state.snoozedUntil) {
      continue;
    }

    if (rule.scheduleType === "interval") {
      const intervalMs = Math.max(1, rule.intervalMinutes) * 60_000;
      const baseline = Math.max(
        state.lastCompletedAt || 0,
        state.lastTriggeredAt || 0
      );

      // If never triggered or interval has passed
      if (baseline === 0) {
        // Initialize baseline to now to not trigger immediately on first boot, or trigger after interval
        state.lastTriggeredAt = nowMs;
        changed = true;
      } else if (nowMs - baseline >= intervalMs) {
        due.push({ rule, dueAt: nowMs, kind: rule.kind });
      }
    } else if (rule.scheduleType === "daily" && rule.dailyTime) {
      // Check if current time matches dailyTime and hasn't been triggered today
      const currentHM = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
      if (currentHM === rule.dailyTime) {
        const lastTrigDate = state.lastTriggeredAt ? todayKey(new Date(state.lastTriggeredAt)) : "";
        if (lastTrigDate !== today) {
          due.push({ rule, dueAt: nowMs, kind: rule.kind });
        }
      }
    }
  }

  if (changed) {
    saveStore(store, false);
  }
  return due;
}

/** Snooze a reminder for N minutes */
export function snoozeReminder(id: string, minutes: number, nowMs = Date.now()) {
  const store = loadStore();
  const state = store.states[id] || {
    id,
    snoozedUntil: null,
    lastTriggeredAt: nowMs,
    lastCompletedAt: null,
    completedCountToday: 0,
    lastCountDayKey: todayKey(new Date(nowMs)),
  };

  state.snoozedUntil = nowMs + Math.max(1, minutes) * 60_000;
  state.lastTriggeredAt = nowMs;
  store.states[id] = state;
  saveStore(store);
}

/** Mark reminder completed (e.g. drank water, stretched) */
export function completeReminder(id: string, nowMs = Date.now()) {
  const store = loadStore();
  const rule = store.rules.find((r) => r.id === id);
  const today = todayKey(new Date(nowMs));

  const state = store.states[id] || {
    id,
    snoozedUntil: null,
    lastTriggeredAt: nowMs,
    lastCompletedAt: null,
    completedCountToday: 0,
    lastCountDayKey: today,
  };

  state.snoozedUntil = null;
  state.lastCompletedAt = nowMs;
  state.lastTriggeredAt = nowMs;
  state.completedCountToday += 1;
  state.lastCountDayKey = today;
  store.states[id] = state;

  if (rule?.kind === "water") {
    if (store.waterCupsDayKey !== today) {
      store.waterCupsToday = 1;
      store.waterCupsDayKey = today;
    } else {
      store.waterCupsToday += 1;
    }
  }

  saveStore(store);
}

/** Dismiss reminder without marking done (schedules next normal cycle) */
export function dismissReminder(id: string, nowMs = Date.now()) {
  const store = loadStore();
  const state = store.states[id] || {
    id,
    snoozedUntil: null,
    lastTriggeredAt: nowMs,
    lastCompletedAt: null,
    completedCountToday: 0,
    lastCountDayKey: todayKey(new Date(nowMs)),
  };

  state.snoozedUntil = null;
  state.lastTriggeredAt = nowMs;
  store.states[id] = state;
  saveStore(store);
}

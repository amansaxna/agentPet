// Work Time Tracker & Analytics Engine for AgentPet
// Implements manual clock-in/out, pomodoro logging, agent session sync,
// overlap-safe interval merging, and productivity analytics.

import * as history from "./history";

export type WorkSource = "pomodoro" | "manual" | "agent" | "presence";
export type WorkSegmentKind = "focus" | "break";

export interface WorkSegment {
  id: string;
  source: WorkSource;
  category: string; // e.g. "GATE Exam", "Coding", or primary goal title
  kind: WorkSegmentKind;
  startedAt: number; // ms timestamp
  endedAt: number;   // ms timestamp
  note?: string;
}

export interface ActiveManualSession {
  startedAt: number;
  category: string;
  note?: string;
}

export interface CategoryBreakdown {
  category: string;
  seconds: number;
  percentage: number;
}

export interface SourceBreakdown {
  source: WorkSource;
  seconds: number;
  percentage: number;
}

export interface DailyTrendPoint {
  dateStr: string; // "YYYY-MM-DD"
  dayLabel: string; // "Mon", "14", etc.
  workMinutes: number;
  breakMinutes: number;
  targetMinutes: number;
}

export interface HourlyDistributionPoint {
  hour: number; // 0..23
  workMinutes: number;
  label: string; // "00", "01", ..., "23"
}

export interface WorkAnalyticsReport {
  period: "today" | "7d" | "30d";
  totalWorkSeconds: number;
  totalBreakSeconds: number;
  focusRatio: number; // 0..1
  activeStreakDays: number;
  dailyTargetMinutes: number;
  targetAttainment: number; // 0..1+
  categoryBreakdown: CategoryBreakdown[];
  sourceBreakdown: SourceBreakdown[];
  dailyTrend: DailyTrendPoint[];
  hourlyDistribution: HourlyDistributionPoint[];
  peakHour: number; // 0..23
}

const STORAGE_SEGMENTS_KEY = "ap_work_segments_v1";
const STORAGE_MANUAL_KEY = "ap_work_active_manual_v1";

export interface Interval {
  start: number;
  end: number;
}

/** Merges overlapping or adjacent time intervals to prevent double-counting */
export function mergeIntervals(intervals: Interval[]): Interval[] {
  if (intervals.length <= 1) return [...intervals];

  const sorted = [...intervals].sort((a, b) => a.start - b.start);
  const merged: Interval[] = [sorted[0]];

  for (let i = 1; i < sorted.length; i++) {
    const cur = sorted[i];
    const prev = merged[merged.length - 1];

    if (cur.start <= prev.end) {
      prev.end = Math.max(prev.end, cur.end);
    } else {
      merged.push({ start: cur.start, end: cur.end });
    }
  }

  return merged;
}

/** Sums total duration in seconds from an array of intervals */
export function sumIntervalSeconds(intervals: Interval[]): number {
  const merged = mergeIntervals(intervals);
  let totalMs = 0;
  for (const iv of merged) {
    if (iv.end > iv.start) {
      totalMs += (iv.end - iv.start);
    }
  }
  return Math.round(totalMs / 1000);
}

/** Load all work segments */
export function getSegments(): WorkSegment[] {
  try {
    const raw = localStorage.getItem(STORAGE_SEGMENTS_KEY);
    if (!raw) return [];
    const list: WorkSegment[] = JSON.parse(raw);
    return Array.isArray(list) ? list : [];
  } catch {
    return [];
  }
}

/** Save work segments */
export function saveSegments(segments: WorkSegment[]) {
  // Keep last 90 days to avoid unbounded storage
  const cutoff = Date.now() - 90 * 86_400_000;
  const filtered = segments.filter((s) => s.endedAt >= cutoff);
  filtered.sort((a, b) => b.endedAt - a.endedAt);
  localStorage.setItem(STORAGE_SEGMENTS_KEY, JSON.stringify(filtered));
  window.dispatchEvent(new CustomEvent("worktracker-changed"));
}

/** Log a new completed work segment */
export function logSegment(seg: Omit<WorkSegment, "id"> & { id?: string }): WorkSegment {
  const segments = getSegments();
  const id = seg.id || `ws_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
  const item: WorkSegment = { ...seg, id };
  segments.unshift(item);
  saveSegments(segments);
  return item;
}

// ---------------- Manual Work Clock-In / Clock-Out ----------------

/** Check if currently manually working */
export function getActiveManualSession(): ActiveManualSession | null {
  try {
    const raw = localStorage.getItem(STORAGE_MANUAL_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

/** Start manual clock-in */
export function startManualWork(category = "Deep Work", note?: string): ActiveManualSession {
  const session: ActiveManualSession = {
    startedAt: Date.now(),
    category: category.trim() || "Deep Work",
    note,
  };
  localStorage.setItem(STORAGE_MANUAL_KEY, JSON.stringify(session));
  window.dispatchEvent(new CustomEvent("worktracker-manual-changed"));
  return session;
}

/** Stop manual clock-in and record segment */
export function stopManualWork(): WorkSegment | null {
  const active = getActiveManualSession();
  if (!active) return null;

  const now = Date.now();
  localStorage.removeItem(STORAGE_MANUAL_KEY);
  window.dispatchEvent(new CustomEvent("worktracker-manual-changed"));

  const durationMs = now - active.startedAt;
  // Ignore accidental clicks under 10 seconds
  if (durationMs < 10_000) return null;

  return logSegment({
    source: "manual",
    category: active.category,
    kind: "focus",
    startedAt: active.startedAt,
    endedAt: now,
    note: active.note,
  });
}

/** Sync sessions from agent history (history.ts) */
export function syncFromAgentHistory() {
  const entries = history.list();
  if (!entries.length) return;

  const segments = getSegments();
  const existingAgentIds = new Set(
    segments.filter((s) => s.source === "agent").map((s) => s.id)
  );

  let added = false;
  for (const e of entries) {
    const segId = `agent_${e.id}_${e.startedAt}`;
    if (!existingAgentIds.has(segId) && e.endedAt > e.startedAt) {
      segments.push({
        id: segId,
        source: "agent",
        category: e.project || e.agent || "Coding",
        kind: "focus",
        startedAt: e.startedAt,
        endedAt: e.endedAt,
        note: e.title || e.agent,
      });
      existingAgentIds.add(segId);
      added = true;
    }
  }

  if (added) {
    saveSegments(segments);
  }
}

// ---------------- Analytics Engine ----------------

function formatDayKey(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

/** Computes comprehensive work time analytics for Today, 7D, or 30D */
export function computeWorkAnalysis(
  period: "today" | "7d" | "30d",
  options?: { dailyTargetMinutes?: number; now?: Date }
): WorkAnalyticsReport {
  const now = options?.now || new Date();
  const dailyTargetMinutes = options?.dailyTargetMinutes || 240; // 4h default

  const todayMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  let startTimestamp = todayMidnight;

  if (period === "7d") {
    startTimestamp = todayMidnight - 6 * 86_400_000;
  } else if (period === "30d") {
    startTimestamp = todayMidnight - 29 * 86_400_000;
  }
  const endTimestamp = now.getTime();

  const allSegments = getSegments();
  // Filter segments that overlap with the period
  const periodSegments = allSegments.filter(
    (s) => s.endedAt >= startTimestamp && s.startedAt <= endTimestamp
  );

  // Group intervals for overlap-safe merging
  const focusIntervals: Interval[] = [];
  const breakIntervals: Interval[] = [];

  // Breakdown collectors
  const categoryTotals: Record<string, number> = {};
  const sourceTotals: Record<WorkSource, number> = {
    pomodoro: 0,
    manual: 0,
    agent: 0,
    presence: 0,
  };

  // 24-Hour distribution buckets (0..23)
  const hourlyMinutes: number[] = new Array(24).fill(0);

  for (const seg of periodSegments) {
    // Clip interval to period boundary
    const clippedStart = Math.max(seg.startedAt, startTimestamp);
    const clippedEnd = Math.min(seg.endedAt, endTimestamp);
    if (clippedEnd <= clippedStart) continue;

    const durationSec = Math.round((clippedEnd - clippedStart) / 1000);

    if (seg.kind === "focus") {
      focusIntervals.push({ start: clippedStart, end: clippedEnd });

      // Category breakdown
      const cat = seg.category || "General";
      categoryTotals[cat] = (categoryTotals[cat] || 0) + durationSec;

      // Source breakdown
      sourceTotals[seg.source] = (sourceTotals[seg.source] || 0) + durationSec;

      // Hourly distribution
      // Distribute duration into hourly buckets
      let cur = clippedStart;
      while (cur < clippedEnd) {
        const d = new Date(cur);
        const hour = d.getHours();
        const nextHour = new Date(d.getFullYear(), d.getMonth(), d.getDate(), hour + 1).getTime();
        const sliceEnd = Math.min(clippedEnd, nextHour);
        const mins = (sliceEnd - cur) / 60_000;
        hourlyMinutes[hour] += mins;
        cur = sliceEnd;
      }
    } else {
      breakIntervals.push({ start: clippedStart, end: clippedEnd });
    }
  }

  // Also include active manual session if applicable
  const activeManual = getActiveManualSession();
  if (activeManual) {
    const curStart = Math.max(activeManual.startedAt, startTimestamp);
    const curEnd = Math.min(now.getTime(), endTimestamp);
    if (curEnd > curStart) {
      focusIntervals.push({ start: curStart, end: curEnd });
      const sec = Math.round((curEnd - curStart) / 1000);
      categoryTotals[activeManual.category] = (categoryTotals[activeManual.category] || 0) + sec;
      sourceTotals.manual += sec;
    }
  }

  const totalWorkSeconds = sumIntervalSeconds(focusIntervals);
  const totalBreakSeconds = sumIntervalSeconds(breakIntervals);
  const totalCombined = totalWorkSeconds + totalBreakSeconds;
  const focusRatio = totalCombined > 0 ? totalWorkSeconds / totalCombined : 1;

  // Category breakdown array
  const rawCatSum = Object.values(categoryTotals).reduce((a, b) => a + b, 0);
  const categoryBreakdown: CategoryBreakdown[] = Object.entries(categoryTotals)
    .map(([category, seconds]) => ({
      category,
      seconds,
      percentage: rawCatSum > 0 ? (seconds / rawCatSum) * 100 : 0,
    }))
    .sort((a, b) => b.seconds - a.seconds);

  // Source breakdown array
  const rawSrcSum = Object.values(sourceTotals).reduce((a, b) => a + b, 0);
  const sourceBreakdown: SourceBreakdown[] = (Object.keys(sourceTotals) as WorkSource[])
    .map((source) => ({
      source,
      seconds: sourceTotals[source],
      percentage: rawSrcSum > 0 ? (sourceTotals[source] / rawSrcSum) * 100 : 0,
    }))
    .filter((s) => s.seconds > 0)
    .sort((a, b) => b.seconds - a.seconds);

  // 14-Day Daily Trend
  const dailyTrend: DailyTrendPoint[] = [];
  const trendDaysCount = 14;
  for (let i = trendDaysCount - 1; i >= 0; i--) {
    const dayDate = new Date(todayMidnight - i * 86_400_000);
    const dayStart = dayDate.getTime();
    const dayEnd = dayStart + 86_400_000 - 1;
    const dateStr = formatDayKey(dayDate);
    const dayName = dayDate.toLocaleDateString([], { weekday: "short" });

    // Focus intervals for that day
    const dayFocus = allSegments
      .filter((s) => s.kind === "focus" && s.endedAt >= dayStart && s.startedAt <= dayEnd)
      .map((s) => ({
        start: Math.max(s.startedAt, dayStart),
        end: Math.min(s.endedAt, dayEnd),
      }));

    const dayBreaks = allSegments
      .filter((s) => s.kind === "break" && s.endedAt >= dayStart && s.startedAt <= dayEnd)
      .map((s) => ({
        start: Math.max(s.startedAt, dayStart),
        end: Math.min(s.endedAt, dayEnd),
      }));

    const workSec = sumIntervalSeconds(dayFocus);
    const breakSec = sumIntervalSeconds(dayBreaks);

    dailyTrend.push({
      dateStr,
      dayLabel: i === 0 ? "Today" : dayName,
      workMinutes: Math.round(workSec / 60),
      breakMinutes: Math.round(breakSec / 60),
      targetMinutes: dailyTargetMinutes,
    });
  }

  // Hourly distribution array & peak hour
  let peakHour = 0;
  let maxHourlyMins = -1;
  const hourlyDistribution: HourlyDistributionPoint[] = hourlyMinutes.map((mins, h) => {
    const roundedMins = Math.round(mins);
    if (roundedMins > maxHourlyMins) {
      maxHourlyMins = roundedMins;
      peakHour = h;
    }
    return {
      hour: h,
      workMinutes: roundedMins,
      label: String(h).padStart(2, "0"),
    };
  });

  // Active streak calculation (consecutive days with at least 15 min focus)
  let activeStreakDays = 0;
  let checkOffset = 0;
  while (checkOffset < 90) {
    const d = new Date(todayMidnight - checkOffset * 86_400_000);
    const dStart = d.getTime();
    const dEnd = dStart + 86_400_000 - 1;
    const dayFocus = allSegments
      .filter((s) => s.kind === "focus" && s.endedAt >= dStart && s.startedAt <= dEnd)
      .map((s) => ({
        start: Math.max(s.startedAt, dStart),
        end: Math.min(s.endedAt, dEnd),
      }));
    const daySec = sumIntervalSeconds(dayFocus);
    if (daySec >= 15 * 60 || (checkOffset === 0 && daySec > 0)) {
      activeStreakDays++;
      checkOffset++;
    } else {
      break;
    }
  }

  // Today target attainment
  const todayTrend = dailyTrend[dailyTrend.length - 1];
  const targetAttainment = dailyTargetMinutes > 0
    ? (todayTrend?.workMinutes || 0) / dailyTargetMinutes
    : 0;

  return {
    period,
    totalWorkSeconds,
    totalBreakSeconds,
    focusRatio,
    activeStreakDays,
    dailyTargetMinutes,
    targetAttainment,
    categoryBreakdown,
    sourceBreakdown,
    dailyTrend,
    hourlyDistribution,
    peakHour,
  };
}

/** Formats seconds into human readable e.g. "2h 45m" or "45m" or "25s" */
export function formatDuration(seconds: number): string {
  if (seconds <= 0) return "0m";
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;

  if (h > 0) {
    return m > 0 ? `${h}h ${m}m` : `${h}h`;
  }
  if (m > 0) {
    return `${m}m`;
  }
  return `${s}s`;
}

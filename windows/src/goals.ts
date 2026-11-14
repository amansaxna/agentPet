// Target & Primary Goal System for AgentPet
// Computes exact calendar days passed from start date and days left until target date.

export type GoalCategory = "GATE Exam" | "Learning" | "Career" | "Project" | "Health" | "Personal";

export interface GoalMilestone {
  id: string;
  title: string;
  completed: boolean;
}

export interface TargetGoal {
  id: string;
  title: string;
  category: GoalCategory;
  isPrimary: boolean;
  startDate: string; // "YYYY-MM-DD"
  targetDate: string; // "YYYY-MM-DD"
  dailyTargetMinutes: number; // e.g. 240 (4 hours)
  milestones: GoalMilestone[];
  notes: string;
  archived?: boolean;
}

export interface GoalMetrics {
  daysPassed: number;
  daysLeft: number;
  totalSpanDays: number;
  timelineProgress: number; // 0..1
  milestoneProgress: number; // 0..1
  milestoneCount: { completed: number; total: number };
  statusLabel: string;
  passedLabel: string;
  isPastTarget: boolean;
  isTargetDay: boolean;
}

const STORAGE_KEY = "ap_goals_v1";

/** Parse "YYYY-MM-DD" into a local midnight Date */
export function parseLocalDate(dStr: string): Date {
  const parts = dStr.split("-").map(Number);
  if (parts.length < 3 || isNaN(parts[0]) || isNaN(parts[1]) || isNaN(parts[2])) {
    return new Date();
  }
  return new Date(parts[0], parts[1] - 1, parts[2]);
}

/** Format Date to "YYYY-MM-DD" */
export function formatLocalDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

/** Midnight-normalized calendar day difference (d2 - d1) */
export function calendarDaysBetween(d1: Date, d2: Date): number {
  const utc1 = Date.UTC(d1.getFullYear(), d1.getMonth(), d1.getDate());
  const utc2 = Date.UTC(d2.getFullYear(), d2.getMonth(), d2.getDate());
  return Math.round((utc2 - utc1) / 86_400_000);
}

/** Computes metrics for a goal against a reference date */
export function computeGoalMetrics(goal: TargetGoal, now = new Date()): GoalMetrics {
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const start = parseLocalDate(goal.startDate);
  const target = parseLocalDate(goal.targetDate);

  const daysPassed = Math.max(0, calendarDaysBetween(start, today));
  const daysLeft = calendarDaysBetween(today, target);
  const totalSpanDays = Math.max(1, calendarDaysBetween(start, target));
  const timelineProgress = Math.min(1, Math.max(0, daysPassed / totalSpanDays));

  const totalMs = goal.milestones.length;
  const completedMs = goal.milestones.filter((m) => m.completed).length;
  const milestoneProgress = totalMs > 0 ? completedMs / totalMs : 0;

  const isTargetDay = daysLeft === 0;
  const isPastTarget = daysLeft < 0;

  let statusLabel = "";
  if (isTargetDay) {
    statusLabel = "Target Day!";
  } else if (daysLeft === 1) {
    statusLabel = "1 day left";
  } else if (daysLeft > 1) {
    statusLabel = `${daysLeft} days left`;
  } else {
    statusLabel = `${Math.abs(daysLeft)} days past`;
  }

  const passedLabel = `${daysPassed}d passed from ${goal.startDate}`;

  return {
    daysPassed,
    daysLeft,
    totalSpanDays,
    timelineProgress,
    milestoneProgress,
    milestoneCount: { completed: completedMs, total: totalMs },
    statusLabel,
    passedLabel,
    isPastTarget,
    isTargetDay,
  };
}

/** Load goals from localStorage */
export function getGoals(): TargetGoal[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const list: TargetGoal[] = JSON.parse(raw);
    return Array.isArray(list) ? list : [];
  } catch {
    return [];
  }
}

/** Save goals to localStorage */
export function saveGoals(goals: TargetGoal[]) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(goals));
  window.dispatchEvent(new CustomEvent("goals-changed"));
}

/** Get the single active primary goal */
export function getPrimaryGoal(): TargetGoal | null {
  const goals = getGoals();
  return goals.find((g) => g.isPrimary && !g.archived) || goals[0] || null;
}

/** Set a specific goal as Primary and unset others */
export function setPrimaryGoal(id: string): TargetGoal | null {
  const goals = getGoals();
  let selected: TargetGoal | null = null;
  for (const g of goals) {
    if (g.id === id) {
      g.isPrimary = true;
      selected = g;
    } else {
      g.isPrimary = false;
    }
  }
  saveGoals(goals);
  return selected;
}

/** Add a new target goal */
export function addGoal(goal: Omit<TargetGoal, "id"> & { id?: string }): TargetGoal {
  const goals = getGoals();
  const id = goal.id || `goal_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
  // If this is the first goal or marked primary, adjust others
  const isPrimary = goal.isPrimary || goals.length === 0;
  if (isPrimary) {
    goals.forEach((g) => { g.isPrimary = false; });
  }

  const newGoal: TargetGoal = {
    ...goal,
    id,
    isPrimary,
    milestones: goal.milestones || [],
    notes: goal.notes || "",
  };

  goals.unshift(newGoal);
  saveGoals(goals);
  return newGoal;
}

/** Update an existing goal */
export function updateGoal(id: string, patch: Partial<TargetGoal>): TargetGoal | null {
  const goals = getGoals();
  const idx = goals.findIndex((g) => g.id === id);
  if (idx < 0) return null;

  if (patch.isPrimary) {
    goals.forEach((g) => { g.isPrimary = false; });
  }

  goals[idx] = { ...goals[idx], ...patch, id };
  saveGoals(goals);
  return goals[idx];
}

/** Delete a goal */
export function deleteGoal(id: string): boolean {
  const goals = getGoals();
  const filtered = goals.filter((g) => g.id !== id);
  if (filtered.length === goals.length) return false;

  // If deleted was primary, promote the first remaining
  if (filtered.length > 0 && !filtered.some((g) => g.isPrimary)) {
    filtered[0].isPrimary = true;
  }
  saveGoals(filtered);
  return true;
}

/** Toggle a milestone completed state */
export function toggleMilestone(goalId: string, milestoneId: string): boolean {
  const goals = getGoals();
  const goal = goals.find((g) => g.id === goalId);
  if (!goal) return false;

  const ms = goal.milestones.find((m) => m.id === milestoneId);
  if (!ms) return false;

  ms.completed = !ms.completed;
  saveGoals(goals);
  return true;
}

/** Starter template for GATE Exam */
export function createGateStarterTemplate(): TargetGoal {
  const now = new Date();
  const startDate = formatLocalDate(new Date(now.getTime() - 14 * 86_400_000)); // 14 days ago
  const targetYear = now.getMonth() >= 2 ? now.getFullYear() + 1 : now.getFullYear();
  const targetDate = `${targetYear}-02-14`; // February GATE exam date

  return {
    id: `gate_${Date.now()}`,
    title: `GATE CS ${targetYear} — Top Rank Mastery`,
    category: "GATE Exam",
    isPrimary: true,
    startDate,
    targetDate,
    dailyTargetMinutes: 240, // 4 hours
    milestones: [
      { id: "m1", title: "Complete Engineering Mathematics & Aptitude PYQs", completed: true },
      { id: "m2", title: "Data Structures & Algorithms core revision", completed: false },
      { id: "m3", title: "Computer Networks & OS mock problem sets", completed: false },
      { id: "m4", title: "Database Systems & Theory of Computation", completed: false },
      { id: "m5", title: "Take 10 Full-Length Mock Exams with analysis", completed: false },
    ],
    notes: "Daily goal: 4 hours of deep focus. Prioritize PYQs and high-frequency topics.",
  };
}

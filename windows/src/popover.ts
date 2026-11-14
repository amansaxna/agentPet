// The tray/right-click popover , a port of the macOS MenuContentView: live
// agent list with dismiss + Clear all, Show pet toggle, pet-size slider, and
// a Settings / Updates / Quit footer, plus 5 personal productivity modules:
// Primary Goal, Due Reminders, Pomodoro & Work Tracker, and Tailored Quotes.

import { invoke } from "@tauri-apps/api/core";
import { emit, listen } from "@tauri-apps/api/event";
import { getCurrentWindow, LogicalSize } from "@tauri-apps/api/window";
import { check } from "@tauri-apps/plugin-updater";
import { relaunch, exit } from "@tauri-apps/plugin-process";
import { SessionStore, type AgentEventPayload, type Session } from "./state";
import { agentIconUrl } from "./icons";
import { projectLabel } from "./projectnames";
import { elapsedString } from "./bubble";
import { t } from "./i18n";
import * as limits from "./limits";
import * as goals from "./goals";
import * as pomodoro from "./pomodoro";
import * as reminders from "./reminders";
import * as worktracker from "./worktracker";
import * as quotes from "./quotes";

const store = new SessionStore();
const list = document.getElementById("pop-list")!;
const empty = document.getElementById("pop-empty")!;
const sub = document.getElementById("pop-sub")!;
const clearBtn = document.getElementById("pop-clear") as HTMLButtonElement;

function esc(s: string): string {
  return String(s ?? "").replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c] || c));
}

function applyStatic() {
  const set = (id: string, key: string) => { const el = document.getElementById(id); if (el) el.textContent = t(key); };
  set("t-pop-agents", "AGENTS");
  set("t-pop-limits", "LIMITS");
  set("pop-clear", "Clear all");
  set("pop-empty", "Nothing running right now.");
  set("t-pop-showpet", "Show pet");
  set("t-pop-size", "Pet size");
  set("t-pop-settings", "Settings");
  set("t-pop-updates", "Updates");
  set("t-pop-quit", "Quit");
}

/// Like the macOS popover: working/waiting/done sessions, idle + registered hidden.
function visible(): Session[] {
  return store.active().filter((s) => s.state !== "idle" && s.state !== "registered");
}

function paintPrimaryGoal() {
  const host = document.getElementById("pop-primary-goal");
  if (!host) return;
  const primary = goals.getPrimaryGoal();
  if (!primary) {
    host.style.display = "none";
    return;
  }
  host.style.display = "block";
  const m = goals.computeGoalMetrics(primary);
  const analysis = worktracker.computeWorkAnalysis("today");
  const workedStr = worktracker.formatDuration(analysis.totalWorkSeconds);
  const targetStr = `${(primary.dailyTargetMinutes / 60).toFixed(0)}h`;
  const pct = Math.round(m.timelineProgress * 100);

  host.innerHTML = `
    <div class="pop-goal-card">
      <div class="pop-goal-header">
        <span class="pop-goal-tag">${esc(primary.category.toUpperCase())}</span>
        <span class="pop-goal-status">${esc(m.statusLabel)}</span>
      </div>
      <div class="pop-goal-title">${esc(primary.title)}</div>
      <div class="pop-goal-sub">${esc(m.passedLabel)}</div>
      <div class="pop-goal-bar-wrap">
        <div class="pop-goal-bar" style="width: ${pct}%"></div>
      </div>
      <div class="pop-goal-footer">
        <span class="pop-goal-time">Today: <b>${workedStr}</b> / ${targetStr}</span>
        <button class="pop-goal-focus-btn" id="pop-focus-goal">▶ Focus</button>
      </div>
    </div>
  `;

  const btn = document.getElementById("pop-focus-goal");
  if (btn) {
    btn.onclick = () => {
      pomodoro.startFocus(primary.title);
      paintAndFit();
    };
  }
}

function paintReminderBanner() {
  const host = document.getElementById("pop-reminder-banner");
  if (!host) return;
  const dues = reminders.checkDueReminders();
  if (!dues.length) {
    host.style.display = "none";
    return;
  }
  host.style.display = "block";
  const due = dues[0];
  const icon = due.kind === "water" ? "💧" : (due.kind === "takeTime" ? "🧘" : "⏰");

  host.innerHTML = `
    <div class="pop-rem-banner">
      <div class="pop-rem-head">
        <span class="pop-rem-ic">${icon}</span>
        <div class="pop-rem-meta">
          <b>${esc(due.rule.title)}</b>
          <div class="cap">${esc(due.rule.message)}</div>
        </div>
      </div>
      <div class="pop-rem-actions">
        <button class="pop-btn-pill" id="pop-rem-snooze5">Snooze 5m</button>
        <button class="pop-btn-pill" id="pop-rem-snooze15">Snooze 15m</button>
        <button class="pop-btn-pill highlight" id="pop-rem-done">Done</button>
      </div>
    </div>
  `;

  document.getElementById("pop-rem-snooze5")?.addEventListener("click", () => {
    reminders.snoozeReminder(due.rule.id, 5);
    paintAndFit();
  });
  document.getElementById("pop-rem-snooze15")?.addEventListener("click", () => {
    reminders.snoozeReminder(due.rule.id, 15);
    paintAndFit();
  });
  document.getElementById("pop-rem-done")?.addEventListener("click", () => {
    reminders.completeReminder(due.rule.id);
    paintAndFit();
  });
}

function paintPomodoroBar() {
  const host = document.getElementById("pop-pomodoro-bar");
  if (!host) return;

  const state = pomodoro.loadState();
  const timeStr = pomodoro.formatTime(state.remainingSeconds);
  const phaseLabels: Record<pomodoro.PomodoroPhase, string> = {
    focus: "Focus",
    shortBreak: "Short Break",
    longBreak: "Long Break",
    idle: "Idle",
  };
  const phaseLabel = phaseLabels[state.phase] || "Pomodoro";
  const manual = worktracker.getActiveManualSession();
  const todayAnalysis = worktracker.computeWorkAnalysis("today");
  const todayWorked = worktracker.formatDuration(todayAnalysis.totalWorkSeconds);
  const waterCups = reminders.getWaterCupsToday();

  const isRunning = state.isRunning;
  const playPauseIcon = isRunning ? "⏸" : "▶";

  host.innerHTML = `
    <div class="pop-pomo-wrap">
      <div class="pop-pomo-main">
        <div class="pop-pomo-time-block">
          <span class="pop-pomo-time">${timeStr}</span>
          <span class="pop-pomo-phase-badge ${state.phase}">${phaseLabel}</span>
        </div>
        <div class="pop-pomo-controls">
          <button class="pop-ic-btn" id="pop-pomo-toggle" title="${isRunning ? 'Pause' : 'Start'}">${playPauseIcon}</button>
          <button class="pop-ic-btn" id="pop-pomo-skip" title="Skip Phase">⏭</button>
          <button class="pop-ic-btn" id="pop-pomo-reset" title="Reset">↺</button>
        </div>
      </div>
      <div class="pop-pomo-subrow">
        <span class="pop-pomo-tag" title="Active Subject">🏷 ${esc(state.subjectTag || "General")}</span>
        <span class="spacer"></span>
        <span class="pop-pomo-worked">Worked: <b>${todayWorked}</b></span>
      </div>
      <div class="pop-pomo-tools">
        <button class="pop-chip-btn ${manual ? 'active' : ''}" id="pop-clock-btn">
          ${manual ? '⏹ Clock Out' : '⏱ Clock In'}
        </button>
        <button class="pop-chip-btn" id="pop-water-btn" title="Add 1 water glass">
          💧 ${waterCups} cups <span class="pop-plus">+1</span>
        </button>
      </div>
    </div>
  `;

  document.getElementById("pop-pomo-toggle")?.addEventListener("click", () => {
    if (state.isRunning) {
      pomodoro.pause();
    } else {
      if (state.phase === "idle") pomodoro.startFocus();
      else pomodoro.resume();
    }
    paintAndFit();
  });
  document.getElementById("pop-pomo-skip")?.addEventListener("click", () => {
    pomodoro.skipPhase();
    paintAndFit();
  });
  document.getElementById("pop-pomo-reset")?.addEventListener("click", () => {
    pomodoro.reset();
    paintAndFit();
  });
  document.getElementById("pop-clock-btn")?.addEventListener("click", () => {
    if (manual) {
      worktracker.stopManualWork();
    } else {
      const primary = goals.getPrimaryGoal();
      worktracker.startManualWork(primary ? primary.title : "Deep Work");
    }
    paintAndFit();
  });
  document.getElementById("pop-water-btn")?.addEventListener("click", () => {
    reminders.incrementWaterCup();
    paintAndFit();
  });
}

function paintQuoteCard() {
  const host = document.getElementById("pop-quote-card");
  if (!host) return;

  const quote = quotes.getCurrentQuote();
  const catLabel = quotes.CATEGORY_LABELS[quote.category] || quote.category;
  const catColor = quotes.CATEGORY_COLORS[quote.category] || "#3b82f6";
  const isFav = !!quote.isFavorite;

  host.innerHTML = `
    <div class="pop-quote-wrap">
      <div class="pop-quote-top">
        <span class="pop-quote-cat" style="background: ${catColor}22; color: ${catColor}; border: 1px solid ${catColor}44;">
          ${esc(catLabel)}
        </span>
        <span class="spacer"></span>
        <button class="pop-quote-btn ${isFav ? 'fav' : ''}" id="pop-quote-star" title="Star Favorite">${isFav ? '★' : '☆'}</button>
        <button class="pop-quote-btn" id="pop-quote-next" title="Next Quote">↻</button>
      </div>
      <div class="pop-quote-text">“${esc(quote.text)}”</div>
      ${quote.authorOrMeaning ? `<div class="pop-quote-meta">— ${esc(quote.authorOrMeaning)}</div>` : ''}
    </div>
  `;

  document.getElementById("pop-quote-star")?.addEventListener("click", () => {
    quotes.toggleQuoteFavorite(quote.id);
    paintAndFit();
  });
  document.getElementById("pop-quote-next")?.addEventListener("click", () => {
    quotes.getNextQuote();
    paintAndFit();
  });
}

function paint() {
  paintPrimaryGoal();
  paintReminderBanner();
  paintPomodoroBar();

  const sessions = visible();
  const running = sessions.filter((s) => s.state === "working").length;
  if (!sessions.length) {
    sub.textContent = t("No agents running");
  } else {
    const label = `${sessions.length} ${sessions.length === 1 ? t("agent") : t("agents")}`;
    sub.textContent = running > 0 ? `${label} · ${running} ${t("running")}` : label;
  }
  empty.style.display = sessions.length ? "none" : "";
  clearBtn.style.display = sessions.length ? "" : "none";

  list.innerHTML = "";
  for (const s of sessions) {
    const row = document.createElement("div");
    row.className = "pop-agent";
    row.dataset.state = s.state;
    const icon = agentIconUrl(s.agent);
    row.innerHTML =
      `<span class="sess-dot"></span>` +
      `<span class="pop-ameta"><b>${esc(s.project ? projectLabel(s.project) : s.session)}</b>` +
      `<span class="cap">${esc(s.title || s.live || t(cap(s.state)))}</span></span>` +
      (icon ? `<img class="dp-icon" src="${icon}" alt="">` : "") +
      `<span class="sess-time">${timeString(s)}</span>`;
    const x = document.createElement("button");
    x.className = "sess-x";
    x.textContent = "✕";
    x.onclick = () => {
      const key = `${s.agent}:${s.session}`;
      store.removeKey(key);
      emit("session-dismiss", key);
      paint();
    };
    row.appendChild(x);
    list.appendChild(row);
  }
  paintLimits();
  paintQuoteCard();
}

/// Subscription limits from the pet window's cache (no extra API call), only
/// the providers left visible in Settings > Care, like the mac stats card.
function paintLimits() {
  const wrap = document.getElementById("pop-limits")!;
  const host = document.getElementById("pop-limits-list")!;
  const shown = limits.visible(limits.cached());
  wrap.style.display = shown.length ? "" : "none";
  const html = shown.map((p) =>
    `<div class="pop-limit"><div class="pop-limit-name">${esc(p.display_name)}</div>${limits.windowRowsHtml(p, true)}</div>`).join("");
  if (host.innerHTML !== html) host.innerHTML = html;
}

function cap(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

/// mac AgentRow.timeString: live elapsed while active, clock time once done.
function timeString(s: Session): string {
  if (s.state === "done") {
    return new Date(s.updatedAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  }
  return elapsedString(s.stateSince);
}

// ---- controls ----------------------------------------------------------------

(document.getElementById("pop-clear") as HTMLButtonElement).onclick = () => {
  store.clear();
  emit("sessions-clear", null);
  paint();
};

const showPet = document.getElementById("pop-showpet") as HTMLInputElement;
invoke<boolean>("get_pet_visible").then((v) => { showPet.checked = v; }).catch(() => { showPet.checked = true; });
showPet.onchange = () => invoke("set_pet_visible", { visible: showPet.checked }).catch(() => {});

const size = document.getElementById("pop-size") as HTMLInputElement;
size.value = localStorage.getItem("ap_pet_size") || "100";
size.oninput = () => {
  localStorage.setItem("ap_pet_size", size.value);
  emit("bubble-changed", null);
};

function safeCurrentWindow() {
  try { return getCurrentWindow(); } catch { return null; }
}

(document.getElementById("pop-settings") as HTMLButtonElement).onclick = () => {
  invoke("open_settings").catch(() => {});
  void safeCurrentWindow()?.hide();
};
(document.getElementById("pop-quit") as HTMLButtonElement).onclick = () => { exit(0); };

const updatesBtn = document.getElementById("pop-updates") as HTMLButtonElement;
updatesBtn.onclick = async () => {
  const label = document.getElementById("t-pop-updates")!;
  label.textContent = t("Checking…");
  try {
    const update = await check();
    if (update) {
      label.textContent = t("Installing…");
      await update.downloadAndInstall();
      await relaunch();
    } else {
      label.textContent = t("Up to date");
      setTimeout(() => { label.textContent = t("Updates"); }, 2500);
    }
  } catch {
    label.textContent = t("Up to date");
    setTimeout(() => { label.textContent = t("Updates"); }, 2500);
  }
};

// ---- lifecycle ----------------------------------------------------------------

try {
  safeCurrentWindow()?.onFocusChanged(({ payload: focused }) => {
    if (!focused) void safeCurrentWindow()?.hide();
  });
} catch {}
try { listen("popover-close", () => void safeCurrentWindow()?.hide()).catch?.(() => {}); } catch {}
window.addEventListener("keydown", (e) => {
  if (e.key === "Escape") void safeCurrentWindow()?.hide();
});

try { listen<AgentEventPayload>("agent-event", (e) => { store.update(e.payload); paintAndFit(); }).catch?.(() => {}); } catch {}
try { listen<string>("agent-end", (e) => { store.remove(e.payload); paintAndFit(); }).catch?.(() => {}); } catch {}
try { listen<{ agent: string; session: string; title: string }>("agent-title", (e) => {
  store.setTitle(e.payload.agent, e.payload.session, e.payload.title);
  paintAndFit();
}).catch?.(() => {}); } catch {}
try { listen<Session>("session-snapshot", (e) => { store.seed(e.payload); paintAndFit(); }).catch?.(() => {}); } catch {}
try { listen("popover-shown", () => {
  size.value = localStorage.getItem("ap_pet_size") || "100";
  invoke<boolean>("get_pet_visible").then((v) => { showPet.checked = v; }).catch(() => {});
  try { emit("sessions-request", null).catch?.(() => {}); } catch {}
  paintAndFit();
}).catch?.(() => {}); } catch {}
try { emit("sessions-request", null).catch?.(() => {}); } catch {}

// Synchronize external changes
window.addEventListener("goals-changed", () => paintAndFit());
window.addEventListener("quotes-changed", () => paintAndFit());
window.addEventListener("worktracker-changed", () => paintAndFit());
window.addEventListener("pomodoro-changed", () => paintAndFit());
window.addEventListener("reminders-changed", () => paintAndFit());

let lastH = 0;
function fitWindow() {
  const card = document.querySelector(".pop-card") as HTMLElement;
  if (!card) return;
  const h = Math.min(680, Math.max(220, card.scrollHeight + 20));
  if (Math.abs(h - lastH) < 2) return;
  lastH = h;
  try { safeCurrentWindow()?.setSize(new LogicalSize(320, h)).catch?.(() => {}); } catch {}
}

function tickAndPaint() {
  pomodoro.tickPomodoro();
  quotes.checkQuoteRotation();
  worktracker.syncFromAgentHistory();
  paint();
  fitWindow();
}

function paintAndFit() {
  paint();
  fitWindow();
}

setInterval(tickAndPaint, 1000);
applyStatic();
paintAndFit();

// Stats card window (pet right-click), a port of the macOS PetStatsView
// popover + Personal Work Analysis & Primary Target Dashboard.
// Wires data, the sprite thumbnail, badge hover hints, the footer,
// interactive period switcher, milestone toggles, sizing and focus-loss hiding.

import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { check } from "@tauri-apps/plugin-updater";
import { relaunch, exit } from "@tauri-apps/plugin-process";
import * as care from "./care";
import * as limits from "./limits";
import * as usage from "./usage";
import * as goals from "./goals";
import * as pomo from "./pomodoro";
import * as reminders from "./reminders";
import * as quotes from "./quotes";
import * as worktracker from "./worktracker";
import { focusMusic } from "./focusmusic";
import { savedSlug, getLibrary, petDisplayName } from "./catalog";
import { t, getLang, setLang, type Lang } from "./i18n";
import { cardHtml, hintText, esc } from "./statscard";

const body = document.getElementById("sc-body")!;
let petSlug: string | null = new URLSearchParams(location.search).get("pet");
let currentView: "all" | "work" | "pet" = (localStorage.getItem("ap_stats_view") as "all" | "work" | "pet") || "all";
let activePeriod: "today" | "7d" | "30d" = "today";

function currentSlug(): string | null { return petSlug || savedSlug(); }

function petName(slug: string | null): string {
  if (!slug) return t("Your pet");
  const custom = petDisplayName(slug);
  if (custom !== slug) return custom;
  return getLibrary().find((p) => p.slug === slug)?.name || slug;
}

function petSheetUrl(slug: string | null): string | null {
  const lib = getLibrary();
  const hit = lib.find((p) => p.slug === slug)?.url;
  if (hit) return hit;
  const selected = localStorage.getItem("ap_pet_custom") || localStorage.getItem("ap_pet_url");
  if (selected && (!slug || slug === savedSlug())) return selected;
  const saved = lib.find((p) => p.slug === savedSlug())?.url;
  return saved || selected || lib[0]?.url || null;
}

function drawThumb(url: string | null) {
  const cv = document.getElementById("sc-thumb") as HTMLCanvasElement | null;
  const ctx = cv?.getContext("2d");
  if (!cv || !ctx || !url) return;
  ctx.imageSmoothingEnabled = false;
  const img = new Image();
  img.onload = () => {
    const fw = img.naturalWidth / 8, fh = img.naturalHeight / 9;
    if (!fw || !fh) return;
    const sc = Math.min(cv.width / fw, cv.height / fh);
    ctx.clearRect(0, 0, cv.width, cv.height);
    ctx.drawImage(img, 0, 0, fw, fh, (cv.width - fw * sc) / 2, (cv.height - fh * sc) / 2, fw * sc, fh * sc);
  };
  img.src = url;
}

function renderWorkHtml(period: "today" | "7d" | "30d"): string {
  const primary = goals.getPrimaryGoal();
  const dailyTarget = primary ? primary.dailyTargetMinutes : 240;
  const analysis = worktracker.computeWorkAnalysis(period, { dailyTargetMinutes: dailyTarget });

  const totalWorkedStr = worktracker.formatDuration(analysis.totalWorkSeconds);
  const totalBreaksStr = worktracker.formatDuration(analysis.totalBreakSeconds);
  const focusRatioPct = Math.round(analysis.focusRatio * 100);
  const peakHourStr = `${String(analysis.peakHour).padStart(2, "0")}:00`;

  // 1. Primary Target Goal Card (if set)
  let targetHtml = "";
  if (primary) {
    const m = goals.computeGoalMetrics(primary);
    const pct = Math.round(m.timelineProgress * 100);
    const msDone = m.milestoneCount.completed;
    const msTotal = m.milestoneCount.total;

    const milestonesHtml = primary.milestones.slice(0, 5).map((ms) => `
      <label class="sc-work-ms-item ${ms.completed ? 'completed' : ''}">
        <input type="checkbox" class="sc-ms-toggle" data-goal-id="${primary.id}" data-ms-id="${ms.id}" ${ms.completed ? 'checked' : ''} />
        <span>${esc(ms.title)}</span>
      </label>
    `).join("");

    targetHtml = `
      <div class="sc-work-target-card">
        <div class="sc-work-target-head">
          <span class="sc-work-tag">${esc(primary.category.toUpperCase())}</span>
          <span class="sc-work-badge">PRIMARY TARGET</span>
        </div>
        <div class="sc-work-title">${esc(primary.title)}</div>
        <div class="sc-work-status-row">
          <span class="sc-work-highlight">${esc(m.statusLabel)}</span>
          <span class="dim">·</span>
          <span class="dim">${esc(m.passedLabel)}</span>
        </div>
        <div class="sc-work-bar-wrap">
          <div class="sc-work-bar" style="width: ${pct}%"></div>
        </div>
        <div class="sc-work-bar-meta">
          <span>Timeline: ${pct}%</span>
          <span>Milestones: ${msDone}/${msTotal}</span>
        </div>
        ${primary.milestones.length ? `<div class="sc-work-ms-list">${milestonesHtml}</div>` : ''}
      </div>
    `;
  } else {
    targetHtml = `
      <div class="sc-work-target-card empty">
        <div class="cap dim">No Primary Target set. Go to Settings > Targets to set your exam / study goal countdown!</div>
      </div>
    `;
  }

  // 2. Period Switcher
  const periodSwitcher = `
    <div class="sc-period-tabs">
      <button class="sc-pbtn ${period === 'today' ? 'sel' : ''}" data-p="today">Today</button>
      <button class="sc-pbtn ${period === '7d' ? 'sel' : ''}" data-p="7d">Last 7 Days</button>
      <button class="sc-pbtn ${period === '30d' ? 'sel' : ''}" data-p="30d">Last 30 Days</button>
    </div>
  `;

  // 3. Grid of Summary Stats Cards
  const summaryGrid = `
    <div class="sc-grid">
      <div class="sc-cell">
        <div class="sc-cl">TOTAL WORKED</div>
        <div class="sc-cv">${totalWorkedStr}</div>
        <div class="sc-cs">Focus Time</div>
      </div>
      <div class="sc-cell">
        <div class="sc-cl">BREAKS</div>
        <div class="sc-cv">${totalBreaksStr}</div>
        <div class="sc-cs">Rest Taken</div>
      </div>
      <div class="sc-cell">
        <div class="sc-cl">FOCUS RATIO</div>
        <div class="sc-cv">${focusRatioPct}%</div>
        <div class="sc-cs">Efficiency</div>
      </div>
      <div class="sc-cell">
        <div class="sc-cl">PEAK FOCUS</div>
        <div class="sc-cv">${peakHourStr}</div>
        <div class="sc-cs">Sharpest Hour</div>
      </div>
      <div class="sc-cell" style="grid-column: span 2">
        <div class="sc-cl">DAILY TARGET ATTAINMENT</div>
        <div class="sc-cv">${Math.round(analysis.targetAttainment * 100)}%</div>
        <div class="sc-cs">${analysis.activeStreakDays} active day streak</div>
      </div>
    </div>
  `;

  // 4. Category Breakdown Bars
  let categoryHtml = "";
  if (analysis.categoryBreakdown.length) {
    categoryHtml = `
      <div class="sc-sec"><span>SUBJECT / CATEGORY BREAKDOWN</span></div>
      <div class="sc-cats-list">
        ${analysis.categoryBreakdown.map((c) => `
          <div class="sc-cat-row">
            <div class="sc-cat-meta">
              <span>${esc(c.category)}</span>
              <span><b>${worktracker.formatDuration(c.seconds)}</b> (${Math.round(c.percentage)}%)</span>
            </div>
            <div class="sc-cat-bar-wrap">
              <div class="sc-cat-bar" style="width: ${c.percentage}%"></div>
            </div>
          </div>
        `).join("")}
      </div>
    `;
  }

  // 5. Source Breakdown
  let sourceHtml = "";
  if (analysis.sourceBreakdown.length) {
    const srcLabels: Record<worktracker.WorkSource, string> = {
      pomodoro: "Pomodoro Clock",
      manual: "Manual Clock-In",
      agent: "AI Agent Sessions",
      presence: "Active Presence",
    };
    sourceHtml = `
      <div class="sc-sec"><span>WORK TIME BY SOURCE</span></div>
      <div class="sc-cats-list">
        ${analysis.sourceBreakdown.map((s) => `
          <div class="sc-cat-row">
            <div class="sc-cat-meta">
              <span>${esc(srcLabels[s.source] || s.source)}</span>
              <span>${worktracker.formatDuration(s.seconds)} (${Math.round(s.percentage)}%)</span>
            </div>
            <div class="sc-cat-bar-wrap">
              <div class="sc-cat-bar" style="width: ${s.percentage}%; background: #0a84ff;"></div>
            </div>
          </div>
        `).join("")}
      </div>
    `;
  }

  // 6. 14-Day Daily Trend Chart
  const trendMax = Math.max(60, ...analysis.dailyTrend.map((d) => Math.max(d.workMinutes, d.targetMinutes)));
  const trendBars = analysis.dailyTrend.map((d, idx) => {
    const isToday = idx === analysis.dailyTrend.length - 1;
    const h = Math.max(3, Math.round((d.workMinutes / trendMax) * 40));
    const hitTarget = d.workMinutes >= d.targetMinutes;
    const barColor = hitTarget ? "#30d158" : (isToday ? "#0a84ff" : "rgba(255,255,255,0.4)");
    return `
      <div class="sc-bw" title="${esc(d.dateStr)}: ${d.workMinutes}m / ${d.targetMinutes}m target">
        <div class="sc-bar" style="height:${h}px; background:${barColor}"></div>
        <div class="sc-bl">${esc(d.dayLabel)}</div>
      </div>
    `;
  }).join("");

  const trendHtml = `
    <div class="sc-sec"><span>14-DAY DAILY WORK TREND</span></div>
    <div class="sc-chart">${trendBars}</div>
  `;

  // 7. 24-Hour Peak Focus Heatmap / Columns
  const peakMax = Math.max(1, ...analysis.hourlyDistribution.map((h) => h.workMinutes));
  const hourlyBars = analysis.hourlyDistribution.map((h) => {
    const barHeight = Math.max(2, Math.round((h.workMinutes / peakMax) * 32));
    const isPeak = h.hour === analysis.peakHour && h.workMinutes > 0;
    const color = isPeak ? "#ff9f0a" : "rgba(10, 132, 255, 0.65)";
    const showLabel = h.hour % 4 === 0;
    return `
      <div class="sc-hw" title="${h.label}:00 — ${h.workMinutes}m">
        <div class="sc-hbar" style="height:${barHeight}px; background:${color}"></div>
        <div class="sc-hl">${showLabel ? h.label : ''}</div>
      </div>
    `;
  }).join("");

  const peakHtml = `
    <div class="sc-sec"><span>24-HOUR PEAK FOCUS DISTRIBUTION</span><b>Peak: ${peakHourStr}</b></div>
    <div class="sc-hchart">${hourlyBars}</div>
  `;

  return `
    ${targetHtml}
    ${periodSwitcher}
    ${summaryGrid}
    ${categoryHtml}
    ${sourceHtml}
    ${trendHtml}
    ${peakHtml}
  `;
}

function bindCardActions() {
  // Focus Target button
  body.querySelectorAll<HTMLButtonElement>('[data-action="focus-target"]').forEach((btn) => {
    btn.onclick = () => {
      const primary = goals.getPrimaryGoal();
      pomo.startFocus(primary ? primary.title : "Target Focus");
      paint();
    };
  });

  // Pomodoro controls
  body.querySelectorAll<HTMLButtonElement>('[data-action="pomo-start"]').forEach((btn) => {
    btn.onclick = () => {
      pomo.startFocus();
      paint();
    };
  });
  body.querySelectorAll<HTMLButtonElement>('[data-action="pomo-break"]').forEach((btn) => {
    btn.onclick = () => {
      pomo.startBreak(false);
      paint();
    };
  });
  body.querySelectorAll<HTMLButtonElement>('[data-action="pomo-pause"]').forEach((btn) => {
    btn.onclick = () => {
      pomo.pause();
      paint();
    };
  });
  body.querySelectorAll<HTMLButtonElement>('[data-action="pomo-resume"]').forEach((btn) => {
    btn.onclick = () => {
      pomo.resume();
      paint();
    };
  });
  body.querySelectorAll<HTMLButtonElement>('[data-action="pomo-stop"]').forEach((btn) => {
    btn.onclick = () => {
      pomo.stop();
      paint();
    };
  });
  body.querySelectorAll<HTMLButtonElement>('[data-action="pomo-skip"]').forEach((btn) => {
    btn.onclick = () => {
      pomo.skipPhase();
      paint();
    };
  });
  body.querySelectorAll<HTMLButtonElement>('[data-action="pomo-reset"]').forEach((btn) => {
    btn.onclick = () => {
      pomo.reset();
      paint();
    };
  });

  // Manual Clock In / Clock Out
  body.querySelectorAll<HTMLButtonElement>('[data-action="toggle-manual-work"]').forEach((btn) => {
    btn.onclick = () => {
      if (worktracker.getActiveManualSession()) {
        worktracker.stopManualWork();
      } else {
        const prim = goals.getPrimaryGoal();
        worktracker.startManualWork(prim ? prim.title : "GATE Exam");
      }
      paint();
    };
  });

  // Water cup increment
  body.querySelectorAll<HTMLButtonElement>('[data-action="quick-water"]').forEach((btn) => {
    btn.onclick = () => {
      reminders.incrementWaterCup();
      paint();
    };
  });

  // Due reminders: Snooze / Done
  body.querySelectorAll<HTMLButtonElement>('[data-action="snooze-5"]').forEach((btn) => {
    btn.onclick = () => {
      const id = btn.dataset.ruleId;
      if (id) reminders.snoozeReminder(id, 5);
      paint();
    };
  });
  body.querySelectorAll<HTMLButtonElement>('[data-action="done-reminder"]').forEach((btn) => {
    btn.onclick = () => {
      const id = btn.dataset.ruleId;
      if (id) reminders.completeReminder(id);
      paint();
    };
  });

  // Quotes: Favorite toggle & Next Quote
  body.querySelectorAll<HTMLButtonElement>('[data-action="toggle-favorite"]').forEach((btn) => {
    btn.onclick = () => {
      const id = btn.dataset.quoteId;
      if (id) quotes.toggleQuoteFavorite(id);
      paint();
    };
  });
  body.querySelectorAll<HTMLButtonElement>('[data-action="next-quote"]').forEach((btn) => {
    btn.onclick = () => {
      quotes.getNextQuote();
      paint();
    };
  });

  // Focus Music: Play/Stop & Station Switch
  body.querySelectorAll<HTMLButtonElement>('[data-action="music-toggle"]').forEach((btn) => {
    btn.onclick = () => {
      focusMusic.toggle();
      paint();
    };
  });
  body.querySelectorAll<HTMLButtonElement>('[data-action="music-station"]').forEach((btn) => {
    btn.onclick = () => {
      const id = btn.dataset.stationId;
      if (id) focusMusic.selectStation(id);
      paint();
    };
  });
}

let lastHtml = "";
function paint() {
  const btnAll = document.getElementById("sc-view-all") as HTMLButtonElement | null;
  const btnWork = document.getElementById("sc-view-work") as HTMLButtonElement | null;
  const btnPet = document.getElementById("sc-view-pet") as HTMLButtonElement | null;

  if (btnAll) btnAll.classList.toggle("sel", currentView === "all");
  if (btnWork) btnWork.classList.toggle("sel", currentView === "work");
  if (btnPet) btnPet.classList.toggle("sel", currentView === "pet");

  if (currentView === "all" || currentView === "pet") {
    const slug = currentSlug();
    const state = slug ? care.stateFor(slug) : care.emptyState();
    const html = cardHtml({
      name: petName(slug), state, providers: limits.cached(),
      costToday: usage.todayCostUSD(), costMonth: usage.monthlyCostUSD(), agents: usage.byAgent(), lang: getLang(),
      showPersonalized: (currentView === "all"),
    });

    if (html !== lastHtml) {
      lastHtml = html;
      body.innerHTML = html;
      drawThumb(petSheetUrl(slug));
      const hint = document.getElementById("sc-hint");
      if (hint) {
        const idle = hint.textContent || "";
        const unlocked = new Set(state.unlockedAchievements || []);
        body.querySelectorAll<HTMLElement>(".sc-badge").forEach((b) => {
          b.onmouseenter = () => { hint.textContent = hintText(b.dataset.ach!, unlocked.has(b.dataset.ach!)); hint.classList.add("on"); };
          b.onmouseleave = () => { hint.textContent = idle; hint.classList.remove("on"); };
        });
      }
      bindCardActions();
    }
  } else {
    // Work Analysis View
    worktracker.syncFromAgentHistory();
    const html = renderWorkHtml(activePeriod);
    lastHtml = html;
    body.innerHTML = html;

    // Bind period buttons
    body.querySelectorAll<HTMLButtonElement>(".sc-pbtn").forEach((btn) => {
      btn.onclick = () => {
        activePeriod = btn.dataset.p as "today" | "7d" | "30d";
        paint();
      };
    });

    // Bind milestone toggles
    body.querySelectorAll<HTMLInputElement>(".sc-ms-toggle").forEach((chk) => {
      chk.onchange = () => {
        goals.toggleMilestone(chk.dataset.goalId!, chk.dataset.msId!);
        paint();
      };
    });
  }

  fit();
}

let lastH = 0;
function fit() {
  const card = document.querySelector(".sc-card") as HTMLElement;
  const scroller = document.getElementById("sc-body")!;
  const h = Math.ceil(card.offsetHeight - scroller.clientHeight + scroller.scrollHeight + 16);
  if (Math.abs(h - lastH) < 2) return;
  lastH = h;
  invoke("stats_resized", { height: h }).catch(() => {});
}

// Switcher tab click events
document.getElementById("sc-view-all")?.addEventListener("click", () => {
  currentView = "all";
  localStorage.setItem("ap_stats_view", "all");
  lastHtml = "";
  paint();
});

document.getElementById("sc-view-work")?.addEventListener("click", () => {
  currentView = "work";
  localStorage.setItem("ap_stats_view", "work");
  lastHtml = "";
  paint();
});

document.getElementById("sc-view-pet")?.addEventListener("click", () => {
  currentView = "pet";
  localStorage.setItem("ap_stats_view", "pet");
  lastHtml = "";
  paint();
});

listen<{ edge: string; offset: number }>("stats-anchor", (e) => {
  const card = document.querySelector(".sc-card") as HTMLElement;
  card.dataset.edge = e.payload.edge;
  card.style.setProperty("--arrow-x", `${Math.round(e.payload.offset - 8)}px`);
});

function applyStatic() {
  const set = (id: string, key: string) => { const el = document.getElementById(id); if (el) el.textContent = t(key); };
  set("t-sc-settings", "Settings");
  set("t-sc-updates", "Updates");
  set("t-sc-quit", "Quit");
}

function safeCurrentWindow() {
  try { return getCurrentWindow(); } catch { return null; }
}

(document.getElementById("sc-settings") as HTMLButtonElement).onclick = () => {
  invoke("open_settings").catch(() => {});
  void safeCurrentWindow()?.hide();
};
(document.getElementById("sc-quit") as HTMLButtonElement).onclick = () => { exit(0); };
const upd = document.getElementById("sc-updates") as HTMLButtonElement;
upd.onclick = async () => {
  const label = document.getElementById("t-sc-updates")!;
  const reset = () => setTimeout(() => { label.textContent = t("Updates"); }, 2500);
  label.textContent = t("Checking…");
  try {
    const update = await check();
    if (update) { label.textContent = t("Installing…"); await update.downloadAndInstall(); await relaunch(); }
    else { label.textContent = t("Up to date"); reset(); }
  } catch { label.textContent = t("Up to date"); reset(); }
};

try {
  safeCurrentWindow()?.onFocusChanged(({ payload: focused }) => { if (!focused) void safeCurrentWindow()?.hide(); });
} catch {}
try { listen("popover-close", () => void safeCurrentWindow()?.hide()).catch?.(() => {}); } catch {}
window.addEventListener("keydown", (e) => { if (e.key === "Escape") void safeCurrentWindow()?.hide(); });
window.addEventListener("contextmenu", (e) => e.preventDefault());

try { listen<string | null>("stats-shown", (e) => { petSlug = e.payload || null; lastHtml = ""; paint(); }).catch?.(() => {}); } catch {}
try { listen("care-updated", () => { lastHtml = ""; paint(); }).catch?.(() => {}); } catch {}
try { listen<Lang>("lang-changed", (e) => { setLang(e.payload); applyStatic(); lastHtml = ""; paint(); }).catch?.(() => {}); } catch {}

window.addEventListener("goals-changed", () => { lastHtml = ""; paint(); });
window.addEventListener("worktracker-changed", () => { lastHtml = ""; paint(); });
window.addEventListener("pomodoro-changed", () => { lastHtml = ""; paint(); });
window.addEventListener("reminders-changed", () => { lastHtml = ""; paint(); });
window.addEventListener("quotes-changed", () => { lastHtml = ""; paint(); });

setInterval(paint, 15_000);

applyStatic();
paint();

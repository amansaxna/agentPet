// The pet's right-click stats card, a port of the macOS PetStatsView:
// header (sprite, level, stage, hunger), XP, primary target goal countdown,
// pomodoro status bar, due reminders, tailored quote strip, achievements,
// four stat cells, 7-day burn, cost, subscription limits, and last fed.
// Pure HTML builders live here so they can be tested without a webview.

import * as care from "./care";
import * as limits from "./limits";
import * as goals from "./goals";
import * as pomo from "./pomodoro";
import * as reminders from "./reminders";
import * as quotes from "./quotes";
import * as worktracker from "./worktracker";
import { focusMusic, STATIONS } from "./focusmusic";
import { dayProgress } from "./dayprogress";
import { t } from "./i18n";
import { agentLabel } from "./state";

// mac PetStatsView.stageColors: green, teal, blue, purple, orange.
export const STAGE_COLORS = ["#30d158", "#40c8e0", "#0a84ff", "#bf5af2", "#ff9f0a"];

export const ACH_HINT: Record<string, string> = {
  firstMeal: "Finish your first agent session", sessions100: "Finish 100 agent sessions",
  sessions500: "Finish 500 agent sessions", tokens1M: "Burn 1M tokens", tokens10M: "Burn 10M tokens",
  tokens50M: "Burn 50M tokens", level5: "Reach Level 5", level10: "Reach Level 10",
  level20: "Reach Level 20", level35: "Reach Level 35 (Legend)", streak7: "Feed your pet 7 days in a row",
  streak14: "Feed your pet 14 days in a row", streak30: "Feed your pet 30 days in a row",
  nightOwl: "Finish a session after midnight",
  focus1Hour: "Accumulate 1 hour of total focus time",
  focus10Hours: "Accumulate 10 hours of total focus time",
  focus50Hours: "Accumulate 50 hours of total focus time",
  focus100Hours: "Accumulate 100 hours of total focus time",
};

export function esc(s: string): string {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
}

/// mac PetStatsView.tokenString: 1.2M / 962k / 512.
export function tokenString(n: number): string {
  n = Math.max(0, Math.floor(Number(n) || 0));
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${Math.round(n / 1_000)}k`;
  return String(n);
}

/// Continuous fullness 0..1: 48 h since the last feeding is empty (mac `fullness`).
export function fullness(s: care.CareState, now = Date.now()): number {
  if (s.lastFedAt == null) return 0.5;
  return Math.max(0, Math.min(1, 1 - (now - s.lastFedAt) / 3_600_000 / 48));
}

/// XP earned inside the current level and the level's span (mac xpWithinLevel).
export function xpWithinLevel(xp: number): { inLevel: number; span: number } {
  const level = care.levelForXP(xp);
  const floor = care.xpToReach(level), ceil = care.xpToReach(level + 1);
  return { inLevel: Math.max(0, xp - floor), span: Math.max(1, ceil - floor) };
}

/// "4 minutes ago" in the UI language.
export function relativeAgo(ms: number, now = Date.now(), lang = "en"): string {
  const secs = Math.round((ms - now) / 1000);
  const rtf = new Intl.RelativeTimeFormat(lang === "zh-TW" ? "zh-Hant" : lang, { numeric: "auto" });
  const a = Math.abs(secs);
  if (a < 60) return rtf.format(secs, "second");
  if (a < 3600) return rtf.format(Math.round(secs / 60), "minute");
  if (a < 86400) return rtf.format(Math.round(secs / 3600), "hour");
  return rtf.format(Math.round(secs / 86400), "day");
}

const HUNGER_LABEL: Record<care.Hunger, string> = {
  full: "Full", satisfied: "Satisfied", peckish: "Peckish", hungry: "Hungry", starving: "Starving",
};

export interface CardInput {
  name: string;
  state: care.CareState;
  providers: limits.LimitProvider[];
  costToday: number;
  costMonth: number;
  /// Per-agent token totals (usage.byAgent()); the section is hidden when empty.
  agents?: { agent: string; today: number; month: number; sessions: number }[];
  now?: number;
  lang?: string;
  showPersonalized?: boolean;
}

// MARK: - Personalized Section Builders

export function dueAlertHtml(): string {
  const dueList = reminders.checkDueReminders();
  if (!dueList.length) return "";
  const d = dueList[0];
  return `
    <div class="sc-due-banner">
      <div class="sc-due-head">
        <span class="sc-due-icon">${d.kind === "water" ? "💧" : "⏰"}</span>
        <b class="sc-due-title">${esc(d.rule.title)}</b>
        <span class="sc-due-badge">DUE</span>
      </div>
      <div class="sc-due-msg">${esc(d.rule.message)}</div>
      <div class="sc-due-actions">
        <button class="sc-due-btn snooze" data-rule-id="${esc(d.rule.id)}" data-action="snooze-5">Snooze 5m</button>
        <button class="sc-due-btn done" data-rule-id="${esc(d.rule.id)}" data-action="done-reminder">Done</button>
      </div>
    </div>
  `;
}

export function primaryTargetHtml(color: string): string {
  const primary = goals.getPrimaryGoal();
  if (!primary) return "";
  const m = goals.computeGoalMetrics(primary);
  const pct = Math.round(m.timelineProgress * 100);
  const analysis = worktracker.computeWorkAnalysis("today");
  const workedTodayStr = worktracker.formatDuration(analysis.totalWorkSeconds);
  const targetHours = Math.round(primary.dailyTargetMinutes / 60);

  return `
    <div class="sc-target-card" style="border-color:${color}40">
      <div class="sc-target-head">
        <span class="sc-target-tag" style="color:${color};background:${color}26">${esc(primary.category.toUpperCase())}</span>
        <span class="sc-target-tag-sub">PRIMARY TARGET</span>
        <span class="sc-target-badge" style="color:${m.isPastTarget ? '#ff453a' : color};background:${m.isPastTarget ? '#ff453a26' : color + '26'}">${esc(m.statusLabel)}</span>
      </div>
      <div class="sc-target-row">
        <div class="sc-target-title">${esc(primary.title)}</div>
        <button class="sc-focus-btn" data-action="focus-target" style="background:${color};color:#000">▶ Focus</button>
      </div>
      <div class="sc-target-pbar-wrap">
        <div class="sc-target-pbar" style="width:${pct}%;background:${color}"></div>
      </div>
      <div class="sc-target-meta">
        <span>${esc(m.passedLabel)}</span>
        <span>Today ${esc(workedTodayStr)} / ${targetHours}h</span>
      </div>
    </div>
  `;
}

export function pomoAndWorkHtml(color: string): string {
  const pState = pomo.loadState();
  const isRunning = pState.phase !== "idle";
  const isFocus = pState.phase === "focus";
  const isBreak = pState.phase === "shortBreak" || pState.phase === "longBreak";
  const phaseColor = isFocus ? "#ff453a" : isBreak ? "#30d158" : "#8e8e93";
  const phaseLabel = isRunning ? pState.phase.toUpperCase() : "POMODORO";
  const timeStr = pomo.formatTime(pState.remainingSeconds);
  const waterCups = reminders.getWaterCupsToday();
  const analysis = worktracker.computeWorkAnalysis("today");
  const workedStr = worktracker.formatDuration(analysis.totalWorkSeconds);
  const isManual = !!worktracker.getActiveManualSession();

  const actionButtons = !isRunning
    ? `
      <button class="sc-pbtn-action focus" data-action="pomo-start" style="background:${color};color:#000">▶ Start Focus</button>
      <button class="sc-pbtn-action break" data-action="pomo-break">☕ Start Break</button>
    `
    : `
      <button class="sc-pbtn-action" data-action="${pState.isRunning ? 'pomo-pause' : 'pomo-resume'}" style="background:${color};color:#000">
        ${pState.isRunning ? '⏸ Pause' : '▶ Resume'}
      </button>
      <button class="sc-pbtn-action stop" data-action="pomo-stop">⏹ Stop</button>
      ${isFocus
        ? `<button class="sc-pbtn-action break" data-action="pomo-break">☕ Break</button>`
        : `<button class="sc-pbtn-action focus" data-action="pomo-start">🎯 Focus</button>`
      }
    `;

  return `
    <div class="sc-pomo-bar" style="border: 1px solid ${isRunning ? (isFocus ? 'rgba(255, 69, 58, 0.35)' : 'rgba(48, 209, 88, 0.35)') : 'rgba(255, 255, 255, 0.08)'}">
      <div class="sc-pomo-top">
        <div class="sc-pomo-status">
          <span class="sc-pomo-dot" style="background:${phaseColor}"></span>
          <b class="sc-pomo-phase" style="color:${phaseColor}">${phaseLabel}</b>
          ${isRunning && pState.subjectTag ? `<span class="dim">· ${esc(pState.subjectTag)}</span>` : ''}
        </div>
        <b class="sc-pomo-time" style="color:${isRunning && !pState.isRunning ? '#ff9f0a' : '#fff'}">${timeStr}</b>
      </div>
      <div class="sc-pomo-actions-row">
        ${actionButtons}
      </div>
      <div class="sc-pomo-sub">
        <button class="sc-work-toggle-btn ${isManual ? 'active' : ''}" data-action="toggle-manual-work">
          ${isManual ? '⏹ Clock Out' : '▶ Clock In'}
        </button>
        <button class="sc-water-btn" data-action="quick-water" title="Log 1 cup of water">
          💧 +1 Water (${waterCups})
        </button>
        <span class="sc-pomo-worked">⏱ ${esc(workedStr)}</span>
      </div>
    </div>
  `;
}

export function quoteStripHtml(color: string): string {
  const item = quotes.getCurrentQuote();
  const catLabel = quotes.CATEGORY_LABELS[item.category] || item.category;

  return `
    <div class="sc-quote-card">
      <div class="sc-quote-head">
        <span class="sc-quote-cat" style="color:${color};background:${color}26">${esc(catLabel.toUpperCase())}</span>
        <div class="sc-quote-ctrls">
          <button class="sc-quote-btn" data-action="toggle-favorite" data-quote-id="${esc(item.id)}" title="Favorite">${item.isFavorite ? '★' : '☆'}</button>
          <button class="sc-quote-btn" data-action="next-quote" title="Next Quote">↻</button>
        </div>
      </div>
      <div class="sc-quote-text">“${esc(item.text)}”</div>
      ${item.authorOrMeaning ? `<div class="sc-quote-author">${item.category === 'idioms' ? 'Meaning: ' : '— '}${esc(item.authorOrMeaning)}</div>` : ''}
    </div>
  `;
}

export function focusMusicHtml(color: string): string {
  const isPlaying = focusMusic.getPlaying();
  const station = focusMusic.getCurrentStation();
  const stations = STATIONS;

  const stationPills = stations.map(s => `
    <button class="sc-music-station ${s.id === station.id ? 'active' : ''}" data-action="music-station" data-station-id="${esc(s.id)}" title="${esc(s.description)}">
      ${esc(s.icon)} ${esc(s.title.split(' ')[0])}
    </button>
  `).join("");

  return `
    <div class="sc-music-bar" style="border: 1px solid ${isPlaying ? 'rgba(59, 130, 246, 0.45)' : 'rgba(255, 255, 255, 0.08)'}">
      <div class="sc-music-top">
        <div class="sc-music-status">
          <span class="sc-music-dot" style="background:${isPlaying ? '#3b82f6' : '#8e8e93'}"></span>
          <b class="sc-music-title">${esc(station.title)}</b>
          <span class="dim">· Ambient Stream</span>
        </div>
        <button class="sc-music-play-btn" data-action="music-toggle" style="background:${isPlaying ? '#3b82f6' : 'rgba(255,255,255,0.1)'};color:#fff">
          ${isPlaying ? '⏹ Pause' : '▶ Play'}
        </button>
      </div>
      <div class="sc-music-stations-row">
        ${stationPills}
      </div>
    </div>
  `;
}

export function dayProgressHtml(color: string): string {
  const snap = dayProgress.getSnapshot();
  const cfg = dayProgress.getConfig();
  const sleepPercent = ((cfg.sleepHour / 24) * 100).toFixed(1);
  const progPercent = (snap.percentPassed * 100).toFixed(1);

  return `
    <div class="sc-dayprog-card" style="border: 1px solid ${snap.isPastSleepTime ? 'rgba(129, 140, 248, 0.4)' : 'rgba(255, 255, 255, 0.08)'}">
      <div class="sc-dayprog-head">
        <div class="sc-dayprog-title">
          <span>${esc(snap.currentSection.icon)}</span>
          <b>${esc(snap.currentSection.title.toUpperCase())}</b>
          <span class="dim">· ${esc(snap.currentTimeFormatted)}</span>
        </div>
        <span class="sc-dayprog-pct" style="color:${color}">${progPercent}% DAY</span>
      </div>
      <div class="sc-dayprog-sub">
        <span>${Math.floor(snap.hoursPassedToday)}h ${Math.floor((snap.hoursPassedToday % 1) * 60)}m passed</span>
        <span>·</span>
        <span>${Math.floor(snap.remainingHoursInDay)}h ${Math.floor((snap.remainingHoursInDay % 1) * 60)}m left</span>
        <span class="sc-dayprog-night-tag" style="margin-left:auto">${snap.isPastSleepTime ? '🌙 Nighttime' : '🌙 Bedtime ' + esc(snap.sleepTimeFormatted)}</span>
      </div>
      <div class="sc-dayprog-bar-wrap">
        <div class="sc-dayprog-bar-track">
          <div class="sc-dayprog-bar-night-zone" style="left:${sleepPercent}%"></div>
          <div class="sc-dayprog-bar-fill ${snap.isPastSleepTime ? 'night-fill' : ''}" style="width:${progPercent}%;background:${color}"></div>
          <div class="sc-dayprog-bar-line" style="left:${sleepPercent}%" title="Sleep Time: ${esc(snap.sleepTimeFormatted)}"></div>
        </div>
      </div>
      <div class="sc-dayprog-legend">
        <span>0h</span>
        <span>🌅 ${esc(snap.wakeTimeFormatted)}</span>
        <span style="color:#a5b4fc">🌙 ${esc(snap.sleepTimeFormatted)}</span>
        <span>24h</span>
      </div>
    </div>
  `;
}

/// Everything below the sprite thumbnail. The thumbnail is a canvas the caller
/// draws into (`#sc-thumb`), so the HTML stays pure.
export function cardHtml(inp: CardInput): string {
  const s = inp.state, now = inp.now ?? Date.now();
  const internal = care.levelForXP(s.xp);
  const level = care.displayLevel(s.xp);
  const stage = care.stageIndex(internal);
  const color = STAGE_COLORS[Math.min(stage, STAGE_COLORS.length - 1)];
  const progress = care.levelProgress(s.xp);
  const { inLevel, span } = xpWithinLevel(s.xp);
  const full = fullness(s, now);
  const fullColor = full > 0.5 ? "#30d158" : full > 0.25 ? "#ff9f0a" : "#ff453a";
  const hunger = care.hunger(s, new Date(now));
  const unlocked = new Set(s.unlockedAchievements || []);
  const days = care.recentDays(s, 7, new Date(now));
  const peak = Math.max(1, ...days.map((d) => d.tokens));
  const todayFocus = s.focusSecondsToday ? ` · ${care.formattedFocus(s.focusSecondsToday)} focus` : "";
  const meals = (s.mealsToday === 1 ? t("1 meal") : t("%d meals").replace("%d", String(s.mealsToday))) + todayFocus;
  const lifetimeSub = s.totalFocusSeconds ? `${care.formattedFocus(s.totalFocusSeconds)} focus` : t("tokens eaten");
  const focusMins = Math.max(0, span - inLevel);
  const focusHelp = focusMins >= 60 ? ` (or ${(focusMins / 60).toFixed(1)}h focus)` : ` (or ${focusMins}m focus)`;
  const money = (v: number) => `$${v.toFixed(2)}`;
  const nf = new Intl.NumberFormat();

  const cell = (label: string, value: string, sub: string) =>
    `<div class="sc-cell"><div class="sc-cl">${esc(t(label).toUpperCase())}</div>` +
    `<div class="sc-cv">${esc(value)}</div><div class="sc-cs">${esc(sub)}</div></div>`;

  const badges = care.ACHIEVEMENTS.map((a) =>
    `<span class="sc-badge${unlocked.has(a) ? " on" : ""}" data-ach="${a}" style="${unlocked.has(a) ? `color:${color}` : ""}">${care.ACH_ICON[a]}</span>`).join("");

  const bars = days.map((d, i) =>
    `<div class="sc-bw" title="${esc(tokenString(d.tokens))}"><div class="sc-bar" style="height:${Math.max(3, Math.round((d.tokens / peak) * 34))}px;background:${color};opacity:${i === days.length - 1 ? 1 : 0.4}"></div><div class="sc-bl">${esc(d.label)}</div></div>`).join("");

  const agentRows = (inp.agents || []).slice(0, 6);
  const agentsHtml = agentRows.length
    ? `<div class="sc-sec"><span>${esc(t("By agent"))}</span><b>${esc(t("Today · Month"))}</b></div>` +
      agentRows.map((a) =>
        `<div class="sc-last"><span>${esc(agentLabel(a.agent))}</span><span>${esc(tokenString(a.today))} · ${esc(tokenString(a.month))}</span></div>`).join("")
    : "";
  const shown = limits.visible(inp.providers);
  const limitsHtml = shown.length
    ? `<div class="sc-sec"><span>${esc(t("Limits"))}</span></div>` +
      shown.map((p) => `<div class="sc-prov"><div class="sc-pname">${esc(p.display_name)}</div>${limits.windowRowsHtml(p, true)}</div>`).join("")
    : "";

  const personalizedHtml = (inp.showPersonalized !== false)
    ? `
      ${dueAlertHtml()}
      ${dayProgressHtml(color)}
      ${primaryTargetHtml(color)}
      ${quoteStripHtml(color)}
    `
    : "";

  const isPomoRunning = pomo.loadState().phase !== "idle";
  const pomoAboveAgentsHtml = (isPomoRunning || inp.showPersonalized !== false)
    ? pomoAndWorkHtml(color)
    : "";

  return `
  <div class="sc-head">
    <div class="sc-thumbwrap" style="background:${color}24"><canvas id="sc-thumb" width="46" height="46"></canvas></div>
    <div class="sc-id">
      <div class="sc-name">${esc(inp.name)}</div>
      <div class="sc-lvrow"><b style="color:${color}">Lv ${level}</b>
        <span class="sc-stage" style="color:${color};background:${color}33">${esc(t(care.stageName(internal)))}</span></div>
    </div>
    <div class="sc-hunger"><div>${esc(t(HUNGER_LABEL[hunger]))}</div>
      <div class="sc-fbar"><div style="width:${Math.round(full * 100)}%;background:${fullColor}"></div></div></div>
  </div>
  <div class="sc-xp">
    <div class="sc-pbar"><div style="width:${(progress * 100).toFixed(1)}%;background:${color}"></div></div>
    <div class="sc-xprow"><span>${nf.format(inLevel)} / ${nf.format(span)} XP</span><b style="color:${color}">${Math.round(progress * 100)}%</b></div>
    <div class="sc-next" style="color:${color}">${esc(t("≈ %@ tokens to Lv %d").replace("%@", tokenString(care.tokensToNextLevel(s))).replace("%d", String(level + 1)))} (${esc(focusHelp)})</div>
  </div>
  ${personalizedHtml}
  <div class="sc-sec"><span>${esc(t("Achievements"))}</span><b>${unlocked.size} / ${care.ACHIEVEMENTS.length}</b></div>
  <div class="sc-badges">${badges}</div>
  <div class="sc-hint" id="sc-hint">${esc(t("Hover a badge to see how to unlock it"))}</div>
  <div class="sc-grid">
    ${cell("Today", tokenString(s.tokensToday), meals)}
    ${cell("Streak", String(s.streakDays), t("days fed"))}
    ${cell("Lifetime", tokenString(s.totalTokens), lifetimeSub)}
    ${cell("Sessions", String(s.totalMeals), t("completed"))}
  </div>
  <div class="sc-sec"><span>${esc(t("Burn, last 7 days"))}</span><b>${esc(tokenString(days.reduce((a, d) => a + d.tokens, 0)))}</b></div>
  <div class="sc-chart">${bars}</div>
  <div class="sc-sec"><span>${esc(t("Est. cost (Claude)"))}</span><b>${esc(t("Today %@ · Month %@").replace("%@", money(inp.costToday)).replace("%@", money(inp.costMonth)))}</b></div>
  ${pomoAboveAgentsHtml}
  ${focusMusicHtml(color)}
  ${agentsHtml}
  ${limitsHtml}
  ${s.lastFedAt != null ? `<div class="sc-last"><span>${esc(t("Last fed"))}</span><span>${esc(relativeAgo(s.lastFedAt, now, inp.lang))}</span></div>` : ""}`;
}

/// Text for the hovered badge (mac achievementHint).
export function hintText(ach: string, unlocked: boolean): string {
  return `${unlocked ? "✓" : "🔒"} ${t(care.ACH_NAME[ach] || ach)} · ${t(ACH_HINT[ach] || "")}`;
}

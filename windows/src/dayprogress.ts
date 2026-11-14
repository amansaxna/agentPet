// windows/src/dayprogress.ts
// 24-Hour Day Progress & Hourly Chime Engine

export interface DaySection {
  id: string;
  title: string;
  startHour: number;
  endHour: number;
  icon: string;
  colorHex: string;
  isNight: boolean;
}

export interface DayProgressConfig {
  enabled: boolean;
  hourlyNotificationEnabled: boolean;
  sleepHour: number;
  wakeHour: number;
  autoDismissSeconds: number;
}

export interface DayProgressSnapshot {
  currentTimeFormatted: string;
  hoursPassedToday: number;
  percentPassed: number;
  remainingHoursInDay: number;
  hoursUntilSleep: number;
  isPastSleepTime: boolean;
  sleepTimeFormatted: string;
  wakeTimeFormatted: string;
  currentSection: DaySection;
}

const DEFAULT_CONFIG: DayProgressConfig = {
  enabled: true,
  hourlyNotificationEnabled: true,
  sleepHour: 23, // 11:00 PM
  wakeHour: 7,   // 7:00 AM
  autoDismissSeconds: 16,
};

class DayProgressService {
  private config: DayProgressConfig = { ...DEFAULT_CONFIG };
  private isChimeVisible = false;

  constructor() {
    try {
      const saved = localStorage.getItem("ap_day_progress_config");
      if (saved) {
        this.config = { ...DEFAULT_CONFIG, ...JSON.parse(saved) };
      }
    } catch {}
  }

  getConfig(): DayProgressConfig {
    return { ...this.config };
  }

  setSleepHour(hour: number) {
    this.config.sleepHour = Math.max(0, Math.min(23, hour));
    this.save();
  }

  setWakeHour(hour: number) {
    this.config.wakeHour = Math.max(0, Math.min(23, hour));
    this.save();
  }

  getChimeVisible(): boolean {
    return this.isChimeVisible;
  }

  showChime() {
    this.isChimeVisible = true;
  }

  dismiss() {
    this.isChimeVisible = false;
  }

  private save() {
    try {
      localStorage.setItem("ap_day_progress_config", JSON.stringify(this.config));
    } catch {}
  }

  getSnapshot(now: Date = new Date()): DayProgressSnapshot {
    const h = now.getHours();
    const m = now.getMinutes();
    const s = now.getSeconds();

    const totalHours = h + m / 60 + s / 3600;
    const percentPassed = Math.max(0, Math.min(1, totalHours / 24));
    const remainingHoursInDay = Math.max(0, 24 - totalHours);

    const sleepH = this.config.sleepHour;
    const isPastSleep = totalHours >= sleepH || totalHours < this.config.wakeHour;
    const hoursUntilSleep = totalHours < sleepH ? sleepH - totalHours : 0;

    const formatHour = (hr: number) => {
      const ampm = hr >= 12 && hr < 24 ? "PM" : "AM";
      const displayH = hr % 12 === 0 ? 12 : hr % 12;
      return `${displayH}:00 ${ampm}`;
    };

    const currentAmPm = h >= 12 && h < 24 ? "PM" : "AM";
    const currentH12 = h % 12 === 0 ? 12 : h % 12;
    const currentTimeFormatted = `${currentH12}:${String(m).padStart(2, "0")} ${currentAmPm}`;

    let sec: DaySection;
    if (isPastSleep) {
      sec = { id: "night", title: "Night & Sleep", startHour: sleepH, endHour: this.config.wakeHour, icon: "🌙", colorHex: "#818cf8", isNight: true };
    } else if (totalHours < 12) {
      sec = { id: "morning", title: "Morning", startHour: this.config.wakeHour, endHour: 12, icon: "☀️", colorHex: "#fbbf24", isNight: false };
    } else if (totalHours < 18) {
      sec = { id: "focus", title: "Focus Work", startHour: 12, endHour: 18, icon: "⚡", colorHex: "#38bdf8", isNight: false };
    } else {
      sec = { id: "evening", title: "Evening", startHour: 18, endHour: sleepH, icon: "🌆", colorHex: "#c084fc", isNight: false };
    }

    return {
      currentTimeFormatted,
      hoursPassedToday: totalHours,
      percentPassed,
      remainingHoursInDay,
      hoursUntilSleep,
      isPastSleepTime: isPastSleep,
      sleepTimeFormatted: formatHour(sleepH),
      wakeTimeFormatted: formatHour(this.config.wakeHour),
      currentSection: sec,
    };
  }
}

export const dayProgress = new DayProgressService();

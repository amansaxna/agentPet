// Sources/AgentPetCore/DayProgressEngine.swift
import Foundation
import SwiftUI

/// A configurable section of the 24-hour day (e.g. Morning, Deep Work, Evening, Night/Sleep).
public struct DaySection: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var startHour: Double // 0.0 to 24.0
    public var endHour: Double   // 0.0 to 24.0
    public var icon: String      // SF Symbol
    public var colorHex: String
    public var isNight: Bool

    public init(id: String, title: String, startHour: Double, endHour: Double, icon: String, colorHex: String, isNight: Bool = false) {
        self.id = id
        self.title = title
        self.startHour = startHour
        self.endHour = endHour
        self.icon = icon
        self.colorHex = colorHex
        self.isNight = isNight
    }

    public var spanHours: Double {
        if endHour >= startHour {
            return endHour - startHour
        } else {
            return (24.0 - startHour) + endHour
        }
    }
}

/// User configuration for Day Progress & Hourly Chime.
public struct DayProgressConfig: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var hourlyNotificationEnabled: Bool
    public var sleepHour: Int // Default: 23 (11:00 PM)
    public var wakeHour: Int  // Default: 7  (7:00 AM)
    public var autoDismissSeconds: Int // Default: 16 (0 = manual dismiss only)
    public var sections: [DaySection]

    public init(
        enabled: Bool = true,
        hourlyNotificationEnabled: Bool = true,
        sleepHour: Int = 23,
        wakeHour: Int = 7,
        autoDismissSeconds: Int = 16,
        sections: [DaySection]? = nil
    ) {
        self.enabled = enabled
        self.hourlyNotificationEnabled = hourlyNotificationEnabled
        self.sleepHour = max(0, min(23, sleepHour))
        self.wakeHour = max(0, min(23, wakeHour))
        self.autoDismissSeconds = autoDismissSeconds
        self.sections = sections ?? Self.defaultSections(wakeHour: wakeHour, sleepHour: sleepHour)
    }

    public static func defaultSections(wakeHour: Int = 7, sleepHour: Int = 23) -> [DaySection] {
        let wake = Double(wakeHour)
        let sleep = Double(sleepHour)
        let workStart = max(wake, 9.0)
        let eveningStart = max(workStart, 18.0)

        return [
            DaySection(id: "morning", title: "Morning", startHour: wake, endHour: workStart, icon: "sun.horizon.fill", colorHex: "#FF9F0A"),
            DaySection(id: "focus", title: "Focus Work", startHour: workStart, endHour: eveningStart, icon: "bolt.fill", colorHex: "#0A84FF"),
            DaySection(id: "evening", title: "Evening", startHour: eveningStart, endHour: sleep, icon: "sunset.fill", colorHex: "#BF5AF2"),
            DaySection(id: "night", title: "Night & Sleep", startHour: sleep, endHour: wake, icon: "moon.stars.fill", colorHex: "#5E5CE6", isNight: true)
        ]
    }
}

/// Live computed snapshot of 24-hour day progress.
public struct DayProgressSnapshot: Equatable, Sendable {
    public let date: Date
    public let currentTimeFormatted: String
    public let hoursPassedToday: Double      // e.g. 22.58
    public let percentPassed: Double          // 0.0 ... 1.0
    public let remainingHoursInDay: Double    // until 24:00
    public let hoursUntilSleep: Double        // positive if before sleep, 0 or negative if past
    public let isPastSleepTime: Bool
    public let currentSection: DaySection
    public let sleepTimeFormatted: String
    public let wakeTimeFormatted: String

    public init(date: Date = Date(), config: DayProgressConfig) {
        let calendar = Calendar.current
        self.date = date

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)

        let totalHours = Double(hour) + (Double(minute) / 60.0) + (Double(second) / 3600.0)
        self.hoursPassedToday = totalHours
        self.percentPassed = max(0.0, min(1.0, totalHours / 24.0))
        self.remainingHoursInDay = max(0.0, 24.0 - totalHours)

        let sleepH = Double(config.sleepHour)
        let isPastSleep = totalHours >= sleepH || totalHours < Double(config.wakeHour)
        self.isPastSleepTime = isPastSleep

        if totalHours < sleepH {
            self.hoursUntilSleep = sleepH - totalHours
        } else {
            self.hoursUntilSleep = 0
        }

        // Format current time
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        self.currentTimeFormatted = formatter.string(from: date)

        // Format sleep and wake times
        let sleepDate = calendar.date(bySettingHour: config.sleepHour, minute: 0, second: 0, of: date) ?? date
        let wakeDate = calendar.date(bySettingHour: config.wakeHour, minute: 0, second: 0, of: date) ?? date
        self.sleepTimeFormatted = formatter.string(from: sleepDate)
        self.wakeTimeFormatted = formatter.string(from: wakeDate)

        // Find active section
        let matched = config.sections.first { sec in
            if sec.startHour <= sec.endHour {
                return totalHours >= sec.startHour && totalHours < sec.endHour
            } else {
                // Wraps across midnight (e.g. 23:00 to 07:00)
                return totalHours >= sec.startHour || totalHours < sec.endHour
            }
        }
        self.currentSection = matched ?? DaySection(
            id: "day",
            title: isPastSleep ? "Nighttime" : "Daytime",
            startHour: 0,
            endHour: 24,
            icon: isPastSleep ? "moon.stars.fill" : "sun.max.fill",
            colorHex: isPastSleep ? "#5E5CE6" : "#0A84FF",
            isNight: isPastSleep
        )
    }

    public var hoursPassedFormatted: String {
        let h = Int(hoursPassedToday)
        let m = Int((hoursPassedToday - Double(h)) * 60)
        return "\(h)h \(m)m"
    }

    public var remainingFormatted: String {
        let h = Int(remainingHoursInDay)
        let m = Int((remainingHoursInDay - Double(h)) * 60)
        return "\(h)h \(m)m"
    }

    public var untilSleepFormatted: String {
        if isPastSleepTime {
            return "Nighttime"
        }
        let h = Int(hoursUntilSleep)
        let m = Int((hoursUntilSleep - Double(h)) * 60)
        if h > 0 {
            return "\(h)h \(m)m until sleep"
        } else {
            return "\(m)m until sleep"
        }
    }
}

extension Color {
    public init(hex: String) {
        let hexClean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexClean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexClean.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

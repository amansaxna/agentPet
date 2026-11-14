// Sources/App/WorkAnalysisView.swift
import SwiftUI
import AgentPetCore

/// Comprehensive Work & Study Time Analytics Dashboard.
struct WorkAnalysisView: View {
    @ObservedObject private var work = WorkTrackerController.shared
    @State private var selectedPeriod: WorkAnalysisPeriod = .today

    private var activeReport: WorkAnalyticsReport? {
        switch selectedPeriod {
        case .today: return work.todayReport
        case .week: return work.weekReport
        case .month: return work.monthReport
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Period Picker
                pickerHeader

                if let rep = activeReport {
                    // KPI Summary Cards
                    kpiCards(report: rep)

                    // Category Breakdown
                    categoryBreakdownCard(report: rep)

                    // Daily Trend Chart
                    dailyTrendCard(report: rep)

                    // Hourly Peak Distribution (24h)
                    hourlyPeakCard(report: rep)
                } else {
                    Text("No work segments recorded yet.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Period Header

    private var pickerHeader: some View {
        HStack {
            EyebrowLabel("WORK TIME & PRODUCTIVITY ANALYSIS")
            Spacer()
            Picker("", selection: $selectedPeriod) {
                ForEach(WorkAnalysisPeriod.allCases, id: \.self) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
    }

    // MARK: - KPI Cards

    private func kpiCards(report: WorkAnalyticsReport) -> some View {
        HStack(spacing: 12) {
            kpiTile(title: "NET FOCUS", value: report.formattedFocusDuration, subtitle: "Merged no-overlap", icon: "timer", color: Theme.accent)
            kpiTile(title: "STREAK", value: "\(report.activeStreakDays) days", subtitle: "Active focus", icon: "flame.fill", color: .orange)
            kpiTile(title: "RATIO", value: String(format: "%.1f : 1", report.focusToBreakRatio), subtitle: "Focus to rest", icon: "scale.3d", color: .green)
            kpiTile(title: "ATTAINMENT", value: "\(Int(report.dailyTargetAttainmentPercent))%", subtitle: "Target goal", icon: "target", color: .cyan)
        }
    }

    private func kpiTile(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.system(size: 9, weight: .bold)).tracking(1.0).foregroundStyle(Theme.muted)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.cardStroke, lineWidth: 1))
    }

    // MARK: - Category Breakdown

    private func categoryBreakdownCard(report: WorkAnalyticsReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel("TIME BY CATEGORY / SUBJECT")

            if report.categoryBreakdown.isEmpty {
                Text("No categorized segments yet.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(report.categoryBreakdown) { cat in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(cat.category)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(cat.formattedDuration) (\(Int(cat.percentage))%)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Theme.muted)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.08))
                                Capsule()
                                    .fill(Theme.accent)
                                    .frame(width: max(4, proxy.size.width * CGFloat(cat.percentage / 100.0)))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .themedCard()
    }

    // MARK: - Daily Trend Card

    private func dailyTrendCard(report: WorkAnalyticsReport) -> some View {
        let points = report.dailyPoints
        let maxMins = max(60.0, points.map { $0.minutes }.max() ?? 60.0)

        return VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel("DAILY WORK TREND")

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(points) { pt in
                    VStack(spacing: 4) {
                        GeometryReader { proxy in
                            let h = CGFloat(pt.minutes / maxMins) * proxy.size.height
                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(pt.minutes >= pt.targetMinutes ? Color.green : Theme.accent)
                                    .frame(height: max(3, h))
                            }
                        }
                        .frame(height: 70)

                        Text(pt.dateKey.suffix(2))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .themedCard()
    }

    // MARK: - Hourly Peak Distribution (24h)

    private func hourlyPeakCard(report: WorkAnalyticsReport) -> some View {
        let dist = report.hourlyPeakDistribution
        let peakIdx = report.peakHourIndex
        let maxVal = max(1, dist.max() ?? 1)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                EyebrowLabel("24-HOUR PEAK PRODUCTIVITY")
                Spacer()
                Text("Peak: \(String(format: "%02d:00", peakIdx))")
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
            }

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { hr in
                    let val = dist[hr]
                    let isPeak = (hr == peakIdx && val > 0)
                    VStack(spacing: 3) {
                        GeometryReader { proxy in
                            let h = CGFloat(Double(val) / Double(maxVal)) * proxy.size.height
                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(isPeak ? Color.yellow : Theme.accent.opacity(val > 0 ? 0.8 : 0.2))
                                    .frame(height: max(2, h))
                            }
                        }
                        .frame(height: 50)

                        if hr % 4 == 0 {
                            Text("\(hr)")
                                .font(.system(size: 8))
                                .foregroundStyle(Theme.muted)
                        } else {
                            Text("")
                                .font(.system(size: 8))
                        }
                    }
                }
            }
        }
        .themedCard()
    }
}

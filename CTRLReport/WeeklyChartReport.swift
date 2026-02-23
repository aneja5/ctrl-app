import DeviceActivity
import SwiftUI

// MARK: - Data Model

struct DailyScreenTime: Identifiable {
    let id: Int          // 0=Mon, 1=Tue, ... 6=Sun
    let dayLabel: String // "M", "T", "W", etc.
    let screenTime: TimeInterval
}

struct WeeklyChartData {
    var dailyTotals: [DailyScreenTime] = []
    var average: TimeInterval = 0
}

// MARK: - Report Scene

struct WeeklyChartReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .weeklyChart

    let content: (WeeklyChartData) -> WeeklyChartView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> WeeklyChartData {
        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

        // Collect screen time per segment (each segment = one day with .daily filter)
        var segmentTotals: [TimeInterval] = []

        for await eachData in data {
            var dayTotal: TimeInterval = 0
            for await activitySegment in eachData.activitySegments {
                for await categoryActivity in activitySegment.categories {
                    for await applicationActivity in categoryActivity.applications {
                        dayTotal += applicationActivity.totalActivityDuration
                    }
                }
            }
            segmentTotals.append(dayTotal)
        }

        // Build daily totals array (always 7 entries, pad with zeros if fewer segments)
        var totals: [DailyScreenTime] = []
        for i in 0..<7 {
            let screenTime = i < segmentTotals.count ? segmentTotals[i] : 0
            totals.append(DailyScreenTime(
                id: i,
                dayLabel: dayLabels[i],
                screenTime: screenTime
            ))
        }

        // Calculate average (only for days with data)
        let activeDays = totals.filter { $0.screenTime > 0 }
        let totalScreenTime = totals.reduce(0) { $0 + $1.screenTime }
        let avg = activeDays.isEmpty ? 0 : totalScreenTime / Double(activeDays.count)

        return WeeklyChartData(dailyTotals: totals, average: avg)
    }
}

// MARK: - View

struct WeeklyChartView: View {
    let data: WeeklyChartData

    private let chartHeight: CGFloat = 150
    private let barWidth: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: ReportSpacing.sm) {
            // Section header + average
            HStack(alignment: .firstTextBaseline) {
                Text("weekly screen time")
                    .font(ReportFonts.sectionHeader)
                    .tracking(2)
                    .foregroundColor(ReportColors.textTertiary)

                Spacer()

                if data.average > 0 {
                    Text("avg \(formatDuration(data.average))/day")
                        .font(ReportFonts.micro)
                        .foregroundColor(ReportColors.textSecondary)
                }
            }
            .padding(.horizontal, 4)

            if data.dailyTotals.allSatisfy({ $0.screenTime == 0 }) {
                emptyState
            } else {
                chartCard
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ReportSpacing.md)
        .padding(.vertical, ReportSpacing.sm)
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        let maxScreenTime = max(data.dailyTotals.map { $0.screenTime }.max() ?? 0, 60)
        let yAxisMax = calculateYAxisMax(maxSeconds: Int(maxScreenTime))

        return VStack(spacing: 6) {
            // Chart area with Y-axis
            HStack(alignment: .top, spacing: 6) {
                // Y-Axis Labels
                VStack(alignment: .trailing, spacing: 0) {
                    Text(formatYAxisLabel(seconds: yAxisMax))
                        .font(ReportFonts.micro)
                        .foregroundColor(ReportColors.textTertiary)

                    Spacer()

                    Text(formatYAxisLabel(seconds: yAxisMax / 2))
                        .font(ReportFonts.micro)
                        .foregroundColor(ReportColors.textTertiary)

                    Spacer()

                    Text("0h")
                        .font(ReportFonts.micro)
                        .foregroundColor(ReportColors.textTertiary)
                }
                .frame(width: 26, height: chartHeight)

                // Bars area
                ZStack(alignment: .bottom) {
                    // Grid lines
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(ReportColors.border.opacity(0.3))
                            .frame(height: 1)

                        Spacer()

                        Rectangle()
                            .fill(ReportColors.border.opacity(0.2))
                            .frame(height: 1)

                        Spacer()

                        Rectangle()
                            .fill(ReportColors.border.opacity(0.3))
                            .frame(height: 1)
                    }
                    .frame(height: chartHeight)

                    // Bar chart
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(data.dailyTotals) { day in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(day.screenTime > 0 ? ReportColors.accent : ReportColors.accent.opacity(0.1))
                                .frame(width: barWidth, height: barHeight(for: day.screenTime, max: yAxisMax))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(height: chartHeight)
            }

            // Day Labels
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 26 + 6) // Match Y-axis width + spacing

                HStack(spacing: 0) {
                    ForEach(data.dailyTotals) { day in
                        Text(day.dayLabel)
                            .font(ReportFonts.micro)
                            .tracking(1)
                            .foregroundColor(ReportColors.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, ReportSpacing.sm)
        .padding(.vertical, ReportSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ReportSpacing.cardRadius)
                .fill(ReportColors.surface1)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ReportSpacing.xs) {
            Text("no screen time data this week")
                .font(ReportFonts.emptyState)
                .foregroundColor(ReportColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ReportSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ReportSpacing.cardRadius)
                .fill(ReportColors.surface1)
        )
    }

    // MARK: - Helpers

    private func calculateYAxisMax(maxSeconds: Int) -> Int {
        let maxHours = Double(maxSeconds) / 3600.0

        if maxHours <= 1   { return 3600 * 2 }
        if maxHours <= 2   { return 3600 * 4 }
        if maxHours <= 3   { return 3600 * 6 }
        if maxHours <= 4   { return 3600 * 8 }
        if maxHours <= 5   { return 3600 * 10 }
        if maxHours <= 6   { return 3600 * 12 }
        if maxHours <= 8   { return 3600 * 16 }
        if maxHours <= 10  { return 3600 * 20 }

        let roundedHours = Int(ceil(maxHours / 2.0) * 2)
        return roundedHours * 3600
    }

    private func formatYAxisLabel(seconds: Int) -> String {
        let hours = seconds / 3600
        return "\(hours)h"
    }

    private func barHeight(for seconds: TimeInterval, max: Int) -> CGFloat {
        guard max > 0 else { return 4 }
        let minHeight: CGFloat = seconds > 0 ? 6 : 0
        let ratio = CGFloat(seconds) / CGFloat(max)
        return Swift.max(ratio * chartHeight, minHeight)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m"
        }
    }
}

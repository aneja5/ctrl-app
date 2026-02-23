import DeviceActivity
import SwiftUI

// MARK: - Data Model

struct DailyStatsData {
    var screenTime: TimeInterval = 0
    var pickups: Int = 0
}

// MARK: - Report Scene

struct DailyStatsReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .dailyStats

    let content: (DailyStatsData) -> DailyStatsView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> DailyStatsData {
        var result = DailyStatsData()

        for await eachData in data {
            for await activitySegment in eachData.activitySegments {
                for await categoryActivity in activitySegment.categories {
                    for await applicationActivity in categoryActivity.applications {
                        result.screenTime += applicationActivity.totalActivityDuration
                        result.pickups += applicationActivity.numberOfPickups
                    }
                }
            }
        }

        return result
    }
}

// MARK: - View

struct DailyStatsView: View {
    let data: DailyStatsData

    var body: some View {
        VStack(alignment: .leading, spacing: ReportSpacing.sm) {
            if data.screenTime == 0 && data.pickups == 0 {
                emptyState
            } else {
                HStack(spacing: ReportSpacing.xs) {
                    statCard(
                        value: formatDuration(data.screenTime),
                        label: "screen time"
                    )
                    statCard(
                        value: "\(data.pickups)",
                        label: "pickups"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ReportSpacing.md)
        .padding(.vertical, ReportSpacing.xs)
    }

    // MARK: - Stat Card

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: ReportSpacing.xs) {
            Text(value)
                .font(ReportFonts.statValue)
                .foregroundColor(ReportColors.textPrimary)
                .monospacedDigit()

            Text(label)
                .font(ReportFonts.statLabel)
                .tracking(1.5)
                .foregroundColor(ReportColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ReportSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ReportSpacing.buttonRadius)
                .fill(ReportColors.surface1)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ReportSpacing.xs) {
            Text("no data for this day")
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

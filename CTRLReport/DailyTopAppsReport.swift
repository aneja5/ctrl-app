import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

// MARK: - Data Model

struct DailyAppUsageData: Identifiable {
    let id = UUID()
    let appName: String
    let duration: TimeInterval
    let token: ApplicationToken?
    let numberOfPickups: Int
}

// MARK: - Report Scene

struct DailyTopAppsReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .dailyTopApps

    let content: ([DailyAppUsageData]) -> DailyTopAppsView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> [DailyAppUsageData] {
        var appDurations: [String: (duration: TimeInterval, token: ApplicationToken?, pickups: Int)] = [:]

        for await eachData in data {
            for await activitySegment in eachData.activitySegments {
                for await categoryActivity in activitySegment.categories {
                    for await applicationActivity in categoryActivity.applications {
                        let appName = applicationActivity.application.localizedDisplayName ?? "Unknown"
                        let token = applicationActivity.application.token
                        let existing = appDurations[appName] ?? (duration: 0, token: token, pickups: 0)

                        appDurations[appName] = (
                            duration: existing.duration + applicationActivity.totalActivityDuration,
                            token: token ?? existing.token,
                            pickups: existing.pickups + applicationActivity.numberOfPickups
                        )
                    }
                }
            }
        }

        // Return all apps sorted by duration (no limit)
        let sorted = appDurations
            .map { DailyAppUsageData(
                appName: $0.key,
                duration: $0.value.duration,
                token: $0.value.token,
                numberOfPickups: $0.value.pickups
            )}
            .sorted { $0.duration > $1.duration }

        return sorted
    }
}

// MARK: - View

struct DailyTopAppsView: View {
    let data: [DailyAppUsageData]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if data.isEmpty {
                emptyState
            } else {
                // App list card — scrollable within fixed height
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(data.enumerated()), id: \.element.id) { index, app in
                            appRow(app: app, rank: index + 1)

                            if index < data.count - 1 {
                                Rectangle()
                                    .fill(ReportColors.border.opacity(0.5))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, ReportSpacing.md)
                            }
                        }
                    }
                }
                .frame(maxHeight: 260) // ~5 rows visible, scroll for more
                .background(
                    RoundedRectangle(cornerRadius: ReportSpacing.cardRadius)
                        .fill(ReportColors.surface1)
                )
                .clipShape(RoundedRectangle(cornerRadius: ReportSpacing.cardRadius))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ReportSpacing.md)
        .padding(.top, ReportSpacing.sm)
        .padding(.bottom, ReportSpacing.xs)
    }

    // MARK: - App Row

    private func appRow(app: DailyAppUsageData, rank: Int) -> some View {
        HStack(spacing: ReportSpacing.sm) {
            // Rank number
            Text("\(rank)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(ReportColors.textTertiary)
                .frame(width: 20)

            // App icon via token
            if let token = app.token {
                Label(token)
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
                    .scaleEffect(0.8)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(ReportColors.surface2)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "app.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ReportColors.textTertiary)
                    )
            }

            // App name
            Text(app.appName.lowercased())
                .font(ReportFonts.appName)
                .foregroundColor(ReportColors.textPrimary)
                .lineLimit(1)

            Spacer()

            // Duration
            Text(formatDuration(app.duration))
                .font(ReportFonts.appDuration)
                .foregroundColor(ReportColors.textSecondary)
        }
        .padding(.horizontal, ReportSpacing.md)
        .padding(.vertical, ReportSpacing.sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ReportSpacing.xs) {
            Image(systemName: "apps.iphone")
                .font(.system(size: 24))
                .foregroundColor(ReportColors.textTertiary.opacity(0.5))

            Text("no app usage data")
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
        } else if totalSeconds > 0 {
            return "<1m"
        } else {
            return "0m"
        }
    }
}

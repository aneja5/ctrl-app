import DeviceActivity
import SwiftUI

@main
struct CTRLReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        DailyStatsReport { data in
            DailyStatsView(data: data)
        }

        DailyTopAppsReport { data in
            DailyTopAppsView(data: data)
        }

        WeeklyChartReport { data in
            WeeklyChartView(data: data)
        }
    }
}

// MARK: - Report Contexts

extension DeviceActivityReport.Context {
    static let dailyStats = Self("dailyStats")
    static let dailyTopApps = Self("dailyTopApps")
    static let weeklyChart = Self("weeklyChart")
}

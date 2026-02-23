import SwiftUI

struct LifetimeStatsView: View {
    @EnvironmentObject var appState: AppState
    @State private var refreshTick: Int = 0

    var body: some View {
        VStack(spacing: CTRLSpacing.lg) {
            // Lifetime Hero
            lifetimeHero

            // Stat Cards
            statCards

            // Avg Per Week
            avgPerWeekCard

            // Monthly Summary
            monthlySummarySection
                .padding(.top, CTRLSpacing.sm)
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            if appState.isInSession {
                refreshTick += 1
            }
        }
    }

    // MARK: - Lifetime Hero (subtle gradient)

    private var lifetimeHero: some View {
        let _ = refreshTick // Force SwiftUI re-evaluation during active sessions
        let totalHours = appState.totalLifetimeSeconds / 3600.0
        let displayHours = Int(totalHours)

        return VStack(spacing: CTRLSpacing.sm) {
            Text("\(displayHours)")
                .font(.system(size: displayHours == 0 ? 48 : 64, weight: .ultraLight, design: .default))
                .foregroundColor(displayHours == 0 ? Color.white.opacity(0.3) : CTRLColors.textPrimary)
                .monospacedDigit()

            Text("hours reclaimed")
                .font(CTRLFonts.captionFont)
                .tracking(2)
                .foregroundColor(CTRLColors.textTertiary)

            Text(milestoneText(hours: totalHours))
                .font(CTRLFonts.bodySmall)
                .foregroundColor(CTRLColors.textSecondary)
                .padding(.top, CTRLSpacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CTRLSpacing.xl)
        .padding(.horizontal, CTRLSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CTRLSpacing.cardRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            CTRLColors.surface1,
                            CTRLColors.surface2.opacity(0.5)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }

    private func milestoneText(hours: Double) -> String {
        if hours < 1 {
            return "your journey begins"
        } else if hours < 10 {
            return "every hour counts"
        } else if hours < 50 {
            return "building a real habit"
        } else if hours < 100 {
            return "over fifty hours reclaimed"
        } else {
            return "a hundred hours of intentional focus"
        }
    }

    // MARK: - Stat Cards

    private var statCards: some View {
        HStack(spacing: CTRLSpacing.sm) {
            statCard(
                value: "\(appState.totalDaysFocused)",
                label: "days focused",
                isZero: appState.totalDaysFocused == 0
            )
            statCard(
                value: "\(appState.totalLifetimeSessions)",
                label: "sessions",
                isZero: appState.totalLifetimeSessions == 0
            )
        }
    }

    private func statCard(value: String, label: String, isZero: Bool = false) -> some View {
        SurfaceCard(padding: CTRLSpacing.cardPadding, cornerRadius: CTRLSpacing.buttonRadius) {
            VStack(spacing: CTRLSpacing.xs) {
                Text(value)
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(isZero ? CTRLColors.textPrimary.opacity(0.3) : CTRLColors.textPrimary)
                    .monospacedDigit()

                Text(label)
                    .font(CTRLFonts.captionFont)
                    .tracking(1.5)
                    .foregroundColor(CTRLColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Avg Per Week

    private var avgPerWeekCard: some View {
        let avgWeeklySeconds = calculateAvgWeeklySeconds()
        let isZero = avgWeeklySeconds == 0

        return SurfaceCard(padding: CTRLSpacing.cardPadding, cornerRadius: CTRLSpacing.buttonRadius) {
            VStack(spacing: CTRLSpacing.xs) {
                Text(StatsChartHelpers.formatDuration(avgWeeklySeconds))
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(isZero ? CTRLColors.textPrimary.opacity(0.3) : CTRLColors.textPrimary)
                    .monospacedDigit()

                Text("avg per week")
                    .font(CTRLFonts.captionFont)
                    .tracking(1.5)
                    .foregroundColor(CTRLColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func calculateAvgWeeklySeconds() -> Int {
        let totalSeconds = Int(appState.totalLifetimeSeconds)
        guard totalSeconds > 0 else { return 0 }

        let calendar = CalendarHelper.mondayFirst
        let today = Date()

        // Find earliest entry date
        let earliestDate: Date? = appState.focusHistory
            .compactMap { $0.dateValue() }
            .min()

        guard let startDate = earliestDate else { return 0 }

        // Calculate weeks between first entry and today (minimum 1)
        let daysBetween = max(calendar.dateComponents([.day], from: startDate, to: today).day ?? 1, 1)
        let weeks = max(Double(daysBetween) / 7.0, 1.0)

        return Int(Double(totalSeconds) / weeks)
    }

    // MARK: - Monthly Summary

    private var monthlySummarySection: some View {
        let months = buildMonthlyData()
        let hasAnyData = months.contains { $0.totalSeconds > 0 }

        return VStack(spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "monthly summary")

            if hasAnyData {
                VStack(spacing: CTRLSpacing.xs) {
                    ForEach(months) { month in
                        monthlySummaryRow(month: month)
                    }
                }
            } else {
                Text("no sessions yet")
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CTRLSpacing.lg)
            }
        }
    }

    private func monthlySummaryRow(month: MonthSummary) -> some View {
        let hasData = month.totalSeconds > 0

        return SurfaceCard(padding: CTRLSpacing.sm + 4, cornerRadius: CTRLSpacing.buttonRadius) {
            HStack {
                Text(month.label)
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(hasData ? CTRLColors.textSecondary : Color.white.opacity(0.3))

                Spacer()

                Text(StatsChartHelpers.formatDuration(Int(month.totalSeconds)))
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(hasData ? CTRLColors.textPrimary : Color.white.opacity(0.3))
                    .monospacedDigit()

                Text("·")
                    .foregroundColor(CTRLColors.textTertiary)
                    .font(.system(size: 12))

                Text("\(month.sessionCount) \(month.sessionCount == 1 ? "session" : "sessions")")
                    .font(CTRLFonts.micro)
                    .foregroundColor(hasData ? CTRLColors.textTertiary : Color.white.opacity(0.3))
            }
        }
    }

    // MARK: - Data

    private struct MonthSummary: Identifiable {
        let id: String // "yyyy-MM"
        let label: String // "feb 2026"
        let totalSeconds: TimeInterval
        let sessionCount: Int
    }

    private func buildMonthlyData() -> [MonthSummary] {
        let _ = refreshTick // Force SwiftUI re-evaluation during active sessions
        let calendar = Calendar.current
        let today = Date()

        // Find earliest month from focus history, or use current month
        let earliestDate: Date? = appState.focusHistory
            .compactMap { $0.dateValue() }
            .min()

        // Start from earliest month, or current month if no history
        let startDate = earliestDate ?? today

        // Calculate months between start and now
        let startComponents = calendar.dateComponents([.year, .month], from: startDate)
        let endComponents = calendar.dateComponents([.year, .month], from: today)

        guard let startMonth = calendar.date(from: startComponents),
              let endMonth = calendar.date(from: endComponents) else { return [] }

        let monthDiff = calendar.dateComponents([.month], from: startMonth, to: endMonth).month ?? 0
        let monthCount = min(max(monthDiff + 1, 1), 6) // 1-6 months

        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "MMM yyyy"

        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM"

        var months: [MonthSummary] = []

        for offset in 0..<monthCount {
            guard let monthDate = calendar.date(byAdding: .month, value: -offset, to: endMonth) else { continue }

            let monthComponents = calendar.dateComponents([.year, .month], from: monthDate)

            // Filter focus history entries for this month
            let entriesInMonth = appState.focusHistory.filter { entry in
                guard let entryDate = entry.dateValue() else { return false }
                let entryComponents = calendar.dateComponents([.year, .month], from: entryDate)
                return entryComponents.year == monthComponents.year && entryComponents.month == monthComponents.month
            }

            // Sum totals
            var totalSeconds = entriesInMonth.reduce(0.0) { $0 + $1.totalSeconds }
            let sessionCount = entriesInMonth.reduce(0) { $0 + $1.sessionCount }

            // Include today's live seconds if this is the current month
            let todayComponents = calendar.dateComponents([.year, .month], from: today)
            if monthComponents.year == todayComponents.year && monthComponents.month == todayComponents.month {
                let todayKey = DailyFocusEntry.todayKey()
                let todayInHistory = entriesInMonth.first { $0.date == todayKey }
                if todayInHistory != nil {
                    // Replace history value with live value
                    totalSeconds = totalSeconds - (todayInHistory?.totalSeconds ?? 0) + appState.todayFocusSeconds
                } else {
                    totalSeconds += appState.todayFocusSeconds
                }
            }

            guard let monthStart = calendar.date(from: monthComponents) else { continue }

            months.append(MonthSummary(
                id: keyFormatter.string(from: monthStart),
                label: labelFormatter.string(from: monthStart).lowercased(),
                totalSeconds: totalSeconds,
                sessionCount: sessionCount
            ))
        }

        return months // Most recent first (offset 0 = current month)
    }
}

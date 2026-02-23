import SwiftUI

struct LifetimeStatsView: View {
    @EnvironmentObject var appState: AppState
    @State private var refreshTick: Int = 0

    var body: some View {
        let isEmpty = appState.totalLifetimeSeconds <= 0

        VStack(spacing: CTRLSpacing.lg) {
            if isEmpty {
                // Empty state
                emptyLifetimeHero
                emptyLifetimePrompt
            } else {
                // Full dashboard
                lifetimeHero
                streakCards
                compactStatsRow
                personalRecordsCard
                monthlySummarySection
                    .padding(.top, CTRLSpacing.sm)
            }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            if appState.isInSession {
                refreshTick += 1
            }
        }
    }

    // MARK: - Empty State

    private var emptyLifetimeHero: some View {
        VStack(spacing: CTRLSpacing.sm) {
            Text("0")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(Color.white.opacity(0.2))
                .monospacedDigit()

            Text("hours reclaimed")
                .font(CTRLFonts.captionFont)
                .tracking(2)
                .foregroundColor(Color.white.opacity(0.3))

            Text("every hour counts")
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

    private var emptyLifetimePrompt: some View {
        Text("complete your first session to start tracking")
            .font(.system(size: 13))
            .foregroundColor(Color.white.opacity(0.3))
            .frame(maxWidth: .infinity)
            .padding(.top, CTRLSpacing.xl)
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
        if hours < 5 {
            return "every hour counts"
        } else if hours < 24 {
            return "that's \(Int(hours)) hours back in your life"
        } else if hours < 100 {
            let days = Int(hours / 24)
            return "over \(days > 1 ? "\(days) days" : "a full day") reclaimed"
        } else if hours < 500 {
            let days = Int(hours / 24)
            return "over \(days) days of your life, reclaimed"
        } else {
            let weeks = Int(hours / 168)
            return "you've reclaimed \(weeks) weeks"
        }
    }

    // MARK: - Streak Cards

    private var streakCards: some View {
        HStack(spacing: CTRLSpacing.sm) {
            // Current streak
            SurfaceCard(padding: CTRLSpacing.cardPadding, cornerRadius: CTRLSpacing.buttonRadius) {
                VStack(spacing: CTRLSpacing.xs) {
                    Text("\(appState.currentStreak)")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(appState.currentStreak > 0 ? CTRLColors.accent : Color.white.opacity(0.3))
                        .monospacedDigit()

                    Text("current streak")
                        .font(.system(size: 11))
                        .tracking(1.5)
                        .foregroundColor(Color.white.opacity(0.4))

                    Text(appState.currentStreak > 0 ? "days" : "start today")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.3))

                }
                .frame(maxWidth: .infinity)
            }

            // Longest streak
            SurfaceCard(padding: CTRLSpacing.cardPadding, cornerRadius: CTRLSpacing.buttonRadius) {
                VStack(spacing: CTRLSpacing.xs) {
                    Text("\(appState.longestStreak)")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(CTRLColors.textPrimary)
                        .monospacedDigit()

                    Text("longest streak")
                        .font(.system(size: 11))
                        .tracking(1.5)
                        .foregroundColor(Color.white.opacity(0.4))

                    Text("days")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Compact Stats Row

    private var compactStatsRow: some View {
        let _ = refreshTick
        let avgWeekly = calculateAvgWeeklySeconds()

        return Text("\(appState.totalDaysFocused) days  ·  \(appState.totalLifetimeSessions) sessions  ·  \(StatsChartHelpers.formatDuration(avgWeekly)) avg/week")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Color.white.opacity(0.4))
            .frame(maxWidth: .infinity)
    }

    // MARK: - Personal Records Card

    @ViewBuilder
    private var personalRecordsCard: some View {
        let records = computePersonalRecords()

        if !records.isEmpty {
            VStack(spacing: CTRLSpacing.sm) {
                CTRLSectionHeader(title: "personal records")

                SurfaceCard(padding: CTRLSpacing.cardPadding, cornerRadius: CTRLSpacing.cardRadius) {
                    VStack(spacing: CTRLSpacing.md) {
                        ForEach(records, id: \.label) { record in
                            recordRow(label: record.label, display: record.display)
                        }
                    }
                }
            }
        }
    }

    private struct PersonalRecord {
        let label: String
        let display: String // "1h 42m  ·  sat, feb 21"
    }

    private func computePersonalRecords() -> [PersonalRecord] {
        var records: [PersonalRecord] = []
        let history = appState.focusHistory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, MMM d"
        let weekFormatter = DateFormatter()
        weekFormatter.dateFormat = "MMM d"

        // Longest session — from persisted record (can't derive from daily totals)
        if appState.longestSessionSeconds > 0 {
            let value = StatsChartHelpers.formatDuration(appState.longestSessionSeconds)
            if let date = appState.longestSessionDate {
                records.append(PersonalRecord(
                    label: "longest session",
                    display: "\(value)  ·  \(dateFormatter.string(from: date).lowercased())"
                ))
            } else {
                records.append(PersonalRecord(label: "longest session", display: value))
            }
        }

        // Best day — computed from focusHistory (need 2+ days with data)
        let daysWithData = history.filter { $0.totalSeconds > 0 }
        if daysWithData.count >= 2,
           let bestDay = daysWithData.max(by: { $0.totalSeconds < $1.totalSeconds }),
           let bestDayDate = bestDay.dateValue() {
            let value = StatsChartHelpers.formatDuration(Int(bestDay.totalSeconds))
            records.append(PersonalRecord(
                label: "best day",
                display: "\(value)  ·  \(dateFormatter.string(from: bestDayDate).lowercased())"
            ))
        }

        // Best week — computed from focusHistory (need at least 1 full week of data)
        if let (weekTotal, weekStart) = computeBestWeek(), weekTotal > 0 {
            let value = StatsChartHelpers.formatDuration(weekTotal)
            let end = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let dateLabel = "\(weekFormatter.string(from: weekStart).lowercased())–\(weekFormatter.string(from: end).lowercased())"
            records.append(PersonalRecord(
                label: "best week",
                display: "\(value)  ·  \(dateLabel)"
            ))
        }

        return records
    }

    /// Finds the Mon–Sun week with the highest total focus time.
    /// Returns nil if there isn't at least 1 complete week of data.
    private func computeBestWeek() -> (Int, Date)? {
        let calendar = CalendarHelper.mondayFirst
        let history = appState.focusHistory
        guard !history.isEmpty else { return nil }

        let dates = history.compactMap { $0.dateValue() }
        guard let earliest = dates.min(), let latest = dates.max() else { return nil }

        // Need at least 7 days span
        let span = calendar.dateComponents([.day], from: earliest, to: latest).day ?? 0
        guard span >= 6 else { return nil }

        // Get the Monday of the earliest date
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: earliest)
        components.weekday = 2
        guard var weekStart = calendar.date(from: components) else { return nil }

        let today = Date()
        var bestTotal = 0
        var bestStart: Date = weekStart

        while weekStart <= today {
            var weekTotal = 0
            for i in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: i, to: weekStart) else { continue }
                let key = DailyFocusEntry.dateFormatter.string(from: day)
                if let entry = history.first(where: { $0.date == key }) {
                    weekTotal += Int(entry.totalSeconds)
                }
            }
            if weekTotal > bestTotal {
                bestTotal = weekTotal
                bestStart = weekStart
            }
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
            weekStart = next
        }

        return bestTotal > 0 ? (bestTotal, bestStart) : nil
    }

    private func recordRow(label: String, display: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.4))

            Spacer()

            Text(display)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.7))
                .monospacedDigit()
        }
    }

    // MARK: - Avg Per Week (helper)

    private func calculateAvgWeeklySeconds() -> Int {
        let totalSeconds = Int(appState.totalLifetimeSeconds)
        guard totalSeconds > 0 else { return 0 }

        let calendar = CalendarHelper.mondayFirst
        let today = Date()

        let earliestDate: Date? = appState.focusHistory
            .compactMap { $0.dateValue() }
            .min()

        guard let startDate = earliestDate else { return 0 }

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

        let earliestDate: Date? = appState.focusHistory
            .compactMap { $0.dateValue() }
            .min()

        let startDate = earliestDate ?? today

        let startComponents = calendar.dateComponents([.year, .month], from: startDate)
        let endComponents = calendar.dateComponents([.year, .month], from: today)

        guard let startMonth = calendar.date(from: startComponents),
              let endMonth = calendar.date(from: endComponents) else { return [] }

        let monthDiff = calendar.dateComponents([.month], from: startMonth, to: endMonth).month ?? 0
        let monthCount = min(max(monthDiff + 1, 1), 6)

        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "MMM yyyy"

        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM"

        var months: [MonthSummary] = []

        for offset in 0..<monthCount {
            guard let monthDate = calendar.date(byAdding: .month, value: -offset, to: endMonth) else { continue }

            let monthComponents = calendar.dateComponents([.year, .month], from: monthDate)

            let entriesInMonth = appState.focusHistory.filter { entry in
                guard let entryDate = entry.dateValue() else { return false }
                let entryComponents = calendar.dateComponents([.year, .month], from: entryDate)
                return entryComponents.year == monthComponents.year && entryComponents.month == monthComponents.month
            }

            var totalSeconds = entriesInMonth.reduce(0.0) { $0 + $1.totalSeconds }
            let sessionCount = entriesInMonth.reduce(0) { $0 + $1.sessionCount }

            let todayComponents = calendar.dateComponents([.year, .month], from: today)
            if monthComponents.year == todayComponents.year && monthComponents.month == todayComponents.month {
                let todayKey = DailyFocusEntry.todayKey()
                let todayInHistory = entriesInMonth.first { $0.date == todayKey }
                if todayInHistory != nil {
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

        return months
    }
}

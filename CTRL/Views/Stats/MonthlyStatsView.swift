import SwiftUI

// MARK: - Month Day Data

private struct MonthDayData: Identifiable {
    let id: Int
    let day: Int
    let seconds: Int
    let date: Date
    let weekday: Int // 1=Sun, 2=Mon, ...7=Sat
}

struct MonthlyStatsView: View {
    @EnvironmentObject var appState: AppState
    @State var selectedMonthOffset: Int = 0
    @State private var refreshTick: Int = 0

    private var maxMonthsBack: Int {
        guard let regDate = appState.registrationDate else { return 0 }
        let months = Calendar.current.dateComponents([.month], from: regDate, to: Date()).month ?? 0
        return max(months, 0)
    }

    var body: some View {
        let totalSeconds = monthData.reduce(0) { $0 + $1.seconds }

        VStack(spacing: CTRLSpacing.lg) {
            // Month Navigation — always shown so users can browse
            monthNavigation

            if totalSeconds > 0 {
                // Full dashboard
                monthHero
                dailyAverageLine
                patternsSection
                    .padding(.top, CTRLSpacing.md)
                monthHeatmap
                    .padding(.top, CTRLSpacing.md)
                bestDayCard
            } else {
                // Empty state
                emptyMonthCard
            }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            if appState.isInSession {
                refreshTick += 1
            }
        }
    }

    // MARK: - Month Navigation

    private var monthNavigation: some View {
        HStack(spacing: CTRLSpacing.xl) {
            Button(action: {
                if selectedMonthOffset > -maxMonthsBack {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedMonthOffset -= 1
                    }
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedMonthOffset > -maxMonthsBack ? CTRLColors.textSecondary : CTRLColors.textTertiary.opacity(0.4))
            }
            .disabled(selectedMonthOffset <= -maxMonthsBack)

            Text(monthLabel)
                .font(CTRLFonts.bodySmall)
                .foregroundColor(CTRLColors.textTertiary)

            Button(action: {
                if selectedMonthOffset < 0 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedMonthOffset += 1
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedMonthOffset < 0 ? CTRLColors.textSecondary : CTRLColors.textTertiary.opacity(0.4))
            }
            .disabled(selectedMonthOffset >= 0)
        }
    }

    private var monthLabel: String {
        let calendar = Calendar.current
        guard let month = calendar.date(byAdding: .month, value: selectedMonthOffset, to: Date()) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: month).lowercased()
    }

    // MARK: - Empty State

    private var emptyMonthCard: some View {
        SurfaceCard(padding: CTRLSpacing.lg, cornerRadius: CTRLSpacing.cardRadius) {
            Text("your first session will show progress here")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.4))
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Month Hero

    private var monthHero: some View {
        let days = monthData
        let totalSeconds = days.reduce(0) { $0 + $1.seconds }
        let activeDays = days.filter { $0.seconds > 0 }.count
        let isEmpty = totalSeconds == 0

        return SurfaceCard(padding: CTRLSpacing.lg, cornerRadius: CTRLSpacing.cardRadius) {
            VStack(spacing: CTRLSpacing.xs) {
                Text(StatsChartHelpers.formatDuration(totalSeconds))
                    .font(.system(size: isEmpty ? 36 : 40, weight: .light, design: .default))
                    .foregroundColor(isEmpty ? Color.white.opacity(0.3) : CTRLColors.textPrimary)
                    .monospacedDigit()

                if isEmpty {
                    Text("your first session will show progress here")
                        .font(CTRLFonts.micro)
                        .foregroundColor(Color.white.opacity(0.4))
                } else {
                    Text("across \(activeDays) \(activeDays == 1 ? "day" : "days")")
                        .font(CTRLFonts.captionFont)
                        .tracking(1.5)
                        .foregroundColor(CTRLColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Daily Average Line

    @ViewBuilder
    private var dailyAverageLine: some View {
        let days = monthData
        let totalSeconds = days.reduce(0) { $0 + $1.seconds }
        let activeDays = days.filter { $0.seconds > 0 }.count
        let avgSeconds = activeDays > 0 ? totalSeconds / activeDays : 0

        if totalSeconds > 0 {
            Text("\(StatsChartHelpers.formatDuration(avgSeconds)) daily average")
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.3))
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Patterns Section (promoted above heatmap)

    private var patternsSection: some View {
        let averages = weekdayAverages

        return VStack(spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "patterns")

            // Insight line
            if let insight = patternsInsight(averages: averages) {
                Text(insight)
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, CTRLSpacing.xs)
            }

            dayOfWeekBars(averages: averages)
        }
    }

    private func patternsInsight(averages: [(name: String, avg: Int)]) -> String? {
        let active = averages.filter { $0.avg > 0 }
        guard active.count >= 3 else { return nil }

        guard let best = averages.max(by: { $0.avg < $1.avg }),
              best.avg > 0 else { return nil }

        let fullNames = ["mon": "mondays", "tue": "tuesdays", "wed": "wednesdays",
                         "thu": "thursdays", "fri": "fridays", "sat": "saturdays", "sun": "sundays"]
        let dayName = fullNames[best.name] ?? best.name

        // Check if weekends dominate
        let weekendAvg = averages[5].avg + averages[6].avg
        let weekdayAvg = averages[0..<5].reduce(0) { $0 + $1.avg }
        if weekendAvg > weekdayAvg && averages[5].avg > 0 && averages[6].avg > 0 {
            return "weekends are your rhythm"
        }

        return "you focus most on \(dayName)"
    }

    private var weekdayAverages: [(name: String, avg: Int)] {
        let days = monthData
        let dayNames = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

        // Group by weekday (Calendar: 1=Sun..7=Sat → remap to Mon=0..Sun=6)
        var weekdayTotals: [Int: [Int]] = [:]
        for i in 0..<7 { weekdayTotals[i] = [] }

        for day in days {
            let monIndex = (day.weekday + 5) % 7
            weekdayTotals[monIndex]?.append(day.seconds)
        }

        return (0..<7).map { i in
            let entries = weekdayTotals[i] ?? []
            let activeDays = entries.filter { $0 > 0 }
            let avg = activeDays.isEmpty ? 0 : activeDays.reduce(0, +) / activeDays.count
            return (dayNames[i], avg)
        }
    }

    private func dayOfWeekBars(averages: [(name: String, avg: Int)]) -> some View {
        let maxAvg = max(averages.map { $0.avg }.max() ?? 1, 1)

        return SurfaceCard(padding: CTRLSpacing.cardPadding, cornerRadius: CTRLSpacing.cardRadius) {
            VStack(spacing: CTRLSpacing.md) {
                ForEach(0..<7, id: \.self) { i in
                    let entry = averages[i]
                    HStack(spacing: CTRLSpacing.sm) {
                        Text(entry.name)
                            .font(CTRLFonts.captionFont)
                            .tracking(1)
                            .foregroundColor(CTRLColors.textTertiary)
                            .frame(width: 30, alignment: .leading)

                        GeometryReader { geo in
                            let width = entry.avg > 0
                                ? max(CGFloat(entry.avg) / CGFloat(maxAvg) * geo.size.width, 4)
                                : 4
                            RoundedRectangle(cornerRadius: 3)
                                .fill(entry.avg > 0 ? CTRLColors.accent.opacity(0.6) : Color.white.opacity(0.04))
                                .frame(width: width, height: 16)
                                .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 20)

                        Text(StatsChartHelpers.formatDuration(entry.avg))
                            .font(CTRLFonts.micro)
                            .foregroundColor(entry.avg > 0 ? CTRLColors.accent : Color.white.opacity(0.35))
                            .monospacedDigit()
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: - Month Heatmap

    private var monthHeatmap: some View {
        let days = monthData
        let calendar = Calendar.current
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        let dayHeaders = ["m", "t", "w", "t", "f", "s", "s"]

        // Calculate leading empty cells (Monday-first grid)
        let firstWeekday = days.first?.weekday ?? 2
        let leadingBlanks = (firstWeekday + 5) % 7

        return VStack(spacing: CTRLSpacing.sm) {
            // Legend (3 tiers, right-aligned)
            HStack(spacing: CTRLSpacing.xs) {
                Spacer()
                heatmapLegendItem(color: CTRLColors.accent.opacity(0.4), label: "<2h")
                heatmapLegendItem(color: CTRLColors.accent.opacity(0.7), label: "2-4h")
                heatmapLegendItem(color: CTRLColors.accent, label: ">4h")
            }

            // Day-of-week header
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Text(dayHeaders[i])
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(CTRLColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 4) {
                // Leading blank cells
                ForEach((-leadingBlanks..<0), id: \.self) { _ in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }

                // Day cells
                ForEach(days) { day in
                    let isToday = calendar.isDateInToday(day.date) && selectedMonthOffset == 0
                    let tierColor = heatmapTierColor(seconds: day.seconds)

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(tierColor)

                        if isToday {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(CTRLColors.accent.opacity(0.4), lineWidth: 1.5)
                        }

                        Text("\(day.day)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(day.seconds > 0 ? CTRLColors.textPrimary : CTRLColors.textTertiary)
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func heatmapTierColor(seconds: Int) -> Color {
        let hours = Double(seconds) / 3600.0
        if seconds == 0 { return CTRLColors.surface1 }
        if hours < 2 { return CTRLColors.accent.opacity(0.4) }
        if hours < 4 { return CTRLColors.accent.opacity(0.7) }
        return CTRLColors.accent
    }

    private func heatmapLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color.white.opacity(0.3))
        }
    }

    // MARK: - Best Day Card

    @ViewBuilder
    private var bestDayCard: some View {
        let days = monthData
        let daysWithData = days.filter { $0.seconds > 0 }

        if daysWithData.count >= 2,
           let best = daysWithData.max(by: { $0.seconds < $1.seconds }) {
            let dateLabel = bestDayDateLabel(best.date)

            SurfaceCard(padding: CTRLSpacing.cardPadding, cornerRadius: CTRLSpacing.buttonRadius) {
                VStack(spacing: CTRLSpacing.xs) {
                    Text("best day")
                        .font(.system(size: 11))
                        .tracking(1.5)
                        .foregroundColor(Color.white.opacity(0.3))

                    Text("\(dateLabel) — \(StatsChartHelpers.formatDuration(best.seconds))")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func bestDayDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date).lowercased()
    }

    // MARK: - Data

    private var monthData: [MonthDayData] {
        let _ = refreshTick // Force SwiftUI re-evaluation during active sessions
        let calendar = Calendar.current
        let today = Date()

        guard let targetMonth = calendar.date(byAdding: .month, value: selectedMonthOffset, to: today) else { return [] }

        let components = calendar.dateComponents([.year, .month], from: targetMonth)
        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else { return [] }

        var days: [MonthDayData] = []

        for dayNum in range {
            guard let date = calendar.date(byAdding: .day, value: dayNum - 1, to: startOfMonth) else { continue }

            let dateKey = DailyFocusEntry.dateFormatter.string(from: date)
            let weekday = calendar.component(.weekday, from: date)

            var totalSeconds = Int(appState.focusHistory.first { $0.date == dateKey }?.totalSeconds ?? 0)

            // Include live session for today
            if calendar.isDateInToday(date) && selectedMonthOffset == 0 {
                totalSeconds = Int(appState.todayFocusSeconds)
            }

            days.append(MonthDayData(
                id: dayNum,
                day: dayNum,
                seconds: totalSeconds,
                date: date,
                weekday: weekday
            ))
        }

        return days
    }
}

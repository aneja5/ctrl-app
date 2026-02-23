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

    private let maxMonthsBack = 3

    var body: some View {
        VStack(spacing: CTRLSpacing.lg) {
            // Month Navigation
            monthNavigation

            // Hero
            monthHero

            // Calendar Heatmap
            monthHeatmap
                .padding(.top, CTRLSpacing.md)

            // Patterns Section
            patternsSection
                .padding(.top, CTRLSpacing.md)
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

    // MARK: - Month Hero

    private var monthHero: some View {
        let days = monthData
        let totalSeconds = days.reduce(0) { $0 + $1.seconds }
        let activeDays = days.filter { $0.seconds > 0 }.count
        let avgSeconds = activeDays > 0 ? totalSeconds / activeDays : 0
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
                    Text("\(StatsChartHelpers.formatDuration(avgSeconds)) daily average")
                        .font(CTRLFonts.captionFont)
                        .tracking(1.5)
                        .foregroundColor(CTRLColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Month Heatmap

    private var monthHeatmap: some View {
        let days = monthData
        let calendar = Calendar.current
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        let dayHeaders = ["m", "t", "w", "t", "f", "s", "s"]

        // Calculate leading empty cells (Monday-first grid)
        // MonthDayData weekday: 1=Sun, 2=Mon...7=Sat
        // Mon-first index: Mon=0, Tue=1...Sun=6
        let firstWeekday = days.first?.weekday ?? 2
        let leadingBlanks = (firstWeekday + 5) % 7

        return VStack(spacing: CTRLSpacing.sm) {
            // Legend
            HStack(spacing: CTRLSpacing.xs) {
                Spacer()
                heatmapLegendItem(color: CTRLColors.accent.opacity(0.25), label: "<1h")
                heatmapLegendItem(color: CTRLColors.accent.opacity(0.50), label: "1-3h")
                heatmapLegendItem(color: CTRLColors.accent.opacity(0.75), label: "3-5h")
                heatmapLegendItem(color: CTRLColors.accent, label: ">5h")
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
                // Leading blank cells (negative IDs to avoid collision with day IDs)
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
                                .stroke(CTRLColors.accent, lineWidth: 1.5)
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
        if hours < 1 { return CTRLColors.accent.opacity(0.25) }
        if hours < 3 { return CTRLColors.accent.opacity(0.50) }
        if hours < 5 { return CTRLColors.accent.opacity(0.75) }
        return CTRLColors.accent
    }

    private func heatmapLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(CTRLColors.textTertiary)
        }
    }

    // MARK: - Patterns Section

    private var patternsSection: some View {
        VStack(spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "patterns")

            dayOfWeekBars
        }
    }

    private var dayOfWeekBars: some View {
        let days = monthData
        let dayNames = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

        // Group by weekday (Calendar: 1=Sun..7=Sat → remap to Mon=0..Sun=6)
        var weekdayTotals: [Int: [Int]] = [:]
        for i in 0..<7 { weekdayTotals[i] = [] }

        for day in days {
            // Convert Calendar weekday (1=Sun) to Mon-based index (0=Mon..6=Sun)
            let monIndex = (day.weekday + 5) % 7
            weekdayTotals[monIndex]?.append(day.seconds)
        }

        let averages: [(name: String, avg: Int)] = (0..<7).map { i in
            let entries = weekdayTotals[i] ?? []
            let activeDays = entries.filter { $0 > 0 }
            let avg = activeDays.isEmpty ? 0 : activeDays.reduce(0, +) / activeDays.count
            return (dayNames[i], avg)
        }

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

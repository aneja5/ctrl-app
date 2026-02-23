import SwiftUI

struct WeeklyStatsView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedWeekOffset: Int
    @State private var refreshTick: Int = 0

    private var maxWeeksBack: Int {
        let calendar = CalendarHelper.mondayFirst
        guard let regDate = appState.registrationDate else { return 0 }
        let weeks = calendar.dateComponents([.weekOfYear], from: regDate, to: Date()).weekOfYear ?? 0
        return max(weeks, 0)
    }

    var body: some View {
        let totalSeconds = weekData.reduce(0) { $0 + $1.seconds }

        VStack(spacing: CTRLSpacing.lg) {
            if totalSeconds > 0 {
                // Full dashboard
                streakTrendHeader
                heroMetric
                barChart
                    .padding(.top, CTRLSpacing.md)
                    .padding(.bottom, CTRLSpacing.sm)
                weekNavigation
                    .padding(.top, CTRLSpacing.sm)
                if selectedWeekOffset == 0 {
                    todayCard
                }
                dailyBreakdown
                summaryRow
            } else {
                // Empty state
                streakTrendHeader
                emptyWeekCard
            }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            if appState.isInSession {
                refreshTick += 1
            }
        }
    }

    // MARK: - Streak + Trend Header

    private var streakTrendHeader: some View {
        HStack {
            streakBadge
            Spacer()
            trendIndicator
        }
    }

    private var streakBadge: some View {
        let streak = appState.currentStreak

        return HStack(spacing: 6) {
            if streak > 0 {
                Text("🔥")
                    .font(.system(size: 13))
            }
            if streak > 1 {
                (Text("\(streak)").foregroundColor(CTRLColors.accent) +
                 Text(" day streak").foregroundColor(Color.white.opacity(0.5)))
                    .font(.system(size: 14, weight: .medium))
            } else if streak == 1 {
                (Text("\(streak)").foregroundColor(CTRLColors.accent) +
                 Text(" day streak").foregroundColor(Color.white.opacity(0.5)))
                    .font(.system(size: 14, weight: .medium))
            } else {
                Text("start a streak today")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                .fill(CTRLColors.surface1)
        )
    }

    // MARK: - Empty State

    private var emptyWeekCard: some View {
        SurfaceCard(padding: CTRLSpacing.lg, cornerRadius: CTRLSpacing.cardRadius) {
            Text("your first session will show up here")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.4))
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var trendIndicator: some View {
        let thisWeekSeconds = weekData.reduce(0) { $0 + $1.seconds }

        if let prev = previousWeekTotalSeconds {
            let diff = thisWeekSeconds - prev

            if diff > 0 {
                Text("↑ \(StatsChartHelpers.formatDuration(diff))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.55, green: 0.75, blue: 0.55).opacity(0.8))
            } else if diff < 0 {
                Text("↓ \(StatsChartHelpers.formatDuration(abs(diff)))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.4))
            } else {
                Text("same as last week")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.3))
            }
        }
    }

    /// Total seconds for the week before the currently selected week
    private var previousWeekTotalSeconds: Int? {
        let calendar = CalendarHelper.mondayFirst
        let today = Date()

        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2
        guard let startOfCurrentWeek = calendar.date(from: components) else { return nil }

        let prevOffset = selectedWeekOffset - 1
        guard let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: prevOffset, to: startOfCurrentWeek) else { return nil }

        var total = 0
        var hasAnyData = false
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: i, to: prevWeekStart) else { continue }
            let dateKey = DailyFocusEntry.dateFormatter.string(from: date)
            if let entry = appState.focusHistory.first(where: { $0.date == dateKey }) {
                total += Int(entry.totalSeconds)
                if entry.totalSeconds > 0 { hasAnyData = true }
            }
        }

        return hasAnyData ? total : nil
    }

    // MARK: - Hero Metric

    private var heroMetric: some View {
        let totalSeconds = weekData.reduce(0) { $0 + $1.seconds }
        let isEmpty = totalSeconds == 0

        return SurfaceCard(padding: CTRLSpacing.lg, cornerRadius: CTRLSpacing.cardRadius) {
            VStack(spacing: CTRLSpacing.xs) {
                Text(StatsChartHelpers.formatDuration(totalSeconds))
                    .font(.system(size: isEmpty ? 36 : 40, weight: .light, design: .default))
                    .foregroundColor(isEmpty ? Color.white.opacity(0.3) : CTRLColors.textPrimary)
                    .monospacedDigit()

                Text("time reclaimed")
                    .font(CTRLFonts.captionFont)
                    .tracking(2)
                    .foregroundColor(CTRLColors.textTertiary)

                if isEmpty {
                    Text("lock in to start reclaiming time")
                        .font(CTRLFonts.micro)
                        .foregroundColor(Color.white.opacity(0.4))
                        .padding(.top, CTRLSpacing.micro)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Bar Chart

    private var barChart: some View {
        let days = weekData
        let maxSeconds = max(days.map { $0.seconds }.max() ?? 0, 60)
        let yAxisMax = StatsChartHelpers.calculateYAxisMax(maxSeconds: maxSeconds)
        let chartHeight: CGFloat = 200
        let maxMinutes = max(maxSeconds / 60, 1)

        // Average line data (only days with data, need >= 2)
        let daysWithData = days.filter { $0.seconds > 0 }
        let avgSeconds = daysWithData.count >= 2
            ? daysWithData.reduce(0) { $0 + $1.seconds } / daysWithData.count
            : 0

        return VStack(spacing: 4) {
            HStack(alignment: .top, spacing: CTRLSpacing.xs) {
                YAxisLabels(maxSeconds: yAxisMax, height: chartHeight)

                ZStack(alignment: .bottom) {
                    ChartGridLines(height: chartHeight)

                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(days) { day in
                            let dayMinutes = day.seconds / 60
                            let intensity = dayMinutes > 0
                                ? 0.3 + (Double(dayMinutes) / Double(maxMinutes)) * 0.7
                                : 0

                            RoundedRectangle(cornerRadius: 8)
                                .fill(day.seconds > 0
                                    ? LinearGradient(
                                        colors: [
                                            CTRLColors.accent.opacity(intensity * 0.6),
                                            CTRLColors.accent.opacity(intensity)
                                        ],
                                        startPoint: .bottom,
                                        endPoint: .top
                                      )
                                    : LinearGradient(
                                        colors: [Color.white.opacity(0.08)],
                                        startPoint: .bottom,
                                        endPoint: .top
                                      )
                                )
                                .frame(width: 32, height: StatsChartHelpers.barHeight(for: day.seconds, max: yAxisMax, chartHeight: chartHeight))
                                .overlay(
                                    day.isToday
                                        ? RoundedRectangle(cornerRadius: 8)
                                            .stroke(CTRLColors.accent.opacity(0.5), lineWidth: 1)
                                        : nil
                                )
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // Average dotted line
                    if avgSeconds > 0 {
                        let avgY = chartHeight * (1 - CGFloat(avgSeconds) / CGFloat(yAxisMax))
                        VStack(spacing: 0) {
                            Color.clear.frame(height: max(avgY, 0))
                            DottedLine()
                                .stroke(Color.white.opacity(0.2),
                                        style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .frame(height: 1)
                            Spacer(minLength: 0)
                        }
                        .frame(height: chartHeight)
                        .allowsHitTesting(false)
                    }
                }
                .frame(height: chartHeight)
            }

            // Day Labels
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 28 + CTRLSpacing.xs)

                HStack(spacing: 12) {
                    ForEach(days) { day in
                        Text(day.day)
                            .font(CTRLFonts.captionFont)
                            .tracking(1)
                            .foregroundColor(day.isToday ? CTRLColors.accent : CTRLColors.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Week Navigation

    private var weekNavigation: some View {
        HStack(spacing: CTRLSpacing.xl) {
            Button(action: {
                if selectedWeekOffset > -maxWeeksBack {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedWeekOffset -= 1
                    }
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedWeekOffset > -maxWeeksBack ? CTRLColors.textSecondary : CTRLColors.textTertiary.opacity(0.4))
            }
            .disabled(selectedWeekOffset <= -maxWeeksBack)

            Text(weekDateRange)
                .font(CTRLFonts.bodySmall)
                .foregroundColor(CTRLColors.textTertiary)

            Button(action: {
                if selectedWeekOffset < 0 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedWeekOffset += 1
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedWeekOffset < 0 ? CTRLColors.textSecondary : CTRLColors.textTertiary.opacity(0.4))
            }
            .disabled(selectedWeekOffset >= 0)
        }
    }

    private var weekDateRange: String {
        let calendar = CalendarHelper.mondayFirst
        let today = Date()

        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2 // Monday
        guard var startOfWeek = calendar.date(from: components) else { return "" }

        if let adjusted = calendar.date(byAdding: .weekOfYear, value: selectedWeekOffset, to: startOfWeek) {
            startOfWeek = adjusted
        }

        guard let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let start = formatter.string(from: startOfWeek).lowercased()
        let end = formatter.string(from: endOfWeek).lowercased()
        return "\(start) – \(end)"
    }

    // MARK: - Today Card

    private var todayCard: some View {
        let todayData = weekData.first(where: { $0.isToday })
        let seconds = todayData?.seconds ?? Int(appState.todayFocusSeconds)
        let sessions = appState.todaySessionCount

        return SurfaceCard(padding: CTRLSpacing.cardPadding, cornerRadius: CTRLSpacing.buttonRadius) {
            HStack(spacing: CTRLSpacing.sm) {
                // Green dot
                Circle()
                    .fill(CTRLColors.success)
                    .frame(width: 8, height: 8)

                Text("today")
                    .font(CTRLFonts.captionFont)
                    .tracking(1.5)
                    .foregroundColor(CTRLColors.textTertiary)

                Spacer()

                Text(StatsChartHelpers.formatDuration(seconds))
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(CTRLColors.textPrimary)
                    .monospacedDigit()
                    .opacity(seconds > 0 ? 1.0 : 0.5)

                Text("·")
                    .foregroundColor(CTRLColors.textTertiary)

                Text("\(sessions) \(sessions == 1 ? "session" : "sessions")")
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.textSecondary)
                    .opacity(seconds > 0 ? 1.0 : 0.5)
            }
        }
    }

    // MARK: - Daily Breakdown

    private var dailyBreakdown: some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        let hasAnyData = weekData.contains { $0.seconds > 0 }

        return VStack(spacing: CTRLSpacing.xs) {
            CTRLSectionHeader(title: "daily breakdown")

            if hasAnyData {
                VStack(spacing: CTRLSpacing.xs) {
                    ForEach(weekData.reversed()) { day in
                        let dayLabel: String = {
                            if let date = day.date {
                                return formatter.string(from: date).lowercased()
                            }
                            return day.fullDayName.lowercased()
                        }()

                        SurfaceCard(padding: CTRLSpacing.sm + 4, cornerRadius: CTRLSpacing.buttonRadius) {
                            HStack {
                                Text(dayLabel)
                                    .font(CTRLFonts.bodySmall)
                                    .foregroundColor(day.isToday ? CTRLColors.accent : (day.seconds > 0 ? CTRLColors.textSecondary : Color.white.opacity(0.35)))

                                Spacer()

                                Text(StatsChartHelpers.formatDuration(day.seconds))
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundColor(day.seconds > 0 ? CTRLColors.textPrimary : Color.white.opacity(0.35))
                                    .monospacedDigit()

                                Text("·")
                                    .foregroundColor(day.seconds > 0 ? CTRLColors.textTertiary : Color.white.opacity(0.2))
                                    .font(.system(size: 12))

                                Text("\(day.sessionCount) \(day.sessionCount == 1 ? "session" : "sessions")")
                                    .font(CTRLFonts.micro)
                                    .foregroundColor(day.seconds > 0 ? CTRLColors.textTertiary : Color.white.opacity(0.25))
                            }
                        }
                    }
                }
            } else {
                Text("no sessions this week")
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CTRLSpacing.lg)
            }
        }
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        let days = weekData
        let activeDays = days.filter { $0.seconds > 0 }.count
        let totalSeconds = days.reduce(0) { $0 + $1.seconds }
        let avgSeconds = activeDays > 0 ? totalSeconds / activeDays : 0

        return Text("\(activeDays) of 7 days  ·  \(StatsChartHelpers.formatDuration(avgSeconds)) avg")
            .font(.system(size: 13))
            .foregroundColor(Color.white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.top, CTRLSpacing.xs)
    }

    // MARK: - Data

    private var weekData: [DayData] {
        let _ = refreshTick // Force SwiftUI re-evaluation during active sessions
        let calendar = CalendarHelper.mondayFirst
        let today = Date()

        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2 // Monday
        guard var startOfCurrentWeek = calendar.date(from: components) else { return [] }

        if let adjustedStart = calendar.date(byAdding: .weekOfYear, value: selectedWeekOffset, to: startOfCurrentWeek) {
            startOfCurrentWeek = adjustedStart
        }

        let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
        let dayNames = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

        var days: [DayData] = []

        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: i, to: startOfCurrentWeek) else { continue }

            let dateKey = DailyFocusEntry.dateFormatter.string(from: date)
            let isToday = calendar.isDateInToday(date)
            let entry = appState.focusHistory.first { $0.date == dateKey }

            var totalSeconds = Int(entry?.totalSeconds ?? 0)
            var sessionCount = entry?.sessionCount ?? 0

            if isToday && selectedWeekOffset == 0 {
                totalSeconds = Int(appState.todayFocusSeconds)
                sessionCount = appState.todaySessionCount
            }

            days.append(DayData(
                id: i,
                day: dayLetters[i],
                fullDayName: dayNames[i],
                seconds: totalSeconds,
                isToday: isToday && selectedWeekOffset == 0,
                dateKey: dateKey,
                sessionCount: sessionCount,
                date: date
            ))
        }

        return days
    }
}

import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedWeekOffset: Int = 0

    private let maxWeeksBack = 3

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: CTRLSpacing.xl) {
                    // Header
                    header
                        .padding(.top, CTRLSpacing.md)

                    // Hero Metric
                    heroMetric

                    // Line Chart
                    lineChart

                    // Stats Grid
                    statsGrid

                    // Week Navigation
                    weekNavigation
                        .padding(.top, CTRLSpacing.sm)

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, CTRLSpacing.screenPadding)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(weekLabel.lowercased())
                .font(CTRLFonts.h1)
                .foregroundColor(CTRLColors.textPrimary)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CTRLColors.textTertiary)
                    .frame(width: 36, height: 36)
                    .background(CTRLColors.surface1)
                    .clipShape(Circle())
            }
        }
    }

    private var weekLabel: String {
        if selectedWeekOffset == 0 {
            return "this week"
        } else if selectedWeekOffset == -1 {
            return "last week"
        } else {
            return "\(abs(selectedWeekOffset)) weeks ago"
        }
    }

    // MARK: - Hero Metric

    private var heroMetric: some View {
        let totalSeconds = weekData.reduce(0) { $0 + $1.seconds }

        return SurfaceCard(padding: CTRLSpacing.xl, cornerRadius: CTRLSpacing.cardRadius) {
            VStack(spacing: CTRLSpacing.sm) {
                Text(formatDuration(totalSeconds))
                    .font(.system(size: 44, weight: .light, design: .default))
                    .foregroundColor(CTRLColors.textPrimary)
                    .monospacedDigit()

                Text("TOTAL FOCUS")
                    .font(CTRLFonts.captionFont)
                    .tracking(2)
                    .foregroundColor(CTRLColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Line Chart

    private var lineChart: some View {
        let days = weekData
        let maxSeconds = max(days.map { $0.seconds }.max() ?? 1, 60)

        return VStack(spacing: CTRLSpacing.md) {
            // Chart
            GeometryReader { geometry in
                let width = geometry.size.width
                let height: CGFloat = 120
                let stepX = width / 6

                ZStack {
                    // Grid lines (very subtle)
                    ForEach(0..<4, id: \.self) { i in
                        let y = height - (height * CGFloat(i) / 3)
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                        .stroke(CTRLColors.border.opacity(0.5), lineWidth: 1)
                    }

                    // Line path
                    Path { path in
                        for (index, day) in days.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = height - (CGFloat(day.seconds) / CGFloat(maxSeconds) * (height - 20)) - 10

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        CTRLColors.accent,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )

                    // Dots
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        let x = CGFloat(index) * stepX
                        let y = height - (CGFloat(day.seconds) / CGFloat(maxSeconds) * (height - 20)) - 10

                        Circle()
                            .fill(day.isToday ? CTRLColors.accent : CTRLColors.surface2)
                            .frame(width: day.isToday ? 10 : 6, height: day.isToday ? 10 : 6)
                            .overlay(
                                Circle()
                                    .stroke(CTRLColors.accent, lineWidth: day.isToday ? 0 : 1.5)
                            )
                            .position(x: x, y: y)
                    }
                }
            }
            .frame(height: 120)
            .padding(.horizontal, CTRLSpacing.sm)

            // Day Labels
            HStack {
                ForEach(weekData) { day in
                    Text(day.day)
                        .font(CTRLFonts.captionFont)
                        .tracking(1)
                        .foregroundColor(day.isToday ? CTRLColors.accent : CTRLColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, CTRLSpacing.sm)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let days = weekData
        let totalSeconds = days.reduce(0) { $0 + $1.seconds }
        let activeDays = days.filter { $0.seconds > 0 }.count
        let avgSeconds = activeDays > 0 ? totalSeconds / activeDays : 0

        return HStack(spacing: CTRLSpacing.sm) {
            statCard(value: "\(activeDays)", label: "DAYS ACTIVE")
            statCard(value: formatDuration(avgSeconds), label: "AVG / DAY")
        }
    }

    private func statCard(value: String, label: String) -> some View {
        SurfaceCard(padding: CTRLSpacing.cardPadding, cornerRadius: CTRLSpacing.buttonRadius) {
            VStack(spacing: CTRLSpacing.xs) {
                Text(value)
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(CTRLColors.textPrimary)
                    .monospacedDigit()

                Text(label)
                    .font(CTRLFonts.captionFont)
                    .tracking(1.5)
                    .foregroundColor(CTRLColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
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
        let calendar = Calendar.current
        let today = Date()

        var startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        startOfWeek = calendar.date(byAdding: .weekOfYear, value: selectedWeekOffset, to: startOfWeek)!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        return "\(formatter.string(from: startOfWeek)) – \(formatter.string(from: endOfWeek))"
    }

    // MARK: - Data

    private var weekData: [DayData] {
        let calendar = Calendar.current
        let today = Date()

        var startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        startOfWeek = calendar.date(byAdding: .weekOfYear, value: selectedWeekOffset, to: startOfWeek)!

        let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

        var days: [DayData] = []

        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: i, to: startOfWeek)!
            let dateKey = DailyFocusEntry.dateFormatter.string(from: date)
            let seconds = appState.focusHistory.first { $0.date == dateKey }?.totalSeconds ?? 0
            let isToday = calendar.isDateInToday(date)

            var totalSeconds = Int(seconds)
            if isToday && selectedWeekOffset == 0 {
                totalSeconds = Int(appState.todayFocusSeconds + appState.currentSessionSeconds)
            }

            days.append(DayData(
                id: i,
                day: dayLetters[i],
                fullDayName: "",
                seconds: totalSeconds,
                isToday: isToday && selectedWeekOffset == 0,
                dateKey: dateKey
            ))
        }

        return days
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m"
        }
    }
}

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
                VStack(spacing: CTRLSpacing.lg) {
                    // Header
                    header
                        .padding(.top, CTRLSpacing.md)

                    // Hero Metric
                    heroMetric

                    // Bar Chart
                    barChart
                        .padding(.top, CTRLSpacing.md)
                        .padding(.bottom, CTRLSpacing.sm)

                    // Week Navigation (above stats)
                    weekNavigation
                        .padding(.top, CTRLSpacing.sm)

                    // Stats Grid
                    statsGrid
                        .padding(.top, CTRLSpacing.sm)

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, CTRLSpacing.screenPadding)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(weekLabel.lowercased())
                .font(CTRLFonts.ritualSection)
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

        return SurfaceCard(padding: CTRLSpacing.lg, cornerRadius: CTRLSpacing.cardRadius) {
            VStack(spacing: CTRLSpacing.xs) {
                Text(formatDuration(totalSeconds))
                    .font(.system(size: 40, weight: .light, design: .default))
                    .foregroundColor(CTRLColors.textPrimary)
                    .monospacedDigit()

                Text("time reclaimed")
                    .font(CTRLFonts.captionFont)
                    .tracking(2)
                    .foregroundColor(CTRLColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Bar Chart

    private var barChart: some View {
        let days = weekData
        let maxSeconds = max(days.map { $0.seconds }.max() ?? 0, 60)
        let yAxisMax = calculateYAxisMax(maxSeconds: maxSeconds)
        let chartHeight: CGFloat = 200

        return VStack(spacing: 4) {
            // Chart area with Y-axis labels
            HStack(alignment: .top, spacing: CTRLSpacing.xs) {
                // Y-Axis Labels
                VStack(alignment: .trailing, spacing: 0) {
                    Text(formatYAxisLabel(seconds: yAxisMax))
                        .font(CTRLFonts.micro)
                        .foregroundColor(CTRLColors.textTertiary)

                    Spacer()

                    Text(formatYAxisLabel(seconds: yAxisMax / 2))
                        .font(CTRLFonts.micro)
                        .foregroundColor(CTRLColors.textTertiary)

                    Spacer()

                    Text("0h")
                        .font(CTRLFonts.micro)
                        .foregroundColor(CTRLColors.textTertiary)
                }
                .frame(width: 28, height: chartHeight)

                // Chart area
                ZStack(alignment: .bottom) {
                    // Grid lines (solid at 0, half, full; dotted at quarters)
                    VStack(spacing: 0) {
                        // Top solid line (max)
                        Rectangle()
                            .fill(CTRLColors.border.opacity(0.3))
                            .frame(height: 1)

                        Spacer()

                        // 3/4 dotted line
                        DottedLine()
                            .stroke(CTRLColors.border.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .frame(height: 1)

                        Spacer()

                        // Middle solid line (half)
                        Rectangle()
                            .fill(CTRLColors.border.opacity(0.3))
                            .frame(height: 1)

                        Spacer()

                        // 1/4 dotted line
                        DottedLine()
                            .stroke(CTRLColors.border.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .frame(height: 1)

                        Spacer()

                        // Bottom solid line (0)
                        Rectangle()
                            .fill(CTRLColors.border.opacity(0.3))
                            .frame(height: 1)
                    }
                    .frame(height: chartHeight)

                    // Bars
                    HStack(alignment: .bottom, spacing: 16) {
                        ForEach(days) { day in
                            RoundedRectangle(cornerRadius: 10)
                                .fill(day.isToday ? CTRLColors.accent : CTRLColors.accent.opacity(0.35))
                                .frame(width: 28, height: barHeight(for: day.seconds, max: yAxisMax, chartHeight: chartHeight))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(height: chartHeight)
            }

            // Day Labels - closer to chart
            HStack(spacing: 0) {
                // Spacer for Y-axis width
                Color.clear
                    .frame(width: 28 + CTRLSpacing.xs)

                // Day letters aligned with bars
                HStack(spacing: 16) {
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

    // Calculate nice Y-axis maximum (whole hours only, always even so mid-label is whole)
    private func calculateYAxisMax(maxSeconds: Int) -> Int {
        let maxHours = Double(maxSeconds) / 3600.0

        if maxHours <= 1   { return 3600 * 2 }     // 2h (0h, 1h, 2h)
        if maxHours <= 2   { return 3600 * 4 }     // 4h (0h, 2h, 4h)
        if maxHours <= 3   { return 3600 * 6 }     // 6h (0h, 3h, 6h)
        if maxHours <= 4   { return 3600 * 8 }     // 8h (0h, 4h, 8h)
        if maxHours <= 5   { return 3600 * 10 }    // 10h (0h, 5h, 10h)
        if maxHours <= 6   { return 3600 * 12 }    // 12h (0h, 6h, 12h)
        if maxHours <= 8   { return 3600 * 16 }    // 16h (0h, 8h, 16h)
        if maxHours <= 10  { return 3600 * 20 }    // 20h (0h, 10h, 20h)

        let roundedHours = Int(ceil(maxHours / 2.0) * 2)
        return roundedHours * 3600
    }

    private func formatYAxisLabel(seconds: Int) -> String {
        let hours = seconds / 3600
        return "\(hours)h"
    }

    private func barHeight(for seconds: Int, max: Int, chartHeight: CGFloat) -> CGFloat {
        guard max > 0 else { return 4 }
        let minHeight: CGFloat = seconds > 0 ? 6 : 0
        let ratio = CGFloat(seconds) / CGFloat(max)
        return Swift.max(ratio * chartHeight, minHeight)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let days = weekData
        let totalSeconds = days.reduce(0) { $0 + $1.seconds }
        let activeDays = days.filter { $0.seconds > 0 }.count
        let avgSeconds = activeDays > 0 ? totalSeconds / activeDays : 0

        return HStack(spacing: CTRLSpacing.sm) {
            statCard(value: "\(activeDays)", label: "consistency")
            statCard(value: formatDuration(avgSeconds), label: "daily rhythm")
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

        // Get Monday of current week
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2 // Monday
        guard var startOfWeek = calendar.date(from: components) else { return "" }

        // Adjust for offset
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

    // MARK: - Data

    private var weekData: [DayData] {
        let calendar = Calendar.current
        let today = Date()

        // Get the start of the current week (Monday)
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2 // Monday
        guard var startOfCurrentWeek = calendar.date(from: components) else { return [] }

        // Adjust for week offset
        if let adjustedStart = calendar.date(byAdding: .weekOfYear, value: selectedWeekOffset, to: startOfCurrentWeek) {
            startOfCurrentWeek = adjustedStart
        }

        let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

        var days: [DayData] = []

        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: i, to: startOfCurrentWeek) else { continue }

            let dateKey = DailyFocusEntry.dateFormatter.string(from: date)
            let isToday = calendar.isDateInToday(date)

            // Get seconds from history
            var totalSeconds = Int(appState.focusHistory.first { $0.date == dateKey }?.totalSeconds ?? 0)

            // Add live session time if today and current week
            if isToday && selectedWeekOffset == 0 {
                totalSeconds = Int(appState.todayFocusSeconds)
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

// MARK: - Dotted Line Shape

struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

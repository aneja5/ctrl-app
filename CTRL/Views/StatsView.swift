import SwiftUI

struct StatsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedWeekOffset: Int = 0  // 0 = current week, -1 = last week, etc.

    private let maxWeeksBack = 3  // Show up to 4 weeks (0, -1, -2, -3)

    var body: some View {
        NavigationView {
            ZStack {
                CTRLColors.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Week Navigation
                    weekNavigator

                    // Weekly Bar Chart
                    weeklyChart

                    // Week Total
                    weekTotalCard

                    // Day breakdown list
                    dayBreakdownList

                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationTitle("statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundColor(CTRLColors.accent)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Week Navigator

    private var weekNavigator: some View {
        HStack {
            // Left arrow
            Button(action: {
                if selectedWeekOffset > -maxWeeksBack {
                    selectedWeekOffset -= 1
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(selectedWeekOffset > -maxWeeksBack ? CTRLColors.accent : CTRLColors.textMuted)
            }
            .disabled(selectedWeekOffset <= -maxWeeksBack)

            Spacer()

            // Week label
            Text(weekLabel)
                .font(.headline)
                .foregroundColor(CTRLColors.textPrimary)

            Spacer()

            // Right arrow
            Button(action: {
                if selectedWeekOffset < 0 {
                    selectedWeekOffset += 1
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(selectedWeekOffset < 0 ? CTRLColors.accent : CTRLColors.textMuted)
            }
            .disabled(selectedWeekOffset >= 0)
        }
        .padding(.horizontal, 24)
    }

    private var weekLabel: String {
        if selectedWeekOffset == 0 {
            return "This Week"
        } else if selectedWeekOffset == -1 {
            return "Last Week"
        } else {
            return "\(abs(selectedWeekOffset)) Weeks Ago"
        }
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        let days = weekData
        let maxSeconds = max(days.map { $0.seconds }.max() ?? 1, 1)

        return HStack(alignment: .bottom, spacing: 12) {
            ForEach(days) { day in
                VStack(spacing: 8) {
                    // Bar
                    RoundedRectangle(cornerRadius: 6)
                        .fill(day.isToday ? CTRLColors.accent : CTRLColors.accent.opacity(0.5))
                        .frame(width: 36, height: max(CGFloat(day.seconds) / CGFloat(maxSeconds) * 150, 4))

                    // Day label
                    Text(day.day)
                        .font(.caption2)
                        .foregroundColor(day.isToday ? CTRLColors.accent : CTRLColors.textSecondary)
                }
            }
        }
        .frame(height: 180)
        .padding(.horizontal, 24)
    }

    // MARK: - Week Total Card

    private var weekTotalCard: some View {
        let totalSeconds = weekData.reduce(0) { $0 + $1.seconds }

        return VStack(spacing: 4) {
            Text("weekly total")
                .font(.caption)
                .foregroundColor(CTRLColors.textSecondary)
            Text(AppState.formatTime(Double(totalSeconds)))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(CTRLColors.textPrimary)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(CTRLColors.cardBackground)
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }

    // MARK: - Day Breakdown

    private var dayBreakdownList: some View {
        VStack(spacing: 0) {
            ForEach(weekData.reversed()) { day in
                HStack {
                    Text(day.fullDayName)
                        .foregroundColor(day.isToday ? CTRLColors.accent : CTRLColors.textPrimary)
                    Spacer()
                    Text(AppState.formatTime(Double(day.seconds)))
                        .foregroundColor(CTRLColors.textSecondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

                if day.id != 0 {
                    Divider()
                        .background(CTRLColors.cardBackground)
                        .padding(.horizontal, 24)
                }
            }
        }
        .background(CTRLColors.cardBackground)
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }

    // MARK: - Data

    private var weekData: [DayData] {
        let calendar = Calendar.current
        let today = Date()

        // Get start of selected week (Monday)
        var startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        startOfWeek = calendar.date(byAdding: .weekOfYear, value: selectedWeekOffset, to: startOfWeek)!

        let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

        var days: [DayData] = []

        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: i, to: startOfWeek)!
            let dateKey = DailyFocusEntry.dateFormatter.string(from: date)
            let seconds = appState.focusHistory.first { $0.date == dateKey }?.totalSeconds ?? 0
            let isToday = calendar.isDateInToday(date)

            // Add current session if today and blocking
            var totalSeconds = Int(seconds)
            if isToday && selectedWeekOffset == 0 {
                totalSeconds = Int(appState.todayFocusSeconds)
            }

            days.append(DayData(
                id: i,
                day: dayLetters[i],
                fullDayName: dayNames[i],
                seconds: totalSeconds,
                isToday: isToday && selectedWeekOffset == 0,
                dateKey: dateKey
            ))
        }

        return days
    }
}

struct DayData: Identifiable {
    let id: Int
    let day: String
    let fullDayName: String
    let seconds: Int
    let isToday: Bool
    let dateKey: String
}

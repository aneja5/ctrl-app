import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: StatsTab = .week
    @State private var selectedWeekOffset: Int = 0

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: CTRLSpacing.lg) {
                    // Header
                    header
                        .padding(.top, CTRLSpacing.md)

                    // Tab Selector
                    StatsTabSelector(selected: $selectedTab)

                    // Tab Content
                    switch selectedTab {
                    case .week:
                        WeeklyStatsView(selectedWeekOffset: $selectedWeekOffset)
                    case .month:
                        MonthlyStatsView()
                    case .lifetime:
                        LifetimeStatsView()
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, CTRLSpacing.screenPadding)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("activity")
                .font(CTRLFonts.ritualSection)
                .foregroundColor(CTRLColors.textPrimary)

            Spacer()
        }
    }
}

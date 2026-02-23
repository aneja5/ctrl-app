import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nfcManager: NFCManager
    @EnvironmentObject var blockingManager: BlockingManager
    @EnvironmentObject var scheduleManager: ScheduleManager

    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            CTRLColors.base.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)

                ActivityView()
                    .tag(1)

                SettingsView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            NavBar(selectedTab: $selectedTab)
        }
        .preferredColorScheme(.dark)
    }
}

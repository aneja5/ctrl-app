import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nfcManager: NFCManager
    @EnvironmentObject var blockingManager: BlockingManager

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            HomeView()
        }
        .preferredColorScheme(.dark)
    }
}

import SwiftUI

struct RootView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nfcManager: NFCManager
    @EnvironmentObject var blockingManager: BlockingManager

    // MARK: - Body

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                HomeView(
                    nfcManager: nfcManager,
                    blockingManager: blockingManager
                )
                .onAppear {
                    print("[RootView] Showing HomeView")
                }
            } else {
                OnboardingView {
                    print("[RootView] onComplete callback fired")
                }
                .onAppear {
                    print("[RootView] Showing OnboardingView — hasCompletedOnboarding: \(appState.hasCompletedOnboarding)")
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.hasCompletedOnboarding)
    }
}

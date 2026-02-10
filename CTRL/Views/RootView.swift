import SwiftUI

struct RootView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nfcManager: NFCManager
    @EnvironmentObject var blockingManager: BlockingManager

    // MARK: - Body

    var body: some View {
        Group {
            if appState.isPaired {
                HomeView(
                    nfcManager: nfcManager,
                    blockingManager: blockingManager
                )
                .onAppear {
                    print("[RootView] Showing HomeView — isPaired: \(appState.isPaired)")
                }
            } else {
                OnboardingView {
                    print("[RootView] onComplete callback fired")
                }
                .onAppear {
                    print("[RootView] Showing OnboardingView — isPaired: \(appState.isPaired)")
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.isPaired)
    }
}

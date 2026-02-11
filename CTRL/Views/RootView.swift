import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nfcManager: NFCManager
    @EnvironmentObject var blockingManager: BlockingManager

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            Group {
                if appState.isPaired {
                    MainTabView()
                        .transition(.opacity)
                        .onAppear {
                            print("[RootView] Showing MainTabView — isPaired: \(appState.isPaired)")
                        }
                } else {
                    OnboardingView {
                        print("[RootView] onComplete callback fired")
                    }
                    .transition(.opacity)
                    .onAppear {
                        print("[RootView] Showing OnboardingView — isPaired: \(appState.isPaired)")
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: appState.isPaired)
    }
}

import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nfcManager: NFCManager
    @EnvironmentObject var blockingManager: BlockingManager
    @ObservedObject private var supabase = SupabaseManager.shared

    @State private var isCheckingAuth = true

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            Group {
                if isCheckingAuth {
                    // Brief loading state while restoring session
                    VStack {
                        Spacer()
                        Text("ctrl")
                            .font(.custom("Georgia", size: 28))
                            .foregroundColor(CTRLColors.textTertiary)
                            .tracking(3)
                        Spacer()
                    }
                    .transition(.opacity)
                } else if appState.hasCompletedOnboarding {
                    MainTabView()
                        .transition(.opacity)
                        .onAppear {
                            print("[RootView] Showing MainTabView — onboarding complete")
                        }
                } else {
                    OnboardingView(startStep: resolveOnboardingStep()) {
                        print("[RootView] onComplete callback fired")
                    }
                    .transition(.opacity)
                    .onAppear {
                        print("[RootView] Showing OnboardingView at step: \(resolveOnboardingStep()) — authenticated: \(supabase.isAuthenticated), isPaired: \(appState.isPaired)")
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: appState.hasCompletedOnboarding)
        .animation(.easeOut(duration: 0.3), value: isCheckingAuth)
        .task {
            await checkAuthState()
        }
    }

    // MARK: - Auth Check

    /// Restores the Supabase session on launch to determine starting state.
    private func checkAuthState() async {
        let _ = await supabase.getCurrentUser()
        isCheckingAuth = false
        print("[RootView] Auth check complete — authenticated: \(supabase.isAuthenticated), isPaired: \(appState.isPaired), onboarded: \(appState.hasCompletedOnboarding)")
    }

    // MARK: - Step Resolution

    /// Determines which onboarding step to start at based on persisted state.
    /// - Not authenticated → start at splash (full flow)
    /// - Authenticated but not paired → skip to pair step
    /// - Authenticated and paired but not onboarded → skip to apps step
    private func resolveOnboardingStep() -> OnboardingView.Step {
        if supabase.isAuthenticated {
            if appState.isPaired {
                // Authenticated + paired → pick up at apps
                return .apps
            } else {
                // Authenticated but not paired → pick up at pair
                return .pair
            }
        }
        // Not authenticated → full flow from splash
        return .splash
    }
}

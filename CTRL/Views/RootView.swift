import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nfcManager: NFCManager
    @EnvironmentObject var blockingManager: BlockingManager

    #if DEBUG
    @State private var forceOnboarding = false  // Set to true when testing
    #endif

    /// Determine the best onboarding resume point based on completed steps
    private var onboardingResumeStep: OnboardingView.Step {
        if appState.userEmail != nil && appState.hasScreenTimePermission {
            // Signed in + permission granted → resume at intent selection
            return .modes
        } else if appState.userEmail != nil {
            // Signed in but no permission → resume at screen time
            return .screenTime
        } else {
            // Fresh user → start from beginning
            return .welcome
        }
    }

    var body: some View {
        Group {
            #if DEBUG
            if forceOnboarding {
                OnboardingView(startStep: .splash, onComplete: {
                    appState.markOnboardingComplete()
                    forceOnboarding = false
                })
            } else if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView(startStep: onboardingResumeStep, onComplete: {
                    appState.markOnboardingComplete()
                })
                .task {
                    if appState.userEmail == nil {
                        // Clear any stale Keychain auth on fresh install
                        try? await SupabaseManager.shared.signOut()
                    }
                }
            }
            #else
            if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView(startStep: onboardingResumeStep, onComplete: {
                    appState.markOnboardingComplete()
                })
                .task {
                    if appState.userEmail == nil {
                        // Clear any stale Keychain auth on fresh install
                        try? await SupabaseManager.shared.signOut()
                    }
                }
            }
            #endif
        }
        .onAppear {
            appState.restoreSessionIfNeeded()
        }
    }
}

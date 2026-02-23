import SwiftUI
import ManagedSettings

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nfcManager: NFCManager
    @EnvironmentObject var blockingManager: BlockingManager
    @EnvironmentObject var scheduleManager: ScheduleManager

    // App-wide splash shown on every cold launch
    @State private var showSplash = true
    @State private var splashWordmarkOpacity: Double = 0

    #if DEBUG
    @State private var forceOnboarding = false  // Set to true when testing
    #endif

    /// Determine the best onboarding resume point based on completed steps
    private var onboardingResumeStep: OnboardingView.Step {
        if appState.userEmail != nil && appState.hasScreenTimePermission {
            // Signed in + permission granted → resume at ready
            return .ready
        } else if appState.userEmail != nil {
            // Signed in but no permission → resume at screen time
            return .screenTime
        } else {
            // Fresh user → start from welcome
            return .welcome
        }
    }

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            if showSplash {
                // Splash screen — every cold launch
                VStack(spacing: 0) {
                    Spacer()

                    Text("ctrl")
                        .font(.custom("Georgia", size: 28))
                        .foregroundColor(CTRLColors.textTertiary)
                        .tracking(3)
                        .opacity(splashWordmarkOpacity)

                    Spacer()
                }
                .transition(.opacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.8)) {
                        splashWordmarkOpacity = 1.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            showSplash = false
                        }
                    }
                }
            } else {
                Group {
                    #if DEBUG
                    if forceOnboarding {
                        OnboardingView(startStep: .welcome, onComplete: {
                            appState.markOnboardingComplete()
                            forceOnboarding = false
                        })
                    } else if appState.isReturningFromNewDevice {
                        NewDeviceWelcomeView(onContinue: {
                            appState.isReturningFromNewDevice = false
                        })
                    } else if appState.hasCompletedOnboarding {
                        MainTabView()
                    } else {
                        OnboardingView(startStep: onboardingResumeStep, onComplete: {
                            appState.markOnboardingComplete()
                        })
                        .task {
                            if appState.userEmail == nil {
                                try? await SupabaseManager.shared.signOut()
                            }
                        }
                    }
                    #else
                    if appState.isReturningFromNewDevice {
                        NewDeviceWelcomeView(onContinue: {
                            appState.isReturningFromNewDevice = false
                        })
                    } else if appState.hasCompletedOnboarding {
                        MainTabView()
                    } else {
                        OnboardingView(startStep: onboardingResumeStep, onComplete: {
                            appState.markOnboardingComplete()
                        })
                        .task {
                            if appState.userEmail == nil {
                                try? await SupabaseManager.shared.signOut()
                            }
                        }
                    }
                    #endif
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            // One-time migration: clear legacy unnamed ManagedSettingsStore
            migrateToNamedStoresIfNeeded()

            blockingManager.ensureConsistentState()
            appState.restoreSessionIfNeeded()
            if FeatureFlags.schedulesEnabled {
                scheduleManager.reregisterAllSchedules(
                    schedules: appState.schedules,
                    modes: appState.modes
                )
                // reregisterAllSchedules calls syncScheduleShields() + scheduleNextBGTask() internally
            } else {
                ScheduleManager.cleanupSchedulesIfDisabled()
            }
        }
        .task {
            // Background cloud refresh: if signed in, fetch latest from Supabase
            guard appState.hasCompletedOnboarding,
                  appState.userEmail != nil else { return }

            // Wait for Supabase session to restore from Keychain (runs in SupabaseManager.init)
            for _ in 0..<30 {
                if SupabaseManager.shared.isAuthenticated { break }
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            guard SupabaseManager.shared.isAuthenticated else { return }

            if let cloudData = await CloudSyncManager.shared.fetchFromCloud() {
                CloudSyncManager.shared.restoreFromCloud(cloudData, into: appState)
                appState.saveState()
                #if DEBUG
                print("[RootView] Background cloud refresh complete")
                #endif
            }
        }
    }

    /// One-time migration: clear the legacy unnamed ManagedSettingsStore.
    /// After this update, BlockingManager uses "manual" and ScheduleManager uses "schedule".
    private func migrateToNamedStoresIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "ctrl_migrated_named_stores") else { return }

        // Apply shields to named stores first, then clear the unnamed one
        if FeatureFlags.schedulesEnabled {
            scheduleManager.syncScheduleShields()
        }
        ManagedSettingsStore().clearAllSettings()

        defaults.set(true, forKey: "ctrl_migrated_named_stores")
        #if DEBUG
        print("[RootView] Migrated to named ManagedSettingsStores — cleared legacy unnamed store")
        #endif
    }
}

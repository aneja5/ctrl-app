import SwiftUI
import FamilyControls

struct OnboardingView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var blockingManager: BlockingManager
    @StateObject private var nfcManager = NFCManager()

    // MARK: - State

    @State private var currentPage = 0
    @State private var showAppPicker = false
    @State private var pickerSelection = FamilyActivitySelection()
    @State private var isPulsing = false
    @State private var showPairSuccess = false
    @State private var scanError: String?

    // MARK: - Callback

    var onComplete: () -> Void

    // MARK: - Body

    var body: some View {
        ZStack {
            CTRLColors.background
                .ignoresSafeArea()

            switch currentPage {
            case 1:
                pairTokenPage
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case 2:
                selectAppsPage
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            default:
                welcomePage
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentPage)
        .familyActivityPicker(
            isPresented: $showAppPicker,
            selection: $pickerSelection
        )
        .onChange(of: pickerSelection) {
            print("[Onboarding] Apps selected: \(pickerSelection.applicationTokens.count) apps, \(pickerSelection.categoryTokens.count) categories")
            appState.saveSelectedApps(pickerSelection)
        }
        .onAppear {
            print("[Onboarding] View appeared, currentPage: \(currentPage)")
            print("[Onboarding] isPaired: \(appState.isPaired), hasCompletedOnboarding: \(appState.hasCompletedOnboarding)")
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Text("CTRL")
                    .font(CTRLFonts.largeTitle())
                    .foregroundColor(CTRLColors.textPrimary)

                Text("Take back control")
                    .font(CTRLFonts.title())
                    .foregroundColor(CTRLColors.textSecondary)
            }

            Spacer()

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 80))
                .foregroundColor(CTRLColors.accent)

            Spacer()

            Text("Block distracting apps with a physical token")
                .font(CTRLFonts.body())
                .foregroundColor(CTRLColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                print("[Onboarding] Get Started tapped")
                Task {
                    print("[Onboarding] Requesting Screen Time authorization...")
                    let authorized = await blockingManager.requestAuthorization()
                    print("[Onboarding] Authorization result: \(authorized)")
                    appState.isAuthorized = authorized
                    print("[Onboarding] Advancing to page 1 (Pair Token)")
                    withAnimation {
                        currentPage = 1
                    }
                }
            } label: {
                Text("Get Started")
                    .font(CTRLFonts.headline())
                    .foregroundColor(CTRLColors.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(CTRLColors.accent)
                    .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Page 2: Pair Token

    private var pairTokenPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Text("Pair Your Token")
                    .font(CTRLFonts.largeTitle())
                    .foregroundColor(CTRLColors.textPrimary)

                Text("You'll tap this token to lock and unlock apps")
                    .font(CTRLFonts.body())
                    .foregroundColor(CTRLColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            ZStack {
                if showPairSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(CTRLColors.success)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "wave.3.right.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(CTRLColors.accent)
                        .scaleEffect(isPulsing ? 1.1 : 1.0)
                        .opacity(isPulsing ? 0.8 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: isPulsing
                        )
                        .onAppear { isPulsing = true }
                }
            }

            Spacer()

            if let error = scanError {
                Text(error)
                    .font(CTRLFonts.caption())
                    .foregroundColor(CTRLColors.warning)
                    .padding(.bottom, 12)
            }

            Button {
                performPairScan()
            } label: {
                HStack(spacing: 8) {
                    if nfcManager.isScanning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: CTRLColors.background))
                    }
                    Text(nfcManager.isScanning ? "Scanning..." : "Scan Token")
                        .font(CTRLFonts.headline())
                }
                .foregroundColor(CTRLColors.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(showPairSuccess ? CTRLColors.success : CTRLColors.accent)
                .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .disabled(nfcManager.isScanning || showPairSuccess)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Page 3: Select Apps

    private var selectAppsPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Text("Choose Apps to Block")
                    .font(CTRLFonts.largeTitle())
                    .foregroundColor(CTRLColors.textPrimary)

                Text("These apps will be blocked during focus time")
                    .font(CTRLFonts.body())
                    .foregroundColor(CTRLColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 16) {
                Button {
                    showAppPicker = true
                } label: {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                            .font(.title2)
                        Text("Select Apps")
                            .font(CTRLFonts.headline())
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(CTRLFonts.caption())
                            .foregroundColor(CTRLColors.textSecondary)
                    }
                    .foregroundColor(CTRLColors.textPrimary)
                    .padding(16)
                    .background(CTRLColors.cardBackground)
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                Text("\(selectedAppCount) app\(selectedAppCount == 1 ? "" : "s") selected")
                    .font(CTRLFonts.caption())
                    .foregroundColor(selectedAppCount > 0 ? CTRLColors.accent : CTRLColors.textMuted)
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                completeOnboarding()
            } label: {
                Text("Done")
                    .font(CTRLFonts.headline())
                    .foregroundColor(selectedAppCount > 0 ? CTRLColors.background : CTRLColors.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedAppCount > 0 ? CTRLColors.accent : CTRLColors.cardBackground)
                    .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .disabled(selectedAppCount == 0)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Helpers

    private var selectedAppCount: Int {
        appState.selectedApps.applicationTokens.count + appState.selectedApps.categoryTokens.count
    }

    // MARK: - Actions

    private func performPairScan() {
        scanError = nil
        print("[Onboarding] Scan Token tapped, starting NFC scan...")

        nfcManager.scan { result in
            switch result {
            case .success(let tagID):
                print("[Onboarding] Token scanned: \(tagID)")
                appState.pairToken(id: tagID)
                print("[Onboarding] Token paired, isPaired: \(appState.isPaired)")

                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showPairSuccess = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    print("[Onboarding] Advancing to page 2 (Select Apps)")
                    withAnimation {
                        currentPage = 2
                    }
                }

            case .failure(let error):
                print("[Onboarding] Scan failed: \(error.localizedDescription)")
                if case NFCError.userCancelled = error {
                    print("[Onboarding] User cancelled scan")
                    return
                }
                scanError = error.localizedDescription
            }
        }
    }

    private func completeOnboarding() {
        print("[Onboarding] Done tapped")
        print("[Onboarding] Apps selected: \(appState.selectedApps.applicationTokens.count) apps, \(appState.selectedApps.categoryTokens.count) categories")
        print("[Onboarding] isPaired: \(appState.isPaired)")
        print("[Onboarding] hasCompletedOnboarding: \(appState.hasCompletedOnboarding)")
        onComplete()
        print("[Onboarding] onComplete() called — RootView should now switch to HomeView")
    }
}

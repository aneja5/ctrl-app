import SwiftUI

struct SignInOnlyView: View {
    var onComplete: () -> Void

    @EnvironmentObject var appState: AppState
    @State private var email: String = ""
    @State private var code: String = ""
    @State private var step: SignInStep = .email
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum SignInStep {
        case email
        case verify
    }

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            VStack(spacing: 0) {
                // Wordmark
                Text("ctrl")
                    .font(.custom("Georgia", size: 20))
                    .foregroundColor(CTRLColors.textTertiary)
                    .tracking(2)
                    .padding(.top, 60)

                Spacer()

                // Welcome back message
                VStack(spacing: 12) {
                    Text("welcome back")
                        .font(.custom("Georgia", size: 32))
                        .foregroundColor(CTRLColors.textPrimary)

                    Text("sign in to continue")
                        .font(.system(size: 15))
                        .foregroundColor(CTRLColors.textTertiary)
                }

                Spacer()
                    .frame(height: 40)

                // Input based on step
                if step == .email {
                    emailInput
                } else {
                    codeInput
                }

                Spacer()

                // Continue button
                Button(action: handleContinue) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: CTRLColors.base))
                        }
                        Text(isLoading ? (step == .email ? "Sending..." : "Verifying...") : "Continue")
                    }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(CTRLColors.base)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canContinue ? CTRLColors.accent : CTRLColors.surface1)
                .cornerRadius(16)
                .disabled(!canContinue || isLoading)
                .opacity(!canContinue || isLoading ? 0.5 : 1.0)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)

                #if DEBUG
                Button("skip auth (debug)") {
                    appState.userEmail = "dev@getctrl.in"
                    appState.hasCompletedOnboarding = true
                    appState.saveState()
                }
                .font(.system(size: 13))
                .foregroundColor(CTRLColors.textTertiary)
                .padding(.top, 16)
                #endif
            }
        }
    }

    private var emailInput: some View {
        VStack(spacing: 12) {
            TextField("", text: $email, prompt: Text("your@email.com").foregroundColor(CTRLColors.textTertiary))
                .font(CTRLFonts.bodyFont)
                .foregroundColor(CTRLColors.textPrimary)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .disabled(isLoading)
                .padding(CTRLSpacing.md)
                .background(CTRLColors.surface1)
                .cornerRadius(12)
                .padding(.horizontal, 20)

            if let error = errorMessage {
                Text(error)
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.destructive)
            }
        }
    }

    private var codeInput: some View {
        VStack(spacing: 12) {
            Text("enter the code sent to")
                .font(CTRLFonts.bodySmall)
                .foregroundColor(CTRLColors.textTertiary)

            Text(email)
                .font(CTRLFonts.bodyFont)
                .foregroundColor(CTRLColors.textSecondary)

            TextField("", text: $code, prompt: Text("000000").foregroundColor(CTRLColors.textTertiary))
                .font(.system(size: 24, weight: .medium, design: .monospaced))
                .foregroundColor(CTRLColors.textPrimary)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .disabled(isLoading)
                .padding(CTRLSpacing.md)
                .background(CTRLColors.surface1)
                .cornerRadius(12)
                .padding(.horizontal, 60)

            if let error = errorMessage {
                Text(error)
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.destructive)
            }
        }
    }

    private var canContinue: Bool {
        if step == .email {
            return email.contains("@") && email.contains(".")
        } else {
            return code.count == 6
        }
    }

    private func handleContinue() {
        errorMessage = nil
        isLoading = true

        Task {
            do {
                if step == .email {
                    try await SupabaseManager.shared.sendOTP(email: email)
                    await MainActor.run {
                        isLoading = false
                        step = .verify
                    }
                } else {
                    try await SupabaseManager.shared.verifyOTP(email: email, code: code)

                    // Set email immediately
                    await MainActor.run {
                        appState.userEmail = email
                        appState.saveState()
                    }

                    // Fetch cloud data after successful sign-in
                    let cloudData = await CloudSyncManager.shared.fetchFromCloud()
                    if let cloudData = cloudData {
                        await MainActor.run {
                            CloudSyncManager.shared.restoreFromCloud(cloudData, into: appState)
                        }
                        if CloudSyncManager.shared.isNewDevice(cloudData: cloudData) {
                            await MainActor.run {
                                appState.isReturningFromNewDevice = true
                                isLoading = false
                                onComplete()
                            }
                            return
                        }
                    }

                    await MainActor.run {
                        isLoading = false
                        onComplete()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

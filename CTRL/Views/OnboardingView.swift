import SwiftUI
import FamilyControls

struct OnboardingView: View {

    // MARK: - Step Enum

    enum Step: Int, CaseIterable {
        case welcome
        case email
        case verify
        case screenTime
        case ready
    }

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var blockingManager: BlockingManager

    // MARK: - Configuration

    var startStep: Step = .welcome

    // MARK: - State

    @State private var currentStep: Step = .welcome
    @State private var email: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    // Verify step state
    @State private var code: String = ""
    @State private var resendCountdown: Int = 0
    @State private var codeShakeOffset: CGFloat = 0
    @FocusState private var isCodeFieldFocused: Bool

    // MARK: - Callback

    var onComplete: () -> Void

    // MARK: - Init

    init(startStep: Step = .welcome, onComplete: @escaping () -> Void) {
        self.startStep = startStep
        self._currentStep = State(initialValue: startStep)
        self.onComplete = onComplete
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            Group {
                switch currentStep {
                case .welcome:
                    welcomeView
                case .email:
                    emailView
                case .verify:
                    verifyView
                case .screenTime:
                    ScreenTimePermissionView {
                        #if DEBUG
                        print("[Onboarding] ScreenTimePermission completed")
                        #endif
                        advance()
                    }
                case .ready:
                    readyView
                }
            }
            .transition(.opacity)
        }
        .animation(.easeOut(duration: 0.4), value: currentStep)
    }

    // MARK: - Navigation

    @State private var isAdvancing = false

    private func advance() {
        // Prevent double-advance from callbacks firing twice
        guard !isAdvancing else {
            #if DEBUG
            print("[Onboarding] Already advancing, skipping duplicate call")
            #endif
            return
        }
        isAdvancing = true

        let allSteps = Step.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex + 1 < allSteps.count else {
            isAdvancing = false
            return
        }
        errorMessage = nil
        var nextStep = allSteps[currentIndex + 1]

        // Skip Screen Time permission step if already granted
        if nextStep == .screenTime && appState.hasScreenTimePermission {
            let skipIndex = allSteps.firstIndex(of: nextStep)!
            if skipIndex + 1 < allSteps.count {
                nextStep = allSteps[skipIndex + 1]
            }
        }

        // Returning user: skip straight to home if they have previous data
        if appState.hasPreviousData {
            if (nextStep == .screenTime && appState.hasScreenTimePermission) || nextStep == .ready {
                #if DEBUG
                print("[Onboarding] Returning user — skipping to home")
                #endif
                onComplete()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isAdvancing = false }
                return
            }
        }

        // Fresh user reaching ready: create default Focus mode
        if nextStep == .ready && appState.modes.isEmpty {
            let mode = BlockingMode(name: "Focus")
            appState.addMode(mode)
            #if DEBUG
            print("[Onboarding] Auto-created default Focus mode")
            #endif
        }

        #if DEBUG
        print("[Onboarding] Advancing: \(currentStep) → \(nextStep)")
        #endif
        currentStep = nextStep

        // Reset after a short delay to allow future advances
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAdvancing = false
        }
    }

    private func goTo(_ step: Step) {
        errorMessage = nil
        currentStep = step
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(spacing: 0) {
            // Wordmark at top
            Text("ctrl")
                .font(CTRLFonts.ritualWhisper)
                .foregroundColor(CTRLColors.textTertiary)
                .tracking(3)
                .padding(.top, CTRLSpacing.xl)

            Spacer()

            // Center content
            VStack(spacing: CTRLSpacing.sm) {
                Text("design your attention")
                    .font(.custom("Georgia", size: 24))
                    .foregroundColor(CTRLColors.textPrimary)

                Text("architecture for focus")
                    .font(CTRLFonts.captionFont)
                    .tracking(2)
                    .foregroundColor(CTRLColors.textTertiary)
            }

            Spacer()

            // Bottom section
            VStack(spacing: CTRLSpacing.lg) {
                Button(action: { advance() }) {
                    Text("continue with email")
                        .font(CTRLFonts.bodyFont)
                        .fontWeight(.medium)
                        .foregroundColor(CTRLColors.base)
                        .frame(maxWidth: .infinity)
                        .frame(height: CTRLSpacing.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                                .fill(CTRLColors.accent)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, CTRLSpacing.screenPadding)

                Text("we'll just verify it's you")
                    .font(.system(size: 12))
                    .foregroundColor(CTRLColors.textTertiary)
                    .padding(.top, 8)

                VStack(spacing: CTRLSpacing.xs) {
                    Text("don't have your ctrl?")
                        .font(CTRLFonts.bodySmall)
                        .foregroundColor(CTRLColors.textTertiary)

                    Button {
                        if let url = URL(string: "https://www.getctrl.in") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("get yours \u{2192}")
                            .font(CTRLFonts.bodySmall)
                            .fontWeight(.medium)
                            .foregroundColor(CTRLColors.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.bottom, CTRLSpacing.xxl)
        }
    }

    // MARK: - Email

    private var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count >= 5
    }

    private var emailView: some View {
        VStack(spacing: 0) {
            // Wordmark at top
            Text("ctrl")
                .font(CTRLFonts.ritualWhisper)
                .foregroundColor(CTRLColors.textTertiary)
                .tracking(3)
                .padding(.top, CTRLSpacing.xl)

            Spacer()

            // Headline
            Text("enter your email")
                .font(.custom("Georgia", size: 24))
                .foregroundColor(CTRLColors.textPrimary)

            Spacer()

            // Email input
            VStack(spacing: CTRLSpacing.sm) {
                ZStack(alignment: .leading) {
                    if email.isEmpty {
                        Text("your@email.com")
                            .font(CTRLFonts.bodyFont)
                            .foregroundColor(CTRLColors.textTertiary)
                            .padding(CTRLSpacing.md)
                    }
                    TextField("", text: $email)
                        .font(CTRLFonts.bodyFont)
                        .foregroundColor(CTRLColors.textPrimary)
                        .tint(CTRLColors.accent)
                        .accentColor(CTRLColors.accent)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .disabled(isLoading)
                        .padding(CTRLSpacing.md)
                }
                .background(
                    RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                        .fill(CTRLColors.surface1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                        .stroke(CTRLColors.border, lineWidth: 1)
                )
                .accentColor(CTRLColors.accent)

                Text("we'll send a code to verify")
                    .font(.system(size: 12))
                    .foregroundColor(CTRLColors.textTertiary)

                if let error = errorMessage {
                    Text(error)
                        .font(CTRLFonts.captionFont)
                        .foregroundColor(CTRLColors.destructive)
                }
            }
            .padding(.horizontal, CTRLSpacing.screenPadding)

            Spacer()

            onboardingButton(isLoading ? "sending..." : "continue", isLoading: isLoading, isDisabled: !isValidEmail || isLoading) {
                sendOTP()
            }

            #if DEBUG
            Button("skip auth (debug)") {
                appState.userEmail = "dev@getctrl.in"

                if appState.hasPreviousData {
                    appState.hasCompletedOnboarding = true
                    appState.saveState()
                } else {
                    currentStep = .screenTime
                }
            }
            .font(.system(size: 13))
            .foregroundColor(CTRLColors.textTertiary)
            .padding(.top, 16)
            #endif
        }
    }

    private func sendOTP() {
        errorMessage = nil
        isLoading = true

        Task {
            do {
                try await SupabaseManager.shared.sendOTP(email: email.trimmingCharacters(in: .whitespaces))
                isLoading = false
                advance()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Verify

    private var fullCode: String {
        code
    }

    private var verifyView: some View {
        VStack(spacing: 0) {
            // Top bar with back button and wordmark
            HStack {
                Button(action: {
                    // Reset verify state and go back to email
                    code = ""
                    errorMessage = nil
                    isLoading = false
                    isVerifying = false
                    goTo(.email)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(CTRLColors.textTertiary)
                        .frame(width: 36, height: 36)
                }
                .disabled(isLoading)

                Spacer()

                Text("ctrl")
                    .font(CTRLFonts.ritualWhisper)
                    .foregroundColor(CTRLColors.textTertiary)
                    .tracking(3)

                Spacer()

                // Invisible spacer to balance the back button
                Color.clear
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal, CTRLSpacing.screenPadding)
            .padding(.top, CTRLSpacing.xl)

            Spacer()

            // Headlines
            VStack(spacing: CTRLSpacing.xs) {
                Text("check your email")
                    .font(.custom("Georgia", size: 24))
                    .foregroundColor(CTRLColors.textPrimary)

                Text("we sent a code to \(email)")
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.textSecondary)
            }

            Spacer()

            // 6-digit code input
            VStack(spacing: CTRLSpacing.lg) {
                // Digit display boxes with hidden TextField overlay
                HStack(spacing: CTRLSpacing.xs) {
                    ForEach(0..<6, id: \.self) { index in
                        OTPDigitBox(
                            digit: getDigit(at: index),
                            isFocused: isCodeFieldFocused && index == code.count
                        )
                        .onTapGesture {
                            isCodeFieldFocused = true
                        }
                    }
                }
                .overlay(
                    TextField("", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($isCodeFieldFocused)
                        .opacity(0.01)
                        .onChange(of: code) { _, newValue in
                            // Filter non-digits
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue {
                                code = filtered
                                return
                            }
                            // Limit to 6 digits
                            if filtered.count > 6 {
                                code = String(filtered.prefix(6))
                            }
                            // Auto-submit when 6 digits entered
                            if code.count == 6 {
                                isCodeFieldFocused = false
                                verifyCode()
                            }
                        }
                )
                .offset(x: codeShakeOffset)
                .padding(.horizontal, CTRLSpacing.screenPadding)
                .disabled(isLoading)

                // Clear button
                if !code.isEmpty {
                    Button(action: {
                        code = ""
                        isCodeFieldFocused = true
                    }) {
                        Text("clear")
                            .font(CTRLFonts.captionFont)
                            .foregroundColor(CTRLColors.textTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                if let error = errorMessage {
                    Text(error)
                        .font(CTRLFonts.captionFont)
                        .foregroundColor(CTRLColors.destructive)
                }

                // Resend link
                Button {
                    resendOTP()
                } label: {
                    if resendCountdown > 0 {
                        Text("resend in 0:\(String(format: "%02d", resendCountdown))")
                            .font(CTRLFonts.bodySmall)
                            .foregroundColor(CTRLColors.textTertiary.opacity(0.5))
                    } else {
                        Text("resend code")
                            .font(CTRLFonts.bodySmall)
                            .foregroundColor(CTRLColors.textTertiary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(resendCountdown > 0 || isLoading)
            }

            Spacer()

            if isLoading {
                onboardingButton("verifying...", isLoading: true, isDisabled: true) { }
            }
        }
        .onAppear {
            isCodeFieldFocused = true
            startResendCountdown()
        }
    }

    private func getDigit(at index: Int) -> String {
        guard index < code.count else { return "" }
        return String(code[code.index(code.startIndex, offsetBy: index)])
    }

    @State private var isVerifying = false

    private func verifyCode() {
        let code = fullCode
        guard code.count == 6 else { return }

        // Prevent double verification from paste + last-digit onChange both firing
        guard !isVerifying else {
            #if DEBUG
            print("[Onboarding] Already verifying, skipping duplicate call")
            #endif
            return
        }
        isVerifying = true

        errorMessage = nil
        isLoading = true

        Task {
            do {
                let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
                try await SupabaseManager.shared.verifyOTP(
                    email: trimmedEmail,
                    code: code
                )

                // Set email before cloud fetch
                await MainActor.run {
                    appState.userEmail = trimmedEmail
                }

                // Fetch cloud data after successful sign-in
                let cloudData = await CloudSyncManager.shared.fetchFromCloud()
                if let cloudData = cloudData {
                    let isNew = CloudSyncManager.shared.isNewDevice(cloudData: cloudData)

                    // Batch all state mutations into a single MainActor.run
                    await MainActor.run {
                        CloudSyncManager.shared.restoreFromCloud(cloudData, into: appState)
                        if isNew {
                            appState.isReturningFromNewDevice = true
                        }
                        appState.markOnboardingComplete()
                        isLoading = false
                        if !isNew {
                            onComplete()
                        }
                    }
                    return
                }

                // No cloud data — first-time user, continue normal flow
                await MainActor.run {
                    isLoading = false
                    advance()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    isVerifying = false  // Allow retry on error
                    errorMessage = error.localizedDescription
                    shakeAndClearCode()
                }
            }
        }
    }

    private func shakeAndClearCode() {
        withAnimation(.default) {
            codeShakeOffset = 12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.default) {
                codeShakeOffset = -10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.default) {
                codeShakeOffset = 6
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.default) {
                codeShakeOffset = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            code = ""
            isCodeFieldFocused = true
        }
    }

    private func startResendCountdown() {
        resendCountdown = 30
        Task {
            while resendCountdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled {
                    resendCountdown -= 1
                }
            }
        }
    }

    private func resendOTP() {
        errorMessage = nil
        isLoading = true

        Task {
            do {
                try await SupabaseManager.shared.sendOTP(email: email.trimmingCharacters(in: .whitespaces))
                isLoading = false
                startResendCountdown()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Ready

    @State private var readyCheckmarkScale: CGFloat = 0.5
    @State private var readyCheckmarkOpacity: Double = 0.0
    @State private var readyGlowOpacity: Double = 0.0

    private var readyView: some View {
        VStack(spacing: 0) {
            // Wordmark at top
            Text("ctrl")
                .font(CTRLFonts.ritualWhisper)
                .foregroundColor(CTRLColors.textTertiary)
                .tracking(3)
                .padding(.top, CTRLSpacing.xl)

            Spacer()

            // Ritual mark — bronze checkmark with glow
            ZStack {
                // Ambient bronze glow
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                CTRLColors.accent.opacity(0.12),
                                CTRLColors.accent.opacity(0.04),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 140
                        )
                    )
                    .frame(width: 320, height: 320)
                    .blur(radius: 40)
                    .opacity(readyGlowOpacity)

                Circle()
                    .stroke(CTRLColors.accent.opacity(0.3), lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .scaleEffect(readyCheckmarkScale)
                    .opacity(readyCheckmarkOpacity)

                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(CTRLColors.accent)
                    .scaleEffect(readyCheckmarkScale)
                    .opacity(readyCheckmarkOpacity)
            }
            .frame(width: 200, height: 200)
            .onAppear {
                withAnimation(.easeIn(duration: 0.6)) {
                    readyGlowOpacity = 1.0
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                    readyCheckmarkScale = 1.0
                    readyCheckmarkOpacity = 1.0
                }
            }

            Spacer()

            // Headlines
            VStack(spacing: CTRLSpacing.xs) {
                Text("you're ready")
                    .font(.custom("Georgia", size: 28))
                    .foregroundColor(CTRLColors.textPrimary)

                Text("tap lock in to begin your first session")
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.textSecondary)
            }

            Spacer()

            Button(action: {
                onComplete()
            }) {
                Text("begin")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(CTRLColors.base)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(CTRLColors.accent)
                    .cornerRadius(16)
            }
            .padding(.horizontal, CTRLSpacing.screenPadding)
            .padding(.bottom, CTRLSpacing.xxl)
        }
    }

    // MARK: - Shared Button

    private func onboardingButton(
        _ title: String,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        isActive: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: CTRLSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: isActive ? CTRLColors.base : CTRLColors.textSecondary))
                }
                Text(title)
                    .font(CTRLFonts.bodyFont)
                    .fontWeight(.medium)
            }
            .foregroundColor(isActive ? CTRLColors.base : CTRLColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: CTRLSpacing.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                    .fill(isActive ? CTRLColors.accent : CTRLColors.surface1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        .padding(.horizontal, CTRLSpacing.screenPadding)
        .padding(.bottom, CTRLSpacing.xxl)
    }

}

// MARK: - OTP Digit Box

private struct OTPDigitBox: View {
    let digit: String
    let isFocused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(CTRLColors.surface1)
                .frame(height: 56)

            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isFocused ? CTRLColors.accent.opacity(0.5) : CTRLColors.border,
                    lineWidth: isFocused ? 1.5 : 1
                )
                .frame(height: 56)

            if digit.isEmpty && isFocused {
                Rectangle()
                    .fill(CTRLColors.accent)
                    .frame(width: 2, height: 24)
                    .blinkingCursor()
            } else {
                Text(digit)
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .foregroundColor(CTRLColors.textPrimary)
            }
        }
    }
}

// MARK: - Blinking Cursor

private extension View {
    func blinkingCursor() -> some View {
        modifier(BlinkingCursorModifier())
    }
}

private struct BlinkingCursorModifier: ViewModifier {
    @State private var isVisible = true

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    isVisible.toggle()
                }
            }
    }
}

import SwiftUI
import FamilyControls

struct OnboardingView: View {

    // MARK: - Step Enum

    enum Step: Int, CaseIterable {
        case splash
        case welcome
        case email
        case verify
        case screenTime
        case modes
        case apps
        case ready
    }

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var blockingManager: BlockingManager

    // MARK: - Configuration

    var startStep: Step = .splash

    // MARK: - State

    @State private var currentStep: Step = .splash
    @State private var email: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    // Splash animation state
    @State private var splashWordmarkOpacity: Double = 0

    // Verify step state
    @State private var codeDigits: [String] = Array(repeating: "", count: 6)
    @State private var resendCountdown: Int = 0
    @State private var codeShakeOffset: CGFloat = 0
    @FocusState private var focusedCodeIndex: Int?

    // Intent / mode name from IntentSelectionView
    @State private var selectedModeName: String = "Focus"

    // MARK: - Callback

    var onComplete: () -> Void

    // MARK: - Init

    init(startStep: Step = .splash, onComplete: @escaping () -> Void) {
        self.startStep = startStep
        self._currentStep = State(initialValue: startStep)
        self.onComplete = onComplete
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            Group {
                #if DEBUG
                let _ = print("[OnboardingView] body evaluated, currentStep: \(currentStep)")
                #endif

                switch currentStep {
                case .splash:
                    splashView
                case .welcome:
                    welcomeView
                case .email:
                    emailView
                case .verify:
                    verifyView
                case .screenTime:
                    ScreenTimePermissionView {
                        print("[Onboarding] ScreenTimePermission completed")
                        advance()
                    }
                case .modes:
                    IntentSelectionView { modeName in
                        print("[Onboarding] IntentSelection chose: \(modeName)")
                        selectedModeName = modeName
                        advance()
                    }
                case .apps:
                    AppSelectionView(
                        modeName: selectedModeName,
                        onBack: { goTo(.modes) },
                        onContinue: { selection in
                            createModeAndAdvance(name: selectedModeName, appSelection: selection)
                        }
                    )
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
            print("[Onboarding] Already advancing, skipping duplicate call")
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
        let nextStep = allSteps[currentIndex + 1]
        print("[Onboarding] Advancing: \(currentStep) → \(nextStep)")
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

    // MARK: - Splash

    private var splashView: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("ctrl")
                .font(.custom("Georgia", size: 28))
                .foregroundColor(CTRLColors.textTertiary)
                .tracking(3)
                .opacity(splashWordmarkOpacity)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                splashWordmarkOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                advance()
            }
        }
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
        codeDigits.joined()
    }

    private var verifyView: some View {
        VStack(spacing: 0) {
            // Wordmark at top
            Text("ctrl")
                .font(CTRLFonts.ritualWhisper)
                .foregroundColor(CTRLColors.textTertiary)
                .tracking(3)
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
                HStack(spacing: CTRLSpacing.xs) {
                    ForEach(0..<6, id: \.self) { index in
                        codeDigitField(index: index)
                    }
                }
                .offset(x: codeShakeOffset)
                .padding(.horizontal, CTRLSpacing.screenPadding)
                .disabled(isLoading)

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
            focusedCodeIndex = 0
            startResendCountdown()
        }
    }

    private func codeDigitField(index: Int) -> some View {
        TextField("", text: $codeDigits[index])
            .font(.system(size: 28, weight: .light, design: .monospaced))
            .foregroundColor(CTRLColors.textPrimary)
            .tint(CTRLColors.accent)
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($focusedCodeIndex, equals: index)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(CTRLColors.surface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        focusedCodeIndex == index ? CTRLColors.accent.opacity(0.5) : CTRLColors.border,
                        lineWidth: focusedCodeIndex == index ? 1.5 : 1
                    )
            )
            .onChange(of: codeDigits[index]) { oldValue, newValue in
                handleDigitChange(index: index, oldValue: oldValue, newValue: newValue)
            }
    }

    private func handleDigitChange(index: Int, oldValue: String, newValue: String) {
        // Only allow digits
        let filtered = newValue.filter { $0.isNumber }

        if filtered.count > 1 {
            // Pasted full code or multiple digits
            let digits = Array(filtered.prefix(6))
            for i in 0..<6 {
                codeDigits[i] = i < digits.count ? String(digits[i]) : ""
            }
            if digits.count >= 6 {
                focusedCodeIndex = nil
                verifyCode()
            } else {
                focusedCodeIndex = digits.count
            }
            return
        }

        if filtered != newValue {
            codeDigits[index] = filtered
        }

        if filtered.count == 1 {
            // Advance to next field
            if index < 5 {
                focusedCodeIndex = index + 1
            } else {
                // Last digit filled — auto-submit
                focusedCodeIndex = nil
                verifyCode()
            }
        } else if filtered.isEmpty && oldValue.count == 1 {
            // Deleted — go back
            if index > 0 {
                focusedCodeIndex = index - 1
            }
        }
    }

    @State private var isVerifying = false

    private func verifyCode() {
        let code = fullCode
        guard code.count == 6 else { return }

        // Prevent double verification from paste + last-digit onChange both firing
        guard !isVerifying else {
            print("[Onboarding] Already verifying, skipping duplicate call")
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
                await MainActor.run {
                    appState.userEmail = trimmedEmail
                    appState.saveState()
                    isLoading = false
                    advance()
                    // Don't reset isVerifying — we've moved on
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
            codeDigits = Array(repeating: "", count: 6)
            focusedCodeIndex = 0
        }
    }

    private func startResendCountdown() {
        resendCountdown = 30
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                timer.invalidate()
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

    private func createModeAndAdvance(name: String, appSelection: FamilyActivitySelection) {
        // Guard against duplicate creation (SwiftUI can re-invoke callbacks)
        guard !appState.modes.contains(where: { $0.name.lowercased() == name.lowercased() }) else {
            print("[Onboarding] Mode '\(name)' already exists, skipping creation")
            advance()
            return
        }

        // Create the mode with selected apps and add it
        let mode = BlockingMode(name: name, appSelection: appSelection)
        appState.addMode(mode)
        appState.saveSelectedApps(appSelection)

        advance()
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

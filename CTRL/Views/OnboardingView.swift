import SwiftUI
import FamilyControls

struct OnboardingView: View {

    // MARK: - Step Enum

    enum Step: Int, CaseIterable {
        case splash
        case welcome
        case email
        case verify
        case pair
        case apps
        case modes
        case ready
    }

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var blockingManager: BlockingManager
    @StateObject private var nfcManager = NFCManager()

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

    // Pair token animation state
    @State private var pairRingScale: CGFloat = 1.0
    @State private var pairRingOpacity: Double = 0.6
    @State private var pairOuterScale: CGFloat = 1.0
    @State private var pairOuterOpacity: Double = 0.3
    @State private var pairGlowOpacity: Double = 0.0
    @State private var pairSuccessScale: CGFloat = 0.5
    @State private var showPairSuccess: Bool = false

    // App picker state
    @State private var showAppPicker = false
    @State private var pickerSelection = FamilyActivitySelection()

    // Modes step state
    @State private var modeName: String = ""

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
                switch currentStep {
                case .splash:
                    splashView
                case .welcome:
                    welcomeView
                case .email:
                    emailView
                case .verify:
                    verifyView
                case .pair:
                    pairView
                case .apps:
                    appsView
                case .modes:
                    modesView
                case .ready:
                    readyView
                }
            }
            .transition(.opacity)
        }
        .animation(.easeOut(duration: 0.4), value: currentStep)
        .familyActivityPicker(
            isPresented: $showAppPicker,
            selection: $pickerSelection
        )
        .onChange(of: pickerSelection) {
            appState.saveSelectedApps(pickerSelection)
        }
    }

    // MARK: - Navigation

    private func advance() {
        let allSteps = Step.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex + 1 < allSteps.count else { return }
        errorMessage = nil
        currentStep = allSteps[currentIndex + 1]
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

                Text("ARCHITECTURE FOR FOCUS")
                    .font(CTRLFonts.captionFont)
                    .tracking(2)
                    .foregroundColor(CTRLColors.textTertiary)
            }

            Spacer()

            // Bottom section
            VStack(spacing: CTRLSpacing.lg) {
                Button(action: { advance() }) {
                    Text("Continue with Email")
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

                VStack(spacing: CTRLSpacing.xs) {
                    Text("Don't have a token?")
                        .font(CTRLFonts.bodySmall)
                        .foregroundColor(CTRLColors.textTertiary)

                    Button {
                        if let url = URL(string: "https://www.getctrl.in") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Get yours \u{2192}")
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
                TextField("", text: $email, prompt: Text("your@email.com").foregroundColor(CTRLColors.textTertiary))
                    .font(CTRLFonts.bodyFont)
                    .foregroundColor(CTRLColors.textPrimary)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(CTRLSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                            .fill(CTRLColors.surface1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                            .stroke(CTRLColors.border, lineWidth: 1)
                    )

                if let error = errorMessage {
                    Text(error)
                        .font(CTRLFonts.captionFont)
                        .foregroundColor(CTRLColors.destructive)
                }
            }
            .padding(.horizontal, CTRLSpacing.screenPadding)

            Spacer()

            onboardingButton("Continue", isLoading: isLoading, isDisabled: !isValidEmail || isLoading) {
                sendOTP()
            }
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

                if let error = errorMessage {
                    Text(error)
                        .font(CTRLFonts.captionFont)
                        .foregroundColor(CTRLColors.destructive)
                }

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: CTRLColors.accent))
                }

                // Resend link
                Button {
                    resendOTP()
                } label: {
                    if resendCountdown > 0 {
                        Text("resend code (0:\(String(format: "%02d", resendCountdown)))")
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
            Spacer()
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

    private func verifyCode() {
        let code = fullCode
        guard code.count == 6 else { return }

        errorMessage = nil
        isLoading = true

        Task {
            do {
                let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
                try await SupabaseManager.shared.verifyOTP(
                    email: trimmedEmail,
                    code: code
                )
                appState.userEmail = trimmedEmail
                appState.saveState()
                isLoading = false
                advance()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                shakeAndClearCode()
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

    // MARK: - Pair Token

    private var pairView: some View {
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
                Text("pair your token")
                    .font(.custom("Georgia", size: 24))
                    .foregroundColor(CTRLColors.textPrimary)

                Text("Hold your CTRL token near the top of your iPhone")
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, CTRLSpacing.screenPadding)

            Spacer()

            // Ritual mark icon with bronze glow
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
                    .opacity(pairGlowOpacity)

                if showPairSuccess {
                    // Success state — bronze checkmark
                    Circle()
                        .stroke(CTRLColors.accent.opacity(0.4), lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .scaleEffect(pairSuccessScale)

                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .light))
                        .foregroundColor(CTRLColors.accent)
                        .scaleEffect(pairSuccessScale)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Idle / scanning — breathing rings + flame
                    Circle()
                        .stroke(CTRLColors.accent.opacity(pairOuterOpacity), lineWidth: 1)
                        .frame(width: 160, height: 160)
                        .scaleEffect(pairOuterScale)

                    Circle()
                        .stroke(CTRLColors.accent.opacity(pairRingOpacity), lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .scaleEffect(pairRingScale)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(CTRLColors.accent)
                        .opacity(pairRingOpacity + 0.2)
                }
            }
            .frame(width: 200, height: 200)
            .onAppear { startPairAnimations() }

            Spacer()

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(CTRLFonts.captionFont)
                    .foregroundColor(CTRLColors.destructive)
                    .padding(.bottom, CTRLSpacing.sm)
                    .padding(.horizontal, CTRLSpacing.screenPadding)
            }

            // Bottom section
            VStack(spacing: CTRLSpacing.lg) {
                onboardingButton(
                    nfcManager.isScanning ? "Scanning..." : "Pair Token",
                    isLoading: nfcManager.isScanning,
                    isDisabled: nfcManager.isScanning || showPairSuccess
                ) {
                    performPairScan()
                }

                Button {
                    if let url = URL(string: "https://www.getctrl.in") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("I don't have a token yet \u{2192}")
                        .font(CTRLFonts.bodySmall)
                        .foregroundColor(CTRLColors.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, CTRLSpacing.md)
            }
        }
    }

    // MARK: - Select Apps

    @State private var hasRequestedScreenTime: Bool = false

    private var appsView: some View {
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
                Text("choose apps to block")
                    .font(.custom("Georgia", size: 24))
                    .foregroundColor(CTRLColors.textPrimary)

                Text("Select which apps you want to restrict\nduring focus sessions")
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, CTRLSpacing.screenPadding)

            Spacer()

            // App selection area
            VStack(spacing: CTRLSpacing.lg) {
                if selectedAppCount > 0 {
                    // Selected state — show count with checkmark
                    VStack(spacing: CTRLSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(CTRLColors.accent)

                        Text("\(selectedAppCount) app\(selectedAppCount == 1 ? "" : "s") selected")
                            .font(CTRLFonts.bodyFont)
                            .foregroundColor(CTRLColors.accent)
                    }

                    // Edit selection button
                    Button {
                        showAppPicker = true
                    } label: {
                        Text("Edit Selection")
                            .font(CTRLFonts.bodySmall)
                            .foregroundColor(CTRLColors.textTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Empty state — prompt to select
                    onboardingButton("Select Apps") {
                        requestScreenTimeAndShowPicker()
                    }
                }
            }

            Spacer()

            // Continue button (only when apps selected)
            if selectedAppCount > 0 {
                onboardingButton("Continue") {
                    advance()
                }
            }
        }
    }

    private func requestScreenTimeAndShowPicker() {
        if hasRequestedScreenTime {
            showAppPicker = true
            return
        }

        Task {
            let authorized = await blockingManager.requestAuthorization()
            appState.isAuthorized = authorized
            hasRequestedScreenTime = true
            showAppPicker = true
        }
    }

    // MARK: - Modes

    private var modesView: some View {
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
                Text("name your first mode")
                    .font(.custom("Georgia", size: 24))
                    .foregroundColor(CTRLColors.textPrimary)

                Text("you can create more modes later in settings")
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.textSecondary)
            }

            Spacer()

            // Mode name input
            TextField("", text: $modeName, prompt: Text("e.g., focus, study, sleep").foregroundColor(CTRLColors.textTertiary))
                .font(CTRLFonts.bodyFont)
                .foregroundColor(CTRLColors.textPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(CTRLSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                        .fill(CTRLColors.surface1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                        .stroke(CTRLColors.border, lineWidth: 1)
                )
                .padding(.horizontal, CTRLSpacing.screenPadding)

            Spacer()

            // Bottom section
            VStack(spacing: CTRLSpacing.lg) {
                onboardingButton(
                    "Create Mode",
                    isDisabled: modeName.trimmingCharacters(in: .whitespaces).isEmpty
                ) {
                    createModeAndAdvance(name: modeName.trimmingCharacters(in: .whitespaces))
                }

                Button {
                    createModeAndAdvance(name: "Focus")
                } label: {
                    Text("Skip for now")
                        .font(CTRLFonts.bodySmall)
                        .foregroundColor(CTRLColors.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, CTRLSpacing.md)
            }
        }
    }

    private func createModeAndAdvance(name: String) {
        // Clear any existing default modes created by AppState.loadState()
        appState.modes.removeAll()

        // Create the mode with selected apps from previous step
        let mode = BlockingMode(name: name, appSelection: appState.selectedApps)
        appState.modes.append(mode)
        appState.setActiveMode(id: mode.id)

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

                Text("tap Lock In to begin your first session")
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.textSecondary)
            }

            Spacer()

            onboardingButton("Begin") {
                completeOnboarding()
            }
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

    // MARK: - Helpers

    private var selectedAppCount: Int {
        appState.selectedApps.applicationTokens.count + appState.selectedApps.categoryTokens.count
    }

    // MARK: - Pair Token Animations

    private func startPairAnimations() {
        withAnimation(.easeIn(duration: 0.8)) {
            pairGlowOpacity = 1.0
        }
        withAnimation(
            .easeInOut(duration: 2.4)
            .repeatForever(autoreverses: true)
        ) {
            pairRingScale = 1.08
            pairRingOpacity = 0.9
        }
        withAnimation(
            .easeInOut(duration: 3.2)
            .repeatForever(autoreverses: true)
        ) {
            pairOuterScale = 1.15
            pairOuterOpacity = 0.15
        }
    }

    // MARK: - Actions

    private func performPairScan() {
        errorMessage = nil

        nfcManager.scan { result in
            switch result {
            case .success(let tagID):
                // Save token to AppState
                appState.pairToken(id: tagID)

                // Haptic success feedback
                let successHaptic = UINotificationFeedbackGenerator()
                successHaptic.notificationOccurred(.success)

                // Bronze flash on glow
                withAnimation(.easeIn(duration: 0.15)) {
                    pairGlowOpacity = 1.5
                }
                withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
                    pairGlowOpacity = 0.8
                }

                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showPairSuccess = true
                    pairSuccessScale = 1.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    advance()
                }

            case .failure(let error):
                if case NFCError.userCancelled = error {
                    return
                }
                let errorHaptic = UINotificationFeedbackGenerator()
                errorHaptic.notificationOccurred(.error)
                errorMessage = error.localizedDescription
            }
        }
    }

    private func completeOnboarding() {
        appState.markOnboardingComplete()
        onComplete()
    }
}

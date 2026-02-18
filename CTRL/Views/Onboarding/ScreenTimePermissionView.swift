import SwiftUI
import FamilyControls

struct ScreenTimePermissionView: View {
    var onContinue: () -> Void

    @State private var isRequestingPermission = false
    @State private var permissionDenied = false

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
                    .frame(height: 40)

                // Title
                VStack(spacing: 8) {
                    Text("connect to")
                        .font(.custom("Georgia", size: 32))
                        .foregroundColor(CTRLColors.textPrimary)

                    Text("screen time")
                        .font(.custom("Georgia", size: 32))
                        .foregroundColor(CTRLColors.textPrimary)
                }

                Spacer()
                    .frame(height: 40)

                // Info cards
                VStack(spacing: 16) {
                    infoCard(
                        icon: "gearshape",
                        title: "what this enables",
                        description: "screen time lets ctrl pause distracting apps when you lock in. you pick which ones. we just enforce your boundaries."
                    )

                    infoCard(
                        icon: "lock.shield",
                        title: "your privacy",
                        description: "we never see your apps or how you use them. everything stays on your device. always. no exceptions."
                    )

                    infoCard(
                        icon: "sparkles",
                        title: "how it works",
                        description: "tap your ctrl to lock in. tap again to unlock. simple physical boundaries."
                    )
                }
                .padding(.horizontal, 20)

                Spacer()

                // Button
                VStack(spacing: 12) {
                    Button(action: requestPermission) {
                        Text(isRequestingPermission ? "connecting..." : "allow access")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(CTRLColors.base)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(CTRLColors.accent)
                            .cornerRadius(16)
                    }
                    .disabled(isRequestingPermission)

                    if permissionDenied {
                        Text("no rush. you can always enable this in settings.")
                            .font(.system(size: 13))
                            .foregroundColor(CTRLColors.textTertiary)
                            .multilineTextAlignment(.center)

                        Button(action: { onContinue() }) {
                            Text("continue")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(CTRLColors.accent)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Text("you'll see a quick apple prompt next")
                            .font(.system(size: 13))
                            .foregroundColor(CTRLColors.textTertiary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private func infoCard(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(CTRLColors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(CTRLColors.textPrimary)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(CTRLColors.textSecondary)
                    .lineSpacing(2)
            }

            Spacer()
        }
        .padding(16)
        .background(CTRLColors.surface1)
        .cornerRadius(12)
    }

    private func requestPermission() {
        isRequestingPermission = true

        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                await MainActor.run {
                    isRequestingPermission = false
                    onContinue()
                }
            } catch {
                await MainActor.run {
                    isRequestingPermission = false
                    withAnimation(.easeOut(duration: 0.3)) {
                        permissionDenied = true
                    }
                }
            }
        }
    }
}

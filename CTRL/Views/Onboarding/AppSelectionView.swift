import SwiftUI
import FamilyControls

struct AppSelectionView: View {
    let modeName: String
    var onBack: (() -> Void)? = nil
    var onContinue: (FamilyActivitySelection) -> Void

    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            VStack(spacing: 0) {
                // Back button
                HStack {
                    if let onBack = onBack {
                        Button(action: onBack) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .medium))
                                Text("back")
                                    .font(.system(size: 15))
                            }
                            .foregroundColor(CTRLColors.textTertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Title
                VStack(spacing: 8) {
                    Text("let's set up")
                        .font(.custom("Georgia", size: 28))
                        .foregroundColor(CTRLColors.textPrimary)

                    Text(modeName.lowercased())
                        .font(.custom("Georgia", size: 28))
                        .foregroundColor(CTRLColors.accent)
                }
                .padding(.top, 24)

                // Subtitle
                Text("choose apps to pause in this mode")
                    .font(.system(size: 15))
                    .foregroundColor(CTRLColors.textTertiary)
                    .padding(.top, 12)

                Spacer()

                // App count or empty state
                VStack(spacing: 16) {
                    if appCount > 0 {
                        Text("\(appCount)")
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(CTRLColors.textPrimary)

                        Text(appCount == 1 ? "app selected" : "apps selected")
                            .font(.system(size: 15))
                            .foregroundColor(CTRLColors.textTertiary)
                    } else {
                        Text("no apps selected yet")
                            .font(.system(size: 15))
                            .foregroundColor(CTRLColors.textTertiary)
                    }
                }

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    if appCount > 0 {
                        // Continue button (primary)
                        Button(action: {
                            onContinue(selection)
                        }) {
                            Text("continue")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(CTRLColors.base)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(CTRLColors.accent)
                                .cornerRadius(16)
                        }

                        // Edit apps button (secondary)
                        Button(action: { showPicker = true }) {
                            Text("edit apps")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(CTRLColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(CTRLColors.surface1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(CTRLColors.border, lineWidth: 1)
                                )
                                .cornerRadius(16)
                        }
                    } else {
                        // Choose apps button (primary)
                        Button(action: { showPicker = true }) {
                            Text("choose apps")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(CTRLColors.base)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(CTRLColors.accent)
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Footer
                Text("you can edit anytime in settings")
                    .font(.system(size: 13))
                    .foregroundColor(CTRLColors.textTertiary)
                    .padding(.bottom, 32)
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
    }

    private var appCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }
}

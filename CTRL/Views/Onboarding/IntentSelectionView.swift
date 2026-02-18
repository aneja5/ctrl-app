import SwiftUI
import UIKit

struct IntentOption: Identifiable {
    let id: String  // Stable ID based on modeName
    let title: String
    let modeName: String
}

struct IntentSelectionView: View {
    var onContinue: (String) -> Void

    private let options: [IntentOption] = [
        IntentOption(id: "focus", title: "deep work", modeName: "Focus"),
        IntentOption(id: "present", title: "family & friends", modeName: "Present"),
        IntentOption(id: "sleep", title: "wind down", modeName: "Sleep"),
        IntentOption(id: "gym", title: "workout", modeName: "Gym"),
        IntentOption(id: "study", title: "learning", modeName: "Study"),
    ]

    @State private var selectedId: String? = nil

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
                    Text("what do you want")
                        .font(.custom("Georgia", size: 28))
                        .foregroundColor(CTRLColors.textPrimary)

                    Text("to protect first?")
                        .font(.custom("Georgia", size: 28))
                        .foregroundColor(CTRLColors.textPrimary)
                }

                Spacer()
                    .frame(height: 12)

                Text("your first mode. add more later.")
                    .font(.system(size: 14))
                    .foregroundColor(CTRLColors.textTertiary)

                Spacer()
                    .frame(height: 36)

                // Options
                VStack(spacing: 12) {
                    ForEach(options) { option in
                        intentRow(option: option)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Continue
                VStack(spacing: 12) {
                    Button(action: {
                        if let sel = selectedId,
                           let opt = options.first(where: { $0.id == sel }) {
                            onContinue(opt.modeName)
                        }
                    }) {
                        Text(selectedId == nil ? "pick one to continue" : "continue")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedId == nil ? CTRLColors.textSecondary : CTRLColors.base)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(selectedId == nil ? CTRLColors.surface1 : CTRLColors.accent)
                            .cornerRadius(16)
                    }
                    .disabled(selectedId == nil)
                    .animation(.easeOut(duration: 0.2), value: selectedId)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private func intentRow(option: IntentOption) -> some View {
        let isSelected = selectedId == option.id

        return Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            withAnimation(.easeOut(duration: 0.15)) {
                selectedId = option.id
            }
        }) {
            HStack {
                Text(option.title)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? CTRLColors.textPrimary : CTRLColors.textSecondary)

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? CTRLColors.accent : CTRLColors.textTertiary.opacity(0.4), lineWidth: isSelected ? 0 : 1.5)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(CTRLColors.accent)
                            .frame(width: 22, height: 22)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(CTRLColors.base)
                    }
                }
            }
            .padding(16)
            .background(isSelected ? CTRLColors.accent.opacity(0.08) : CTRLColors.surface1)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? CTRLColors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

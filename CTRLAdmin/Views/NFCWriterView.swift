import SwiftUI
import CoreNFC

struct NFCWriterView: View {
    @StateObject private var nfcWriter = NFCWriterManager()
    @State private var generatedToken: (fullPayload: String, uuid: String, signature: String)?
    @State private var writeStatus: WriteStatus = .idle
    @State private var tokensWrittenThisSession: Int = 0

    enum WriteStatus {
        case idle
        case ready
        case writing
        case success
        case error(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Write Token")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color(hex: "E8E0D8"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Stats row
            HStack(spacing: 12) {
                statCard(value: "\(tokensWrittenThisSession)", label: "THIS SESSION")
                statCard(value: "\(getTotalTokensWritten())", label: "ALL TIME")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            // Center content - Status or Token Info
            VStack(spacing: 16) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: statusIcon)
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(statusColor)
                }

                // Status text
                Text(statusText)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(hex: "E8E0D8"))

                // Token details (if generated)
                if let token = generatedToken {
                    VStack(spacing: 8) {
                        Text(token.uuid)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color(hex: "A89F94"))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text("Signature: \(token.signature)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(hex: "6F675E"))
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                }
            }

            Spacer()

            // Action buttons at bottom
            VStack(spacing: 12) {
                Button(action: generateToken) {
                    Text("Generate New Token")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "14110F"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "A68A64"))
                        .cornerRadius(14)
                }

                Button(action: writeToTag) {
                    HStack(spacing: 8) {
                        Image(systemName: "wave.3.right")
                        Text("Write to NFC Tag")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(generatedToken == nil ? Color(hex: "6F675E") : Color(hex: "E8E0D8"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: "1E1915"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(generatedToken == nil ? Color(hex: "2A241E") : Color(hex: "A68A64"), lineWidth: 1)
                    )
                    .cornerRadius(14)
                }
                .disabled(generatedToken == nil)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .onReceive(nfcWriter.$writeResult) { result in
            guard let result = result else { return }
            handleWriteResult(result)
        }
    }

    // MARK: - Components

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 32, weight: .light))
                .foregroundColor(Color(hex: "E8E0D8"))

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .tracking(1)
                .foregroundColor(Color(hex: "6F675E"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(hex: "1E1915"))
        .cornerRadius(16)
    }

    // MARK: - Status Properties

    private var statusColor: Color {
        switch writeStatus {
        case .idle: return Color(hex: "6F675E")
        case .ready: return Color(hex: "A68A64")
        case .writing: return Color(hex: "A68A64")
        case .success: return Color(hex: "6B8B6A")
        case .error: return Color(hex: "8B5A5A")
        }
    }

    private var statusIcon: String {
        switch writeStatus {
        case .idle: return "wave.3.right"
        case .ready: return "checkmark.circle"
        case .writing: return "antenna.radiowaves.left.and.right"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    private var statusText: String {
        switch writeStatus {
        case .idle: return "Generate a token to begin"
        case .ready: return "Ready to write"
        case .writing: return "Hold NFC tag near iPhone..."
        case .success: return "Token written successfully"
        case .error(let msg): return msg
        }
    }

    // MARK: - Actions

    private func generateToken() {
        generatedToken = CTRLTokenValidator.generateToken()
        writeStatus = .ready
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func writeToTag() {
        guard let token = generatedToken else { return }
        writeStatus = .writing
        nfcWriter.write(payload: token.fullPayload)
    }

    private func handleWriteResult(_ result: NFCWriteResult) {
        switch result {
        case .success:
            writeStatus = .success
            tokensWrittenThisSession += 1
            saveTokenToHistory()
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Reset after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                writeStatus = .idle
                generatedToken = nil
            }

        case .failure(let error):
            writeStatus = .error(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func saveTokenToHistory() {
        guard let token = generatedToken else { return }

        var history = getTokenHistory()
        let entry = TokenHistoryEntry(
            uuid: token.uuid,
            fullPayload: token.fullPayload,
            createdAt: Date()
        )
        history.insert(entry, at: 0)

        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "token_history")
        }

        let total = UserDefaults.standard.integer(forKey: "total_tokens_written") + 1
        UserDefaults.standard.set(total, forKey: "total_tokens_written")
    }

    private func getTokenHistory() -> [TokenHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: "token_history"),
              let history = try? JSONDecoder().decode([TokenHistoryEntry].self, from: data) else {
            return []
        }
        return history
    }

    private func getTotalTokensWritten() -> Int {
        UserDefaults.standard.integer(forKey: "total_tokens_written")
    }
}

import SwiftUI
import CoreNFC

struct TokenVerifyView: View {
    @StateObject private var nfcReader = NFCVerifyManager()
    @State private var verificationResult: VerificationResult?

    enum VerificationResult {
        case valid(String)
        case invalid(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title at top
            Text("Verify")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color(hex: "E8E0D8"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Card fills middle
            resultCard
                .padding(.horizontal, 20)
                .padding(.top, 20)

            Spacer(minLength: 20)

            // Button at bottom
            Button(action: scanTag) {
                HStack(spacing: 8) {
                    Image(systemName: "wave.3.right")
                    Text("Scan & Verify Token")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "14110F"))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: "A68A64"))
                .cornerRadius(14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .onReceive(nfcReader.$scannedPayload) { payload in
            guard let payload = payload else { return }
            verifyToken(payload: payload)
        }
    }

    private var resultCard: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: resultIcon)
                .font(.system(size: 56, weight: .light))
                .foregroundColor(resultColor)

            Text(resultTitle)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(hex: "E8E0D8"))

            Text(resultSubtitle)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "6F675E"))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "1E1915"))
        .cornerRadius(20)
    }

    private var resultIcon: String {
        switch verificationResult {
        case .none: return "shield.lefthalf.filled"
        case .valid: return "checkmark.shield.fill"
        case .invalid: return "xmark.shield.fill"
        }
    }

    private var resultColor: Color {
        switch verificationResult {
        case .none: return Color(hex: "6F675E")
        case .valid: return Color(hex: "6B8B6A")
        case .invalid: return Color(hex: "8B5A5A")
        }
    }

    private var resultTitle: String {
        switch verificationResult {
        case .none: return "Scan a Token"
        case .valid: return "Valid CTRL Token"
        case .invalid: return "Invalid Token"
        }
    }

    private var resultSubtitle: String {
        switch verificationResult {
        case .none: return "Check if an NFC tag is genuine"
        case .valid: return "This is an authentic CTRL token"
        case .invalid: return "Not a valid CTRL token"
        }
    }

    private func scanTag() {
        verificationResult = nil
        nfcReader.scan()
    }

    private func verifyToken(payload: String) {
        let (isValid, tokenID) = CTRLTokenValidator.validate(payload: payload)

        if isValid, let tokenID = tokenID {
            verificationResult = .valid(tokenID)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            verificationResult = .invalid("Signature verification failed")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

// MARK: - NFC Verify Manager

class NFCVerifyManager: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    @Published var scannedPayload: String?

    private var session: NFCNDEFReaderSession?

    func scan() {
        guard NFCNDEFReaderSession.readingAvailable else { return }

        scannedPayload = nil
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = "Hold NFC tag near iPhone to verify"
        session?.begin()
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard let record = messages.first?.records.first else { return }

        if let payload = extractText(from: record) {
            DispatchQueue.main.async {
                self.scannedPayload = payload
            }
        }

        session.invalidate()
    }

    private func extractText(from record: NFCNDEFPayload) -> String? {
        guard record.typeNameFormat == .nfcWellKnown,
              let type = String(data: record.type, encoding: .utf8),
              type == "T" else {
            return nil
        }

        let payload = record.payload
        guard payload.count > 0 else { return nil }

        let languageCodeLength = Int(payload[0] & 0x3F)
        guard payload.count > languageCodeLength + 1 else { return nil }

        let textData = payload.subdata(in: (languageCodeLength + 1)..<payload.count)
        return String(data: textData, encoding: .utf8)
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // Handle error if needed
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        #if DEBUG
        print("[NFCVerify] Session active")
        #endif
    }
}

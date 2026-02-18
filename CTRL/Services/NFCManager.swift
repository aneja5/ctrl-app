import CoreNFC
import Combine
import UIKit

class NFCManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isScanning: Bool = false
    @Published var lastTagID: String?
    @Published var errorMessage: String?

    // MARK: - Computed Properties

    var isAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    // MARK: - Private Properties

    private var session: NFCNDEFReaderSession?
    private var completionHandler: ((Result<String, Error>) -> Void)?
    private let feedbackGenerator = UINotificationFeedbackGenerator()

    // MARK: - Lifecycle

    deinit {
        session?.invalidate()
        session = nil
        completionHandler = nil
    }

    // MARK: - Public Methods

    func scan(completion: @escaping (Result<String, Error>) -> Void) {
        guard isAvailable else {
            completion(.failure(NFCError.notAvailable))
            return
        }

        feedbackGenerator.prepare()
        completionHandler = completion

        session = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: true
        )
        session?.alertMessage = "hold your ctrl near the top of your iphone"

        isScanning = true
        errorMessage = nil
        session?.begin()
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCManager: NFCNDEFReaderSessionDelegate {

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        print("NFC session became active")
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isScanning = false
            self?.session = nil
        }

        let nfcError = error as? NFCReaderError

        // Handle user cancellation gracefully (not an error)
        if nfcError?.code == .readerSessionInvalidationErrorUserCanceled {
            DispatchQueue.main.async { [weak self] in
                self?.completionHandler?(.failure(NFCError.userCancelled))
                self?.completionHandler = nil
            }
            return
        }

        // Handle timeout gracefully
        if nfcError?.code == .readerSessionInvalidationErrorSessionTimeout {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Session timed out. Please try again."
                self?.completionHandler?(.failure(NFCError.timeout))
                self?.completionHandler = nil
            }
            return
        }

        // Handle first read invalidation (expected behavior)
        if nfcError?.code == .readerSessionInvalidationErrorFirstNDEFTagRead {
            return
        }

        // Handle other errors
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = error.localizedDescription
            self?.completionHandler?(.failure(error))
            self?.completionHandler = nil
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Not used when connecting to tags directly
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found")
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.completionHandler?(.failure(error))
                    self.completionHandler = nil
                }
                return
            }

            tag.queryNDEFStatus { status, capacity, error in
                if let error = error {
                    session.invalidate(errorMessage: "Failed to query tag: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.completionHandler?(.failure(error))
                        self.completionHandler = nil
                    }
                    return
                }

                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Tag is not NDEF compatible")
                    DispatchQueue.main.async {
                        self.completionHandler?(.failure(NFCError.notSupported))
                        self.completionHandler = nil
                    }

                case .readOnly, .readWrite:
                    tag.readNDEF { message, error in
                        if let error = error, (error as? NFCReaderError)?.code != .ndefReaderSessionErrorZeroLengthMessage {
                            session.invalidate(errorMessage: "Failed to read tag")
                            DispatchQueue.main.async {
                                self.completionHandler?(.failure(error))
                                self.completionHandler = nil
                            }
                            return
                        }

                        // Extract text payload from NDEF message
                        guard let payload = self.extractTextPayload(from: message) else {
                            session.invalidate(errorMessage: "couldn't read your ctrl. try again.")
                            DispatchQueue.main.async {
                                self.completionHandler?(.failure(NFCError.invalidTag))
                                self.completionHandler = nil
                            }
                            return
                        }

                        // Validate the ctrl signature
                        let (isValid, tagID) = CTRLTokenValidator.validate(payload: payload)

                        guard isValid, let tagID = tagID else {
                            session.invalidate(errorMessage: "couldn't read your ctrl. try again.")
                            DispatchQueue.main.async {
                                self.feedbackGenerator.notificationOccurred(.error)
                                self.completionHandler?(.failure(NFCError.invalidTag))
                                self.completionHandler = nil
                            }
                            return
                        }

                        // Valid ctrl — provide success haptic
                        DispatchQueue.main.async {
                            self.feedbackGenerator.notificationOccurred(.success)
                        }

                        session.alertMessage = "success!"
                        session.invalidate()

                        DispatchQueue.main.async {
                            self.lastTagID = tagID
                            self.isScanning = false
                            self.completionHandler?(.success(tagID))
                            self.completionHandler = nil
                        }
                    }

                @unknown default:
                    session.invalidate(errorMessage: "Unknown tag status")
                    DispatchQueue.main.async {
                        self.completionHandler?(.failure(NFCError.unknown))
                        self.completionHandler = nil
                    }
                }
            }
        }
    }
}

// MARK: - Payload Extraction

private extension NFCManager {

    /// Extracts the text string from an NDEF message's first text record.
    func extractTextPayload(from message: NFCNDEFMessage?) -> String? {
        guard let record = message?.records.first else { return nil }

        // Check for well-known text type (RTD "T")
        guard record.typeNameFormat == .nfcWellKnown,
              let type = String(data: record.type, encoding: .utf8),
              type == "T" else {
            return nil
        }

        let payload = record.payload
        guard !payload.isEmpty else { return nil }

        // First byte is the language code length
        let languageCodeLength = Int(payload[0] & 0x3F)
        let textStartIndex = 1 + languageCodeLength

        guard textStartIndex < payload.count else { return nil }

        return String(data: payload[textStartIndex...], encoding: .utf8)
    }
}

// MARK: - NFCError

enum NFCError: LocalizedError {
    case notAvailable
    case userCancelled
    case timeout
    case notSupported
    case invalidTag
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "NFC is not available on this device"
        case .userCancelled:
            return "Scan was cancelled"
        case .timeout:
            return "Session timed out"
        case .notSupported:
            return "Tag is not supported"
        case .invalidTag:
            return "couldn't read your ctrl. try again."
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

import CoreNFC
import Combine
import UIKit
import CryptoKit

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
        session?.alertMessage = "Hold your CTRL token near the top of your iPhone"

        isScanning = true
        errorMessage = nil
        session?.begin()
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCManager: NFCNDEFReaderSessionDelegate {

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

                        // Generate unique tag ID
                        let tagID = self.generateTagID(capacity: capacity, message: message)

                        // Provide haptic feedback
                        DispatchQueue.main.async {
                            self.feedbackGenerator.notificationOccurred(.success)
                        }

                        session.alertMessage = "CTRL token detected!"
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

// MARK: - Tag ID Generation

private extension NFCManager {

    func generateTagID(capacity: Int, message: NFCNDEFMessage?) -> String {
        var dataToHash = Data()

        // Include capacity in hash
        withUnsafeBytes(of: capacity) { bytes in
            dataToHash.append(contentsOf: bytes)
        }

        // Include NDEF payload data if available
        if let message = message {
            for record in message.records {
                dataToHash.append(record.identifier)
                dataToHash.append(record.type)
                dataToHash.append(record.payload)
            }
        }

        // If no payload data, use capacity alone with a salt
        if dataToHash.count <= MemoryLayout<Int>.size {
            let salt = "CTRL-NFC-SALT".data(using: .utf8)!
            dataToHash.append(salt)
        }

        // Generate SHA256 hash
        let hash = SHA256.hash(data: dataToHash)

        // Convert to base64 and take first 24 characters
        let base64 = Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let truncated = String(base64.prefix(24))

        return "CTRL-\(truncated)"
    }
}

// MARK: - NFCError

enum NFCError: LocalizedError {
    case notAvailable
    case userCancelled
    case timeout
    case notSupported
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
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

import Foundation
import CoreNFC
import UIKit

enum NFCWriteResult {
    case success
    case failure(String)
}

class NFCWriterManager: NSObject, ObservableObject {
    @Published var writeResult: NFCWriteResult?

    private var session: NFCNDEFReaderSession?
    private var payloadToWrite: String = ""

    func write(payload: String) {
        guard NFCNDEFReaderSession.readingAvailable else {
            writeResult = .failure("NFC not available on this device")
            return
        }

        payloadToWrite = payload
        writeResult = nil

        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your NFC tag near the top of your iPhone"
        session?.begin()
    }
}

extension NFCWriterManager: NFCNDEFReaderSessionDelegate {

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag detected")
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }

            tag.queryNDEFStatus { status, capacity, error in
                if let error = error {
                    session.invalidate(errorMessage: "Query failed: \(error.localizedDescription)")
                    return
                }

                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Tag is not NDEF compatible")

                case .readOnly:
                    session.invalidate(errorMessage: "Tag is read-only")

                case .readWrite:
                    self.writeToTag(tag, session: session)

                @unknown default:
                    session.invalidate(errorMessage: "Unknown tag status")
                }
            }
        }
    }

    private func writeToTag(_ tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        // Create text payload
        let textPayload = createTextRecord(text: payloadToWrite)
        let message = NFCNDEFMessage(records: [textPayload])

        tag.writeNDEF(message) { [weak self] error in
            if let error = error {
                session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.writeResult = .failure(error.localizedDescription)
                }
            } else {
                session.alertMessage = "✓ Token written successfully!"
                session.invalidate()
                DispatchQueue.main.async {
                    self?.writeResult = .success
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }

    private func createTextRecord(text: String) -> NFCNDEFPayload {
        let language = "en"
        let languageData = language.data(using: .utf8)!
        let textData = text.data(using: .utf8)!

        var payload = Data()
        payload.append(UInt8(languageData.count))
        payload.append(languageData)
        payload.append(textData)

        return NFCNDEFPayload(
            format: .nfcWellKnown,
            type: "T".data(using: .utf8)!,
            identifier: Data(),
            payload: payload
        )
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if let nfcError = error as? NFCReaderError,
           nfcError.code != .readerSessionInvalidationErrorUserCanceled,
           nfcError.code != .readerSessionInvalidationErrorFirstNDEFTagRead {
            DispatchQueue.main.async {
                self.writeResult = .failure(error.localizedDescription)
            }
        }
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        #if DEBUG
        print("[NFCWriter] Session active")
        #endif
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Not used for writing
    }
}

import Foundation
import CryptoKit
import FamilyControls

/// Encrypts and decrypts mode data (including app selections) for cloud sync.
/// Uses ChaChaPoly (AEAD) with a key derived from the user's email + userId.
/// The server never sees decrypted app choices — only an opaque encrypted blob.
enum EncryptionManager {

    // MARK: - Constants

    private static let salt = "CTRL-app-selection-sync-v1"
    private static let info = "mode-encryption"

    // MARK: - Data Model

    /// Intermediate representation for encryption.
    /// Captures mode identity, name, and PropertyList-encoded app selection.
    struct EncryptedModeEntry: Codable {
        let id: UUID
        let name: String
        let appSelectionData: Data  // PropertyList-encoded FamilyActivitySelection
    }

    // MARK: - Encrypt

    /// Encrypts an array of BlockingModes into a base64 string for cloud storage.
    /// Returns nil if encryption fails (caller should proceed without encrypted data).
    static func encryptModes(_ modes: [BlockingMode], email: String, userId: UUID) -> String? {
        do {
            // 1. Convert BlockingModes to EncryptedModeEntries
            let entries: [EncryptedModeEntry] = modes.compactMap { mode in
                guard let appData = try? PropertyListEncoder().encode(mode.appSelection) else {
                    #if DEBUG
                    print("[Encryption] Failed to PropertyList-encode appSelection for mode '\(mode.name)'")
                    #endif
                    return nil
                }
                return EncryptedModeEntry(id: mode.id, name: mode.name, appSelectionData: appData)
            }

            // 2. JSON-encode the entries array
            let jsonData = try JSONEncoder().encode(entries)

            // 3. Derive key and encrypt
            let key = deriveKey(email: email, userId: userId)
            let sealedBox = try ChaChaPoly.seal(jsonData, using: key)

            // 4. Return base64-encoded combined representation
            let base64 = sealedBox.combined.base64EncodedString()

            #if DEBUG
            print("[Encryption] Encrypted \(entries.count) modes (\(base64.count) chars)")
            #endif

            return base64
        } catch {
            #if DEBUG
            print("[Encryption] Encrypt failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - Decrypt

    /// Decrypts a base64 string back into BlockingModes with app selections.
    /// Returns nil if decryption fails (caller should fall back to name-only restore).
    static func decryptModes(_ base64String: String, email: String, userId: UUID) -> [BlockingMode]? {
        do {
            // 1. Base64 decode
            guard let combinedData = Data(base64Encoded: base64String) else {
                #if DEBUG
                print("[Encryption] Invalid base64 string")
                #endif
                return nil
            }

            // 2. Open sealed box
            let sealedBox = try ChaChaPoly.SealedBox(combined: combinedData)
            let key = deriveKey(email: email, userId: userId)
            let decryptedData = try ChaChaPoly.open(sealedBox, using: key)

            // 3. JSON decode entries
            let entries = try JSONDecoder().decode([EncryptedModeEntry].self, from: decryptedData)

            // 4. Convert back to BlockingModes
            let modes: [BlockingMode] = entries.map { entry in
                let appSelection: FamilyActivitySelection
                if let decoded = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: entry.appSelectionData) {
                    // Re-apply includeEntireCategory which is lost during deserialization
                    appSelection = decoded.withIncludeEntireCategory()
                } else {
                    #if DEBUG
                    print("[Encryption] Failed to decode appSelection for mode '\(entry.name)', using empty")
                    #endif
                    appSelection = FamilyActivitySelection(includeEntireCategory: true)
                }

                var mode = BlockingMode(name: entry.name, appSelection: appSelection)
                mode.id = entry.id  // Preserve original mode ID
                return mode
            }

            #if DEBUG
            for mode in modes {
                print("[Encryption] Decrypted mode '\(mode.name)' with \(mode.appCount) apps")
            }
            #endif

            return modes
        } catch {
            #if DEBUG
            print("[Encryption] Decrypt failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - Key Derivation

    /// Derives a 256-bit symmetric key from user email + userId using HKDF.
    /// Same email + userId on any device produces the same key.
    private static func deriveKey(email: String, userId: UUID) -> SymmetricKey {
        let inputKeyMaterial = SymmetricKey(data: Data((email.lowercased() + userId.uuidString).utf8))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKeyMaterial,
            salt: Data(salt.utf8),
            info: Data(info.utf8),
            outputByteCount: 32
        )
    }
}

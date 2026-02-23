import Foundation
import CryptoKit

struct CTRLTokenValidator {

    // IMPORTANT: Change this before shipping!
    private static let secretKey = "9417055697"
    private static let tokenPrefix = "CTRL-"

    // MARK: - Validation (Used by both CTRL and CTRLAdmin)

    /// Validates if a scanned NFC payload is a genuine CTRL device
    static func validate(payload: String) -> (isValid: Bool, tokenID: String?) {
        guard payload.hasPrefix(tokenPrefix) else {
            #if DEBUG
            print("[TokenValidator] ❌ Missing CTRL- prefix")
            #endif
            return (false, nil)
        }

        let content = String(payload.dropFirst(tokenPrefix.count))

        guard let lastDashIndex = content.lastIndex(of: "-") else {
            #if DEBUG
            print("[TokenValidator] ❌ Invalid format")
            #endif
            return (false, nil)
        }

        let uuid = String(content[..<lastDashIndex])
        let providedSignature = String(content[content.index(after: lastDashIndex)...])

        guard uuid.count >= 32 else {
            #if DEBUG
            print("[TokenValidator] ❌ UUID too short")
            #endif
            return (false, nil)
        }

        let expectedSignature = computeSignature(for: uuid)

        guard constantTimeCompare(providedSignature.lowercased(), expectedSignature.lowercased()) else {
            #if DEBUG
            print("[TokenValidator] ❌ Signature mismatch")
            #endif
            return (false, nil)
        }

        let fullTokenID = "\(tokenPrefix)\(uuid)"
        #if DEBUG
        print("[TokenValidator] ✅ Valid ctrl: \(fullTokenID)")
        #endif
        return (true, fullTokenID)
    }

    // MARK: - Generation (Used by CTRLAdmin only)

    /// Generates a complete payload for writing to NFC
    static func generateToken() -> (fullPayload: String, uuid: String, signature: String) {
        let uuid = UUID().uuidString.lowercased()
        let signature = computeSignature(for: uuid)
        let fullPayload = "\(tokenPrefix)\(uuid)-\(signature)"
        return (fullPayload, uuid, signature)
    }

    // MARK: - Private Helpers

    private static func computeSignature(for uuid: String) -> String {
        let key = SymmetricKey(data: Data(secretKey.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(uuid.utf8), using: key)
        let hexSignature = signature.map { String(format: "%02x", $0) }.joined()
        return String(hexSignature.prefix(16))
    }

    private static func constantTimeCompare(_ a: String, _ b: String) -> Bool {
        guard a.count == b.count else { return false }
        var result: UInt8 = 0
        for (c1, c2) in zip(a.utf8, b.utf8) {
            result |= c1 ^ c2
        }
        return result == 0
    }
}

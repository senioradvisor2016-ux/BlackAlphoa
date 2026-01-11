import Foundation
import CryptoKit

enum BankIdentifier
{
    static func id(for data: Data) -> String
    {
        let digest = SHA256.hash(data: data)
        // Short stable id (12 hex chars) is enough for local keys.
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(12).lowercased()
    }
}


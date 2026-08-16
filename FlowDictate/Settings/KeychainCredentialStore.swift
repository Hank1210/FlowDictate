import Foundation
import Security

enum CredentialStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case let .unexpectedStatus(status):
            "The API key could not be stored securely (Keychain status \(status))."
        case .invalidData:
            "The API key stored in Keychain is invalid."
        }
    }
}

protocol CredentialStoring: Sendable {
    func readAPIKey() throws -> String?
    func saveAPIKey(_ value: String) throws
    func deleteAPIKey() throws
}

struct KeychainCredentialStore: CredentialStoring {
    private let service: String
    private let account = "openai-api-key"

    init(service: String = Bundle.main.bundleIdentifier ?? "de.euler.FlowDictate") {
        self.service = service
    }

    func readAPIKey() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CredentialStoreError.unexpectedStatus(status) }
        guard
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8)
        else { throw CredentialStoreError.invalidData }
        return value
    }

    func saveAPIKey(_ value: String) throws {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(normalized.utf8)
        let update = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw CredentialStoreError.unexpectedStatus(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw CredentialStoreError.unexpectedStatus(updateStatus)
        }
    }

    func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

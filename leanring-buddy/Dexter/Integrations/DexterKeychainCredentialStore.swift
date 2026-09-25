//
//  DexterKeychainCredentialStore.swift
//  leanring-buddy
//

import Foundation
import Security

enum DexterKeychainCredentialStore {
    private static let serviceName = "com.getdexter.integrations.credentials"

    enum KeychainError: Error {
        case encodingFailed
        case unexpectedStatus(OSStatus)
    }

    static func saveUTF8Secret(_ secret: String, account: String) throws {
        let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSecret.isEmpty else {
            try deleteSecret(account: account)
            return
        }
        guard let secretData = trimmedSecret.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try saveSecretData(secretData, account: account)
    }

    static func loadUTF8Secret(account: String) -> String? {
        guard let data = loadSecretData(account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteSecret(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private static func saveSecretData(_ secretData: Data, account: String) throws {
        try? deleteSecret(account: account)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: secretData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    private static func loadSecretData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }
}

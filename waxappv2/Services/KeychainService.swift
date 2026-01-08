//
//  KeychainService.swift
//  waxappv2
//
//  Lightweight Keychain wrapper used as a fallback for the trial start date.
//  Keychain typically survives delete/reinstall on the same device.
//

import Foundation
import Security

enum KeychainService {
    private static let service = Bundle.main.bundleIdentifier ?? "waxappv2"

    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
        case invalidItemData
    }

    static func setString(_ value: String, forKey key: String) throws {
        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        // Simple upsert: delete then add.
        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = query.merging([
            kSecValueData as String: data,
            // Device-only: doesn't roam via iCloud Keychain.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]) { _, new in new }

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func getString(forKey key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidItemData
        }

        return string
    }
}

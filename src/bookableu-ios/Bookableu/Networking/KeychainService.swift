//
//  KeychainService.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 30/03/2025.
//

import Foundation
import Security

/// A native wrapper for secure keychain access using Apple's Security framework
final class KeychainService: Sendable {
    private let service: String
    
    init(service: String? = nil) {
        if let service = service {
            self.service = service
        } else if let configuredService = Configuration.keychainService() {
            self.service = configuredService
        } else {
            // Use bundle identifier as fallback, which is dynamic
            print("⚠️ Keychain service not properly configured. Using bundle identifier as fallback.")
            let bundleID = Bundle.main.bundleIdentifier ?? "com.bookableu.app"
            #if DEBUG
            self.service = "\(bundleID).dev"
            #else
            self.service = bundleID
            #endif
        }
    }
    
    /// Store a value in the keychain
    /// - Parameters:
    ///   - value: String value to store
    ///   - key: Key to store the value under
    /// - Returns: Success flag
    @discardableResult
    func set(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Create query for the keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieve a value from the keychain
    /// - Parameter key: Key to retrieve the value for
    /// - Returns: Stored value or nil
    func get(_ key: String) -> String? {
        // Create query for the keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        // Search for the item
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    /// Remove a value from the keychain
    /// - Parameter key: Key to remove
    /// - Returns: Success flag
    @discardableResult
    func remove(_ key: String) -> Bool {
        // Create query for the keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        // Delete the item
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Remove all values from the keychain for this service
    /// - Returns: Success flag
    @discardableResult
    func removeAll() -> Bool {
        // Create query for the keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        // Delete all items
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

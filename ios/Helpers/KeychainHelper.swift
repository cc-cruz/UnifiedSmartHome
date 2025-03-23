import Foundation
import Security

/// A helper class for managing Keychain operations securely
public class KeychainHelper {
    // MARK: - Singleton
    
    /// Shared instance for convenience
    public static let shared = KeychainHelper()
    
    // MARK: - Properties
    
    /// Service name used for keychain items
    private let serviceName: String
    
    /// Access group for shared keychain access (if needed)
    private let accessGroup: String?
    
    // MARK: - Initializer
    
    /// Initialize with a custom service name and optional access group
    public init(serviceName: String = Bundle.main.bundleIdentifier ?? "com.unifiedsmarthome", accessGroup: String? = nil) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }
    
    // MARK: - Public Methods
    
    /// Save a string value securely in the keychain
    public func saveString(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return saveData(data, for: key)
    }
    
    /// Retrieve a string value from the keychain
    public func getString(for key: String) -> String? {
        guard let data = getData(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Save data securely in the keychain
    public func saveData(_ data: Data, for key: String) -> Bool {
        // First delete any existing item
        deleteItem(for: key)
        
        // Create query dictionary
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Add access group if specified
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Add the item to the keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieve data from the keychain
    public func getData(for key: String) -> Data? {
        // Create query dictionary
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        // Add access group if specified
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Search for the item
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // Return data if found
        if status == errSecSuccess, let data = result as? Data {
            return data
        }
        
        return nil
    }
    
    /// Delete an item from the keychain
    public func deleteItem(for key: String) -> Bool {
        // Create query dictionary
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        // Add access group if specified
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Delete the item
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Check if an item exists in the keychain
    public func hasItem(for key: String) -> Bool {
        return getData(for: key) != nil
    }
    
    /// Update a keychain item
    public func updateData(_ data: Data, for key: String) -> Bool {
        // Create query dictionary
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        // Add access group if specified
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Create attributes dictionary for update
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        // Update the item
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        // If item doesn't exist, create it
        if status == errSecItemNotFound {
            return saveData(data, for: key)
        }
        
        return status == errSecSuccess
    }
    
    /// Clear all keychain items for this service
    public func clearAll() -> Bool {
        // Create query dictionary
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        // Add access group if specified
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Delete all items
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
} 
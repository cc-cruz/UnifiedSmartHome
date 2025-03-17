import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    
    private init() {}
    
    // Save data to Keychain
    func save(_ data: Data, service: String, account: String) throws {
        // Create query dictionary
        let query = [
            kSecValueData: data,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword
        ] as CFDictionary
        
        // Delete any existing item
        SecItemDelete(query)
        
        // Add the new item
        let status = SecItemAdd(query, nil)
        
        // Check for errors
        guard status == errSecSuccess else {
            throw KeychainError.saveError(status: status)
        }
    }
    
    // Get data from Keychain
    func get(service: String, account: String) throws -> Data? {
        // Create query dictionary
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as CFDictionary
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        
        // Check for errors
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.readError(status: status)
        }
        
        return result as? Data
    }
    
    // Delete data from Keychain
    func delete(service: String, account: String) throws {
        // Create query dictionary
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword
        ] as CFDictionary
        
        // Delete the item
        let status = SecItemDelete(query)
        
        // Check for errors (ignore "not found" error)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteError(status: status)
        }
    }
    
    // Update data in Keychain
    func update(_ data: Data, service: String, account: String) throws {
        // Create query dictionary
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword
        ] as CFDictionary
        
        // Create update dictionary
        let attributes = [kSecValueData: data] as CFDictionary
        
        // Update the item
        let status = SecItemUpdate(query, attributes)
        
        // Check for errors
        guard status == errSecSuccess else {
            throw KeychainError.updateError(status: status)
        }
    }
}

// Keychain error types
enum KeychainError: Error {
    case saveError(status: OSStatus)
    case readError(status: OSStatus)
    case deleteError(status: OSStatus)
    case updateError(status: OSStatus)
    
    var localizedDescription: String {
        switch self {
        case .saveError(let status):
            return "Failed to save to Keychain: \(status)"
        case .readError(let status):
            return "Failed to read from Keychain: \(status)"
        case .deleteError(let status):
            return "Failed to delete from Keychain: \(status)"
        case .updateError(let status):
            return "Failed to update Keychain: \(status)"
        }
    }
} 
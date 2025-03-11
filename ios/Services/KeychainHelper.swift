import Foundation
import Security

final class KeychainHelper {
    static let standard = KeychainHelper()
    private init() {}
    
    func save<T>(_ data: T, service: String, account: String) where T: Codable {
        do {
            // Convert data to JSON
            let data = try JSONEncoder().encode(data)
            
            // Create query dictionary
            var query = [
                kSecValueData: data,
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
            ] as [CFString: Any]
            
            // Add the access group if any
            
            // Check if item already exists
            let status = SecItemAdd(query as CFDictionary, nil)
            
            if status == errSecDuplicateItem {
                // Item already exists, so update it
                let attributes = [
                    kSecValueData: data
                ] as [CFString: Any]
                
                SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            } else if status != errSecSuccess {
                print("Error saving to Keychain: \(status)")
            }
        } catch {
            print("Error encoding data for Keychain: \(error)")
        }
    }
    
    func read<T>(service: String, account: String, type: T.Type) -> T? where T: Codable {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as [CFString: Any]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                print("Error reading from Keychain: \(status)")
            }
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let item = try decoder.decode(type, from: data)
            return item
        } catch {
            print("Error decoding data from Keychain: \(error)")
            return nil
        }
    }
    
    func delete(service: String, account: String) {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
        ] as [CFString: Any]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Error deleting from Keychain: \(status)")
        }
    }
} 
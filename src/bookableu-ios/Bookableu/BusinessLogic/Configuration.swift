import Foundation

/// Configuration enum that handles environment-specific settings and configuration values.
/// Provides type-safe access to configuration values from the app's Info.plist.
enum Configuration {
    /// Custom error types for configuration-related errors.
    enum Error: Swift.Error {
        case missingKey, invalidValue, emptyValue
    }

    /// Generic method to retrieve configuration values from Info.plist.
    /// - Parameters:
    ///   - key: The key to look up in the Info.plist
    /// - Returns: The configuration value of type T
    /// - Throws: Configuration.Error if the key is missing or the value is invalid
    static func value<T>(for key: String) throws -> T where T: LosslessStringConvertible {
        guard let object = Bundle.main.object(forInfoDictionaryKey: key) else {
            throw Error.missingKey
        }

        switch object {
        case let value as T:
            return value
        case let string as String:
            guard let value = T(string) else { fallthrough }
            return value
        default:
            throw Error.invalidValue
        }
    }
}

// MARK: - Environment Variables
extension Configuration {
    /// The base URL for API requests, configured based on build environment.
    /// - DEBUG: Uses development server URL from DEV_API_BASE_URL
    /// - RELEASE: Uses production server URL from PROD_API_BASE_URL
    /// - Returns: The API base URL or nil if not properly configured
    static func apiBaseURL() -> String? {
#if DEBUG
        do {
            let url = try Configuration.value(for: "DEV_API_BASE_URL") as String
            if url.isEmpty || url.hasPrefix("$(") {
                print("[Configuration] Development API base URL not properly set in build settings")
                return nil
            }
            
            let port = try Configuration.value(for: "DEV_API_BASE_PORT") as String
            if port.isEmpty || port.hasPrefix("$(") {
                print("[Configuration] Development API port not properly set in build settings")
                return nil
            }
            
            // Always add http:// for dev server (prevents double scheme issue)
            let fullUrl = "http://\(url):\(port)"
            print("[Configuration] Using development API base URL: \(fullUrl)")
            return fullUrl
        } catch {
            print("[Configuration] Failed to read development API base URL: \(error)")
            return nil
        }
#else
        do {
            let url = try Configuration.value(for: "PROD_API_BASE_URL") as String
            if url.isEmpty || url.hasPrefix("$(") {
                print("[Configuration] Production API base URL not properly set in build settings")
                return nil
            }
            
            // Always add https:// for prod server (prevents double scheme issue)
            let fullUrl = "https://\(url)"
            print("[Configuration] Using production API base URL: \(fullUrl)")
            return fullUrl
        } catch {
            print("[Configuration] Failed to read production API base URL: \(error)")
            return nil
        }
#endif
    }
    
    /// The keychain service identifier, configured based on build environment.
    /// - DEBUG: Uses development keychain service from DEV_KEYCHAIN_SERVICE
    /// - RELEASE: Uses production keychain service from PROD_KEYCHAIN_SERVICE
    /// - Returns: The keychain service identifier or nil if not properly configured
    static func keychainService() -> String? {
#if DEBUG
        do {
            let service = try Configuration.value(for: "DEV_KEYCHAIN_SERVICE") as String
            if service.isEmpty || service.hasPrefix("$(") {
                print("[Configuration] Development keychain service not properly set in build settings")
                return nil
            }
            return service
        } catch {
            print("[Configuration] Failed to read development keychain service: \(error)")
            return nil
        }
#else
        do {
            let service = try Configuration.value(for: "PROD_KEYCHAIN_SERVICE") as String
            if service.isEmpty || service.hasPrefix("$(") {
                print("[Configuration] Production keychain service not properly set in build settings")
                return nil
            }
            return service
        } catch {
            print("[Configuration] Failed to read production keychain service: \(error)")
            return nil
        }
#endif
    }
} 

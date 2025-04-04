//
//  CustomAPIService.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 10/03/2025.
//  Updated to match Python FastAPI backend

import Foundation
import Combine
import os.log

// MARK: - Configuration

/// Configuration for the CustomAPIService
struct CustomAPIConfig {
    /// Get the base URL for the API
    static var baseURL: String {
        if let configuredURL = Configuration.apiBaseURL() {
            return configuredURL
        } else {
            // Log configuration issue without exposing specific URL
            print("[Configuration] API base URL not properly configured. Please check your configuration.")
            return ""
        }
    }
    
    static let timeout: TimeInterval = 30
}

// MARK: - Error Handling

/// Custom API errors
enum CustomAPIError: Error, LocalizedError, Equatable {
    case invalidURL
    case requestFailed(String)
    case invalidRequest(String)
    case invalidResponse
    case decodingFailed(String)
    case unauthorized
    case notFound
    case serverError(Int)
    case noInternet
    case unknown
    
    static func == (lhs: CustomAPIError, rhs: CustomAPIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL): return true
        case (.invalidResponse, .invalidResponse): return true
        case (.unauthorized, .unauthorized): return true
        case (.notFound, .notFound): return true
        case (.noInternet, .noInternet): return true
        case (.unknown, .unknown): return true
        case (.requestFailed(let lhsMsg), .requestFailed(let rhsMsg)): return lhsMsg == rhsMsg
        case (.invalidRequest(let lhsMsg), .invalidRequest(let rhsMsg)): return lhsMsg == rhsMsg
        case (.decodingFailed(let lhsMsg), .decodingFailed(let rhsMsg)): return lhsMsg == rhsMsg
        case (.serverError(let lhsCode), .serverError(let rhsCode)): return lhsCode == rhsCode
        default: return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed(let error):
            return "Request failed: \(error)"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error)"
        case .unauthorized:
            return "Unauthorized access. Please log in again."
        case .notFound:
            return "Resource not found"
        case .serverError(let code):
            return "Server error with status code: \(code)"
        case .noInternet:
            return "No internet connection"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

// MARK: - API Service

/// Service for handling API requests to the backend
@MainActor
final class CustomAPIService: ObservableObject, Sendable {
    // MARK: Properties
    
    nonisolated let session: URLSession
    private nonisolated let logger = Logger(subsystem: "Bookableu", category: "CustomAPIService")
    private nonisolated let keychain = KeychainService()
    private nonisolated let decoder = JSONDecoder()
    private nonisolated let encoder = JSONEncoder()
    
    @Published var isLoading = false
    
    // MARK: Initialization
    
    nonisolated init(session: URLSession = .shared) {
        // Configure date decoding strategy with flexible options
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // First try ISO8601
            let iso8601Formatter = ISO8601DateFormatter()
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            
            // If ISO8601 fails, try various DateFormatter patterns
            let dateFormats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSZ", 
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd"
            ]
            
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            for format in dateFormats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        encoder.dateEncodingStrategy = .iso8601
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = CustomAPIConfig.timeout
        config.timeoutIntervalForResource = CustomAPIConfig.timeout
        self.session = session
    }
    
    // MARK: - Helper Methods
    
    private nonisolated func getAuthToken() -> String? {
        return keychain.get("authToken")
    }
    
    // MARK: - API Methods
    
    /// Performs a GET request to the specified endpoint
    /// - Parameter endpoint: API endpoint to call
    /// - Returns: Decoded response
    func get<T: Decodable>(endpoint: String) async throws -> T {
        try await performRequest(endpoint: endpoint, method: "GET", body: nil as Data?)
    }
    
    /// Performs a POST request to the specified endpoint
    /// - Parameters:
    ///   - endpoint: API endpoint to call
    ///   - body: Request body
    /// - Returns: Decoded response
    func post<T: Decodable, U: Encodable>(endpoint: String, body: U) async throws -> T {
        try await performRequest(endpoint: endpoint, method: "POST", body: body)
    }
    
    /// Make a PUT request
    /// - Parameters:
    ///   - endpoint: API endpoint
    ///   - body: Request body
    /// - Returns: Decoded response
    func put<T: Codable>(endpoint: String, body: Any) async throws -> T {
        isLoading = true
        defer { isLoading = false }
        
        // Print debugging information to help diagnose URL issues
        print("[Debug] PUT request - Endpoint: \(endpoint)")
        let baseURL = CustomAPIConfig.baseURL
        print("[Debug] PUT request - Base URL value: \(baseURL)")
        
        // Check if the base URL is valid
        if baseURL.isEmpty {
            print("[Error] Configuration Error: Base URL is empty")
            print("[Error] Please set the API URL in your build settings or xcconfig file")
            throw CustomAPIError.invalidURL
        }
        
        // Check for double schemes in BaseURL (http://http:// etc)
        if baseURL.contains("://") && 
           (baseURL.replacingOccurrences(of: "://", with: "").contains("://") ||
            baseURL.hasPrefix("http://http") || 
            baseURL.hasPrefix("https://http")) {
            
            print("[Error] Configuration Error: Base URL has invalid scheme structure: \(baseURL)")
            throw CustomAPIError.invalidURL
        }
        
        // Ensure URL is properly formed by handling both absolute and relative endpoints
        let urlString: String
        if endpoint.starts(with: "http://") || endpoint.starts(with: "https://") {
            urlString = endpoint
            print("[Debug] Using absolute URL: \(urlString)")
        } else {
            // Remove leading slash from endpoint if present
            let cleanEndpoint = endpoint.starts(with: "/") ? String(endpoint.dropFirst()) : endpoint
            
            // Remove trailing slash from base URL if present
            var baseURLCleaned = baseURL
            if baseURLCleaned.hasSuffix("/") {
                baseURLCleaned = String(baseURLCleaned.dropLast())
            }
            
            urlString = "\(baseURLCleaned)/\(cleanEndpoint)"
            print("[Debug] Constructed URL: \(urlString) from base: \(baseURLCleaned) and endpoint: \(endpoint)")
        }
        
        guard let url = URL(string: urlString) else {
            print("[Error] Invalid URL created: \(urlString)")
            print("[Error] Invalid URL: \(urlString)")
            throw CustomAPIError.invalidURL
        }
        
        print("[Debug] Valid URL created: \(url.absoluteString)")
        print("[Debug] Making PUT request to: \(url)")
        print("[Debug] Request body: \(body)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = keychain.get("authToken") {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Convert body to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
        
        // Print the actual JSON being sent
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[Debug] Sending JSON data: \(jsonString)")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CustomAPIError.invalidResponse
            }
            
            // Log response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("[Debug] PUT response from \(endpoint): \(responseString)")
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    // Try to decode with FlexibleDecoder first
                    if let result = FlexibleDecoder.decode(data: data, type: T.self) {
                        print("[Debug] Successfully decoded with FlexibleDecoder")
                        return result
                    }
                    
                    // Fall back to standard decoder
                    let result = try decoder.decode(T.self, from: data)
                    print("[Debug] Successfully decoded with standard decoder")
                    return result
                } catch {
                    print("[Error] Decoding error: \(error)")
                    throw CustomAPIError.decodingFailed(error.localizedDescription)
                }
            case 401:
                throw CustomAPIError.unauthorized
            case 400:
                if let errorString = String(data: data, encoding: .utf8) {
                    print("[Error] Bad request error: \(errorString)")
                    throw CustomAPIError.invalidRequest("Bad request: \(errorString)")
                } else {
                    throw CustomAPIError.invalidRequest("Bad request")
                }
            default:
                throw CustomAPIError.requestFailed("HTTP status code: \(httpResponse.statusCode)")
            }
        } catch {
            print("[Error] PUT request failed: \(error)")
            throw error
        }
    }
    
    /// Performs a DELETE request to the specified endpoint
    /// - Parameter endpoint: API endpoint to call
    /// - Returns: Decoded response
    func delete<T: Decodable>(endpoint: String) async throws -> T {
        try await performRequest(endpoint: endpoint, method: "DELETE", body: nil as Data?)
    }
    
    /// Generic method to perform API requests using async/await
    private func performRequest<T: Decodable, U: Encodable>(endpoint: String, method: String, body: U?) async throws -> T {
        // Print debugging information to help diagnose URL issues
        print("[Debug] API request - Endpoint: \(endpoint)")
        let baseURL = CustomAPIConfig.baseURL
        print("[Debug] API request - Raw Base URL value: \(baseURL)")
        
        // Check if the base URL is valid
        if baseURL.isEmpty {
            print("[Error] Configuration Error: Base URL is empty")
            print("[Error] Please set the API URL in your build settings or xcconfig file")
            throw CustomAPIError.invalidURL
        }
        
        // Check for double schemes in BaseURL (http://http:// etc)
        if baseURL.contains("://") && 
           (baseURL.replacingOccurrences(of: "://", with: "").contains("://") ||
            baseURL.hasPrefix("http://http") || 
            baseURL.hasPrefix("https://http")) {
            
            print("[Error] Configuration Error: Base URL has invalid scheme structure: \(baseURL)")
            throw CustomAPIError.invalidURL
        }
        
        // Original URL construction logic for valid base URLs
        let urlString: String
        if endpoint.starts(with: "http://") || endpoint.starts(with: "https://") {
            urlString = endpoint
            print("[Debug] Using absolute URL: \(urlString)")
        } else {
            // Remove leading slash from endpoint if present
            let cleanEndpoint = endpoint.starts(with: "/") ? String(endpoint.dropFirst()) : endpoint
            
            // Remove trailing slash from base URL if present
            var baseURLCleaned = baseURL
            if baseURLCleaned.hasSuffix("/") {
                baseURLCleaned = String(baseURLCleaned.dropLast())
            }
            
            urlString = "\(baseURLCleaned)/\(cleanEndpoint)"
            print("[Debug] Constructed URL: \(urlString) from base: \(baseURLCleaned) and endpoint: \(endpoint)")
        }
        
        guard let url = URL(string: urlString) else {
            print("[Error] Invalid URL created: \(urlString)")
            logger.error("Invalid URL for endpoint: \(endpoint), formed URL: \(urlString)")
            throw CustomAPIError.invalidURL
        }
        
        print("[Debug] Valid URL created: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = getAuthToken() {
            logger.debug("Using auth token: \(token.prefix(10))...")
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("No auth token available")
            logger.debug("No auth token available")
        }
        
        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                logger.error("Failed to encode request body: \(error.localizedDescription)")
                throw CustomAPIError.requestFailed(error.localizedDescription)
            }
        }
        
        print("[Debug] Making async \(method) request to \(endpoint)")
        logger.debug("Making async \(method) request to \(endpoint)")
        isLoading = true
        
        do {
            defer {
                isLoading = false
            }
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CustomAPIError.invalidResponse
            }
            
            // Log response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Response from \(endpoint): \(responseString)")
                print("[Debug] Raw response from server: \(responseString)")
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    // For empty responses
                    if data.isEmpty {
                        print("[Debug] Empty response received")
                        if let emptyResult = EmptyResponse() as? T {
                            return emptyResult
                        }
                    }
                    
                    // First try with FlexibleDecoder for UserProfile
                    if T.self == UserProfile.self {
                        if let result = FlexibleDecoder.decode(data: data, type: T.self) {
                            return result
                        }
                    }
                    
                    // Try standard decoder
                    return try decoder.decode(T.self, from: data)
                    
                } catch let decodingError {
                    logger.error("Failed to decode response: \(decodingError.localizedDescription)")
                    
                    // Provide detailed error information for debugging
                    if let dataString = String(data: data, encoding: .utf8) {
                        print("[Error] Failed to decode data: \(dataString)")
                        print("[Error] Decoding error details: \(decodingError)")
                        
                        // Try to parse as dictionary for more insight
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("[Debug] JSON structure: \(json.keys)")
                            
                            // If this is a UserProfile and we have enough info, try to create a minimal valid one
                            if T.self == UserProfile.self, 
                               let id = json["id"] as? String ?? (json["id"] as? Int).map({ String($0) }),
                               let email = json["email"] as? String {
                                
                                // Create minimal valid model with required fields
                                let jsonString = """
                                {"id": "\(id)", "email": "\(email)"}
                                """
                                
                                if let minimalData = jsonString.data(using: .utf8),
                                   let minimalModel = try? JSONDecoder().decode(T.self, from: minimalData) {
                                    print("[Debug] Created minimal valid model with required fields")
                                    return minimalModel
                                }
                            }
                        }
                    }
                    
                    throw CustomAPIError.decodingFailed(decodingError.localizedDescription)
                }
            case 401:
                throw CustomAPIError.unauthorized
            case 404:
                throw CustomAPIError.notFound
            case 500...599:
                throw CustomAPIError.serverError(httpResponse.statusCode)
            default:
                throw CustomAPIError.unknown
            }
        } catch {
            if let apiError = error as? CustomAPIError {
                throw apiError
            } else {
                if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                    throw CustomAPIError.noInternet
                }
                logger.error("Request failed: \(error.localizedDescription)")
                throw CustomAPIError.requestFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - File Upload Methods
    
    /// Uploads a file with multipart form data
    /// - Parameters:
    ///   - fileURL: URL of the file to upload
    ///   - endpoint: API endpoint
    ///   - mimeType: MIME type of the file
    ///   - parameters: Additional form parameters
    /// - Returns: Decoded response
    func uploadFile<T: Decodable>(fileURL: URL, endpoint: String, mimeType: String = "application/octet-stream", parameters: [String: String] = [:]) async throws -> T {
        // Check if file exists and can be read
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.error("File not found at path: \(fileURL.path)")
            throw CustomAPIError.invalidRequest("File not found at path: \(fileURL.path)")
        }
        
        // Ensure URL is properly formed by handling both absolute and relative endpoints
        let urlString: String
        if endpoint.starts(with: "http://") || endpoint.starts(with: "https://") {
            urlString = endpoint
        } else {
            // Remove leading slash from endpoint if present
            let cleanEndpoint = endpoint.starts(with: "/") ? String(endpoint.dropFirst()) : endpoint
            
            // Remove trailing slash from base URL if present
            var baseURL = CustomAPIConfig.baseURL
            if baseURL.hasSuffix("/") {
                baseURL = String(baseURL.dropLast())
            }
            
            urlString = "\(baseURL)/\(cleanEndpoint)"
        }
        
        guard let url = URL(string: urlString) else {
            logger.error("Invalid URL for endpoint: \(endpoint), formed URL: \(urlString)")
            throw CustomAPIError.invalidURL
        }
        
        let boundary = UUID().uuidString
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = getAuthToken() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Try/catch for file reading - handle file permission issues
        let fileData: Data
        do {
            // Try to get a security-scoped access if this is a security-scoped URL
            var didStartAccess = false
            if fileURL.startAccessingSecurityScopedResource() {
                didStartAccess = true
            }
            
            // Don't forget to stop accessing
            defer {
                if didStartAccess {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            
            // Try to read the file using multiple strategies
            do {
                // First try with the mapped option which is more efficient for larger files
                fileData = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            } catch {
                // If that fails, try a direct read
                logger.warning("Mapped read failed, trying direct read: \(error.localizedDescription)")
                fileData = try Data(contentsOf: fileURL)
            }
            
            // Check if data is empty
            if fileData.isEmpty {
                throw CustomAPIError.invalidRequest("File is empty")
            }
            
        } catch {
            logger.error("Failed to read file data: \(error.localizedDescription)")
            throw CustomAPIError.requestFailed("Failed to read file data: \(error.localizedDescription)")
        }
        
        var bodyData = Data()
        
        // Add parameters
        for (key, value) in parameters {
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            bodyData.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add file
        let filename = fileURL.lastPathComponent
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        bodyData.append(fileData)
        bodyData.append("\r\n".data(using: .utf8)!)
        
        // Add closing boundary
        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = bodyData
        
        logger.debug("Making file upload request to \(endpoint)")
        isLoading = true
        
        do {
            defer {
                isLoading = false
            }
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CustomAPIError.invalidResponse
            }
            
            // Log response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Response from \(endpoint): \(responseString)")
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    logger.error("Failed to decode upload response: \(error.localizedDescription)")
                    throw CustomAPIError.decodingFailed(error.localizedDescription)
                }
            case 401:
                throw CustomAPIError.unauthorized
            case 404:
                throw CustomAPIError.notFound
            case 500...599:
                throw CustomAPIError.serverError(httpResponse.statusCode)
            default:
                throw CustomAPIError.requestFailed("HTTP status code: \(httpResponse.statusCode)")
            }
        } catch {
            if let apiError = error as? CustomAPIError {
                throw apiError
            } else {
                logger.error("File upload failed: \(error.localizedDescription)")
                throw CustomAPIError.requestFailed("File upload failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Downloads a file from the server
    /// - Parameter endpoint: API endpoint for the file to download
    /// - Returns: File data
    func downloadFile(from endpoint: String) async throws -> Data {
        // Ensure URL is properly formed by handling both absolute and relative endpoints
        let urlString: String
        if endpoint.starts(with: "http://") || endpoint.starts(with: "https://") {
            urlString = endpoint
        } else {
            // Remove leading slash from endpoint if present
            let cleanEndpoint = endpoint.starts(with: "/") ? String(endpoint.dropFirst()) : endpoint
            
            // Remove trailing slash from base URL if present
            var baseURL = CustomAPIConfig.baseURL
            if baseURL.hasSuffix("/") {
                baseURL = String(baseURL.dropLast())
            }
            
            urlString = "\(baseURL)/\(cleanEndpoint)"
        }
        
        guard let url = URL(string: urlString) else {
            logger.error("Invalid URL for endpoint: \(endpoint), formed URL: \(urlString)")
            throw CustomAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = getAuthToken() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        logger.debug("Downloading file from \(endpoint)")
        
        isLoading = true
        
        do {
            defer {
                isLoading = false
            }
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CustomAPIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return data
            case 401:
                throw CustomAPIError.unauthorized
            case 404:
                throw CustomAPIError.notFound
            case 500...599:
                throw CustomAPIError.serverError(httpResponse.statusCode)
            default:
                throw CustomAPIError.requestFailed("HTTP status code: \(httpResponse.statusCode)")
            }
        } catch {
            if let apiError = error as? CustomAPIError {
                throw apiError
            } else if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                throw CustomAPIError.noInternet
            } else {
                logger.error("File download failed: \(error.localizedDescription)")
                throw CustomAPIError.requestFailed("File download failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Performs a PUT request with form data
    /// - Parameters:
    ///   - endpoint: API endpoint
    ///   - parameters: Form parameters
    /// - Returns: Decoded response
    func putWithFormData<T: Decodable>(endpoint: String, parameters: [String: String]) async throws -> T {
        // Ensure URL is properly formed by handling both absolute and relative endpoints
        let urlString: String
        if endpoint.starts(with: "http://") || endpoint.starts(with: "https://") {
            urlString = endpoint
        } else {
            // Remove leading slash from endpoint if present
            let cleanEndpoint = endpoint.starts(with: "/") ? String(endpoint.dropFirst()) : endpoint
            
            // Remove trailing slash from base URL if present
            var baseURL = CustomAPIConfig.baseURL
            if baseURL.hasSuffix("/") {
                baseURL = String(baseURL.dropLast())
            }
            
            urlString = "\(baseURL)/\(cleanEndpoint)"
        }
        
        guard let url = URL(string: urlString) else {
            throw CustomAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        if let token = getAuthToken() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Convert parameters to form data
        let formData = parameters.map { key, value in
            return "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }.joined(separator: "&")
        
        request.httpBody = formData.data(using: .utf8)
        
        isLoading = true
        
        do {
            defer {
                isLoading = false
            }
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CustomAPIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw CustomAPIError.decodingFailed(error.localizedDescription)
                }
            case 401:
                throw CustomAPIError.unauthorized
            case 404:
                throw CustomAPIError.notFound
            case 500...599:
                throw CustomAPIError.serverError(httpResponse.statusCode)
            default:
                throw CustomAPIError.unknown
            }
        } catch {
            if let apiError = error as? CustomAPIError {
                throw apiError
            } else {
                if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                    throw CustomAPIError.noInternet
                }
                throw CustomAPIError.requestFailed(error.localizedDescription)
            }
        }
    }
}

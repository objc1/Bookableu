//
//  UserService.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 10/03/2025.
//  Updated to match Python FastAPI backend

import Foundation
import Combine
import os.log

/// Service for handling user-related API calls
@MainActor
final class UserService: ObservableObject, Sendable {
    private let apiService: CustomAPIService
    private let keychain = KeychainService()
    private let logger = Logger(subsystem: "Bookableu", category: "UserService")
    
    @Published var isLoading = false
    @Published var error: Error?
    
    init(apiService: CustomAPIService = CustomAPIService()) {
        self.apiService = apiService
    }
    
    /// Get current user profile
    /// - Returns: User profile data
    func getCurrentUser() async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // First, get the raw data to debug the response
            let endpoint = "users/me"
            guard let url = URL(string: "\(CustomAPIConfig.baseURL)/\(endpoint)") else {
                throw CustomAPIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let token = keychain.get("authToken") {
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, _) = try await apiService.session.data(for: request)
            
            // Print the raw JSON for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON response for getUserProfile: \(jsonString)")
            }
            
            // Try both approaches for maximum compatibility
            
            // 1. First try with the FlexibleDecoder
            if let user = FlexibleDecoder.decode(data: data, type: UserProfile.self) {
                print("Successfully decoded UserProfile with FlexibleDecoder")
                return user
            }
            
            // 2. Try standard API service method
            do {
                let user: UserProfile = try await apiService.get(endpoint: endpoint)
                return user
            } catch {
                print("Failed to decode with standard API method: \(error)")
                
                // 3. Last resort: try to extract minimal fields manually
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let id = json["id"] as? String ?? (json["id"] as? Int).map({ String($0) }),
                   let email = json["email"] as? String {
                    
                    // Create a minimal valid user profile
                    print("Creating minimal UserProfile from extracted fields")
                    let minimalUser = UserProfile(
                        id: id,
                        email: email,
                        name: json["name"] as? String,
                        profile_picture: json["profile_picture"] as? String,
                        created_at: nil,
                        updated_at: nil,
                        preferences: nil,
                        books_finished: json["books_finished"] as? Int ?? 0,
                        role: json["role"] as? String,
                        is_active: json["is_active"] as? Bool,
                        last_login: nil
                    )
                    return minimalUser
                }
                
                // If we get here, we've tried everything
                throw error
            }
        } catch {
            logger.error("Failed to get user profile: \(error.localizedDescription)")
            self.error = error
            throw error
        }
    }
    
    /// Update user profile
    /// - Parameter name: Updated name
    /// - Returns: Updated user profile
    func updateProfile(name: String) async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Create form data parameters
            var formData = [String: String]()
            formData["name"] = name
            
            print("Attempting to update profile with name: \(name)")
            print("Form data being sent: \(formData)")
            
            // Make the PUT request with form data
            let user: UserProfile = try await apiService.putWithFormData(
                endpoint: "users/me",
                parameters: formData
            )
            
            // Log success
            print("Successfully updated profile name to: \(name)")
            print("Updated user profile: \(user)")
            return user
        } catch {
            print("Failed to update profile: \(error)")
            if let apiError = error as? CustomAPIError {
                print("API Error details: \(apiError.localizedDescription)")
            }
            logger.error("Failed to update profile: \(error.localizedDescription)")
            self.error = error
            throw error
        }
    }
    
    /// Update user profile with picture
    /// - Parameters:
    ///   - name: Updated name
    ///   - imageURL: Local URL of the image file
    /// - Returns: Updated user profile
    func updateProfileWithPicture(name: String, imageURL: URL) async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }
        
        // Determine MIME type based on file extension
        let ext = imageURL.pathExtension.lowercased()
        let mimeType: String
        switch ext {
        case "jpg", "jpeg":
            mimeType = "image/jpeg"
        case "png":
            mimeType = "image/png"
        case "gif":
            mimeType = "image/gif"
        default:
            throw CustomAPIError.invalidRequest("Unsupported image format")
        }
        
        do {
            // Create a multipart form with both the name and picture file
            guard let url = URL(string: "\(CustomAPIConfig.baseURL)/users/me") else {
                throw CustomAPIError.invalidURL
            }
            
            let boundary = UUID().uuidString
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"  // PUT method to match FastAPI route
            request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            if let token = keychain.get("authToken") {
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            // Try to read the file data
            let fileData: Data
            do {
                var didStartAccess = false
                if imageURL.startAccessingSecurityScopedResource() {
                    didStartAccess = true
                }
                
                defer {
                    if didStartAccess {
                        imageURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                fileData = try Data(contentsOf: imageURL)
                
                if fileData.isEmpty {
                    throw CustomAPIError.invalidRequest("File is empty")
                }
            } catch {
                logger.error("Failed to read file data: \(error.localizedDescription)")
                throw CustomAPIError.requestFailed("Failed to read file data: \(error.localizedDescription)")
            }
            
            var bodyData = Data()
            
            // Add name parameter first (matches FastAPI's Form parameter)
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".data(using: .utf8)!)
            bodyData.append("\(name)\r\n".data(using: .utf8)!)
            
            // Add file (matches FastAPI's File parameter named "picture")
            let filename = imageURL.lastPathComponent
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"picture\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            bodyData.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            bodyData.append(fileData)
            bodyData.append("\r\n".data(using: .utf8)!)
            
            // Add closing boundary
            bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = bodyData
            
            // Make the request
            let (data, response) = try await apiService.session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CustomAPIError.invalidResponse
            }
            
            // Debug response
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Profile update response: \(responseString)")
            }
            
            // Handle response status
            switch httpResponse.statusCode {
            case 200...299:
                // Try to decode the user profile from the response
                if let user = FlexibleDecoder.decode(data: data, type: UserProfile.self) {
                    return user
                } else if let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
                    return user
                } else {
                    throw CustomAPIError.decodingFailed("Failed to decode user profile from response")
                }
            case 401:
                throw CustomAPIError.unauthorized
            case 400:
                if let errorString = String(data: data, encoding: .utf8) {
                    throw CustomAPIError.invalidRequest("Bad request: \(errorString)")
                } else {
                    throw CustomAPIError.invalidRequest("Bad request")
                }
            default:
                throw CustomAPIError.requestFailed("HTTP status code: \(httpResponse.statusCode)")
            }
        } catch {
            logger.error("Failed to update profile with picture: \(error.localizedDescription)")
            self.error = error
            throw error
        }
    }
    
    /// Get profile picture URL
    /// - Returns: URL to profile picture
    func getProfilePictureURL() async throws -> URL {
        do {
            let response: [String: String] = try await apiService.get(endpoint: "users/me/picture-url")
            guard let urlString = response["url"],
                  let url = URL(string: urlString) else {
                throw CustomAPIError.invalidResponse
            }
            return url
        } catch {
            logger.error("Failed to get profile picture URL: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Delete user account
    /// - Returns: Success status
    func deleteAccount() async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let _: EmptyResponse = try await apiService.delete(endpoint: "users/me")
            return true
        } catch {
            logger.error("Failed to delete account: \(error.localizedDescription)")
            self.error = error
            throw error
        }
    }
    
    /// Update LLM preferences
    /// - Parameters:
    ///   - model: LLM model name
    ///   - temperature: Temperature parameter (0.0-1.0)
    ///   - maxTokens: Maximum tokens to generate
    ///   - instructionStyle: Instruction style (academic, casual, concise)
    /// - Returns: Updated preferences
    func updateLLMPreferences(
        model: String? = nil,
        temperature: Float? = nil,
        maxTokens: Int? = nil,
        instructionStyle: String? = nil
    ) async throws -> LLMPreferencesResponse {
        isLoading = true
        defer { isLoading = false }
        
        // Create a dictionary for the preferences instead of using struct directly
        var prefsDict: [String: Any] = [:]
        
        if let model = model {
            prefsDict["model"] = model
        }
        if let temperature = temperature {
            prefsDict["temperature"] = temperature
        }
        if let maxTokens = maxTokens {
            prefsDict["max_tokens"] = maxTokens
        }
        if let instructionStyle = instructionStyle {
            prefsDict["instruction_style"] = instructionStyle
        }
        
        do {
            let response: LLMPreferencesResponse = try await apiService.put(
                endpoint: "users/llm-preferences",
                body: prefsDict
            )
            return response
        } catch {
            logger.error("Failed to update LLM preferences: \(error.localizedDescription)")
            self.error = error
            throw error
        }
    }
}

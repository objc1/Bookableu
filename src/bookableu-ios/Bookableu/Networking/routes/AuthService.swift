//
//  AuthService.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 10/03/2025.
//  Updated to match Python FastAPI backend

import Foundation

/// Service for handling authentication-related API calls
@MainActor
final class AuthService: ObservableObject, Sendable {
    private let apiService: CustomAPIService
    private let keychain: KeychainService
    
    @Published var isAuthenticated = false
    @Published var currentUser: UserProfile?
    
    init(apiService: CustomAPIService = CustomAPIService()) {
        self.apiService = apiService
        self.keychain = KeychainService()
        // Check for existing token on init
        checkAuthentication()
    }
    
    private func checkAuthentication() {
        if let token = keychain.get("authToken"), !token.isEmpty {
            isAuthenticated = true
            // Fetch user profile
            Task {
                await fetchCurrentUser()
            }
        }
    }
    
    /// Login user with email and password
    /// - Parameters:
    ///   - email: User email
    ///   - password: User password
    /// - Returns: Authentication response with token
    func login(email: String, password: String) async throws -> Bool {
        let credentials = LoginRequest(email: email, password: password)
        let response: AuthResponse = try await apiService.post(endpoint: "auth/login", body: credentials)
        
        // Save token to keychain
        keychain.set(response.access_token, forKey: "authToken")
        
        // Update authentication state
        isAuthenticated = true
        
        // Fetch user info
        await fetchCurrentUser()
        
        return true
    }
    
    /// Register a new user
    /// - Parameters:
    ///   - email: User email
    ///   - password: User password
    ///   - name: User's full name (optional)
    /// - Returns: Registration status
    func register(email: String, password: String, name: String? = nil) async throws -> Bool {
        let registrationData = RegisterRequest(email: email, password: password, name: name)
        let _: StatusResponse = try await apiService.post(endpoint: "auth/register", body: registrationData)
        
        // After registration, login the user
        return try await login(email: email, password: password)
    }
    
    /// Logout the current user (invalidate token)
    func logout() {
        // Clear token from keychain
        keychain.remove("authToken")
        
        // Update authentication state
        isAuthenticated = false
        currentUser = nil
    }
    
    /// Fetch current user profile
    private func fetchCurrentUser() async {
        print("Attempting to fetch current user...")
        do {
            let userService = UserService(apiService: apiService)
            let user = try await userService.getCurrentUser()
            
            print("Successfully fetched user: \(user.email)")
            currentUser = user
        } catch {
            print("Error fetching user profile: \(error)")
            
            // More detailed error logging
            if let apiError = error as? CustomAPIError {
                switch apiError {
                case .decodingFailed(let message):
                    print("JSON Decoding error: \(message)")
                case .unauthorized:
                    print("Unauthorized - logging out")
                    logout()
                case .invalidResponse:
                    print("Invalid response from server")
                case .serverError(let code):
                    print("Server error with code: \(code)")
                case .noInternet:
                    print("No internet connection detected")
                default:
                    print("Other API error: \(apiError.localizedDescription)")
                }
            } else {
                print("Unknown error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Get the current token
    func getToken() -> String? {
        return keychain.get("authToken")
    }
}

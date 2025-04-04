import SwiftUI
import Combine

/// A class that manages user authentication state and profile information throughout the app.
/// It acts as a central point for handling user authentication and profile data.
@MainActor
class UserProvider: ObservableObject {
    /// Indicates whether the user is currently authenticated
    @Published var isAuthenticated = false
    
    /// Contains the current user's profile information if authenticated
    @Published var currentUser: UserProfile?
    
    private let authService = AuthService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to authentication state changes from AuthService
        // This ensures the UserProvider stays in sync with the actual authentication state
        authService.$isAuthenticated
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)
        
        // Subscribe to user profile updates from AuthService
        // This keeps the current user information up to date
        authService.$currentUser
            .assign(to: \.currentUser, on: self)
            .store(in: &cancellables)
    }
    
    /// Authenticates a user with their email and password
    /// - Parameters:
    ///   - email: The user's email address
    ///   - password: The user's password
    /// - Throws: An error if authentication fails
    func login(email: String, password: String) async throws {
        _ = try await authService.login(email: email, password: password)
    }
    
    /// Registers a new user with the provided credentials
    /// - Parameters:
    ///   - email: The user's email address
    ///   - password: The user's password
    ///   - name: Optional name of the user
    /// - Throws: An error if registration fails
    func register(email: String, password: String, name: String?) async throws {
        _ = try await authService.register(email: email, password: password, name: name)
    }
    
    /// Logs out the current user and clears their session
    func logout() {
        authService.logout()
    }
} 

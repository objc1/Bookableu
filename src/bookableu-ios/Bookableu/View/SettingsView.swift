//
//  SettingsView.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 20/02/2025.
//

import SwiftUI
import SwiftData
import PhotosUI

struct SettingsView: View {
    // MARK: - Properties
    
    // Environment
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProvider: UserProvider
    
    // State
    @State private var activeAlert: AlertType? = nil
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var isEditingProfile: Bool = false
    @State private var selectedProfileImage: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var profileImageData: Data?
    @State private var isLoadingProfileImage: Bool = false
    @State private var showSaveErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var isSavingProfile: Bool = false
    @State private var showEmptyNameError: Bool = false
    
    // Feedback
    private let hapticFeedback = UINotificationFeedbackGenerator()
    
    // MARK: - Alert Types
    
    enum AlertType: Identifiable {
        case logout
        
        var id: Int {
            switch self {
            case .logout: return 1
            }
        }
    }
    
    // MARK: - Navigation Types
    enum NavigationDestination: Hashable {
        case readingStats
        case readingPreferences
        case libraryManagement
        case about
    }
    
    // Navigation state
    @State private var navigationPath = NavigationPath()
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Form {
                // Profile Section
                profileSection
                
                // Reading & Library Section
                Section(header: Text("Reading & Library")) {
                    Button {
                        navigationPath.append(NavigationDestination.readingStats)
                    } label: {
                        Label("Reading Statistics", systemImage: "chart.bar")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        navigationPath.append(NavigationDestination.readingPreferences)
                    } label: {
                        Label("Reading Preferences", systemImage: "book")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        navigationPath.append(NavigationDestination.libraryManagement)
                    } label: {
                        Label("Library Management", systemImage: "folder")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                // About Section
                Section(header: Text("About")) {
                    Button {
                        navigationPath.append(NavigationDestination.about)
                    } label: {
                        Label("About This App", systemImage: "info.circle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .refreshable {
                await refreshUserProfile()
                hapticFeedback.notificationOccurred(.success)
            }
            .navigationTitle("Settings")
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .readingStats:
                    ReadingStatsView()
                case .readingPreferences:
                    ReadingPreferencesView()
                case .libraryManagement:
                    LibraryManagementView()
                case .about:
                    AboutView()
                }
            }
            .alert(item: $activeAlert) { alertType in
                createAlert(for: alertType)
            }
            .alert("Error Saving Profile", isPresented: $showSaveErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Invalid Name", isPresented: $showEmptyNameError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a valid name")
            }
            .onAppear {
                // Only load user profile if needed on initial view
                if profileImage == nil || profileImageData == nil {
                    loadUserProfileFromCache()
                }
            }
        }
    }
    
    // MARK: - UI Sections
    
    private var profileSection: some View {
        Section {
            if !isEditingProfile {
                profileDisplayView
            } else {
                profileEditView
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
    
    private var profileDisplayView: some View {
        Group {
            // Profile display mode
            HStack(spacing: 12) {
                profileImageView
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(userProvider.currentUser?.name ?? "Guest User")
                        .font(.body)
                        .fontWeight(.medium)
                    Text(userProvider.currentUser?.email ?? "Not signed in")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    isEditingProfile = true
                    initProfileEdits()
                } label: {
                    Text("Edit")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 6)
            
            Button(action: {
                hapticFeedback.notificationOccurred(.warning)
                activeAlert = .logout
            }) {
                HStack {
                    Text("Sign Out")
                        .font(.footnote)
                    Spacer()
                    Image(systemName: "arrow.right.square")
                        .font(.footnote)
                }
                .foregroundColor(.red)
            }
            .padding(.vertical, 6)
        }
    }
    
    private var profileEditView: some View {
        Group {
            // Profile image edit
            HStack(spacing: 12) {
                if isLoadingProfileImage {
                    ProgressView()
                        .frame(width: 80, height: 80)
                } else {
                    profileImageView
                }
                
                PhotosPicker(selection: $selectedProfileImage, matching: .images) {
                    Text("Change Photo")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
                .onChange(of: selectedProfileImage) { _, newItem in
                    loadSelectedImage(newItem)
                }
            }
            .padding(.vertical, 6)
            
            // Name field
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Enter your name", text: $displayName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isSavingProfile)
            }
            .padding(.vertical, 6)
            
            // Email display (non-editable)
            VStack(alignment: .leading, spacing: 4) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(email)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            
            // Action buttons
            HStack {
                Button("Cancel") {
                    isEditingProfile = false
                    resetProfileEdits()
                }
                .font(.footnote)
                .foregroundColor(.blue)
                .disabled(isSavingProfile)
                
                Spacer()
                
                if isSavingProfile {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Button("Save") {
                        saveProfile()
                    }
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 6)
        }
    }
    
    private var profileImageView: some View {
        Group {
            if isLoadingProfileImage {
                ProgressView()
                    .frame(width: 80, height: 80)
            } else if let profileImage = profileImage {
                profileImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(.systemGray5), lineWidth: 1))
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createAlert(for alertType: AlertType) -> Alert {
        switch alertType {
        case .logout:
            return Alert(
                title: Text("Sign Out"),
                message: Text("Are you sure you want to sign out?"),
                primaryButton: .destructive(Text("Sign Out")) {
                    userProvider.logout()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func loadSelectedImage(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        Task {
            isLoadingProfileImage = true
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    if let uiImage = UIImage(data: data) {
                        // Resize image before saving to reduce upload size
                        let resizedImage = resizeImage(uiImage, targetSize: CGSize(width: 300, height: 300))
                        let resizedData = resizedImage.jpegData(compressionQuality: 0.7)
                        
                        await MainActor.run {
                            profileImage = Image(uiImage: resizedImage)
                            profileImageData = resizedData
                            isLoadingProfileImage = false
                        }
                    } else {
                        throw NSError(domain: "ImageProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                    }
                }
            } catch {
                await MainActor.run {
                    print("Failed to load image: \(error.localizedDescription)")
                    errorMessage = "Failed to load image: \(error.localizedDescription)"
                    showSaveErrorAlert = true
                    isLoadingProfileImage = false
                }
            }
        }
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Use the smaller scale factor to ensure the image fits within the target size
        let scaleFactor = min(widthRatio, heightRatio)
        
        let scaledSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let scaledImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
        
        return scaledImage
    }
    
    // MARK: - Profile Management
    
    /// New method that combines refreshUserData and loadUserProfile for the pull-to-refresh action
    private func refreshUserProfile() async {
        do {
            // Fetch fresh data from the server to ensure we have the latest
            let userService = UserService(apiService: CustomAPIService())
            let freshUserData = try await userService.getCurrentUser()
            
            await MainActor.run {
                // Update the UserProvider with the fresh data
                userProvider.currentUser = freshUserData
                
                // Now populate the UI fields from the fresh data
                displayName = freshUserData.name ?? ""
                email = freshUserData.email
            }
            
            // Load profile image if available
            if let profilePictureURL = freshUserData.profile_picture, !profilePictureURL.isEmpty {
                await MainActor.run {
                    isLoadingProfileImage = true
                }
                
                do {
                    let imageURL = try await userService.getProfilePictureURL()
                    
                    // Download the image data
                    let (data, _) = try await URLSession.shared.data(from: imageURL)
                    if let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            profileImage = Image(uiImage: uiImage)
                            profileImageData = data
                            isLoadingProfileImage = false
                        }
                    } else {
                        throw NSError(domain: "ProfileImage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                    }
                } catch {
                    print("Failed to load profile image: \(error)")
                    await MainActor.run {
                        isLoadingProfileImage = false
                    }
                }
            }
        } catch {
            print("Error refreshing user profile: \(error)")
            // Fall back to using the cached user data if we can't fetch fresh data
            await MainActor.run {
                if let user = userProvider.currentUser {
                    displayName = user.name ?? ""
                    email = user.email
                }
            }
        }
    }
    
    /// Loads user profile from cached data without making API calls
    private func loadUserProfileFromCache() {
        if let user = userProvider.currentUser {
            displayName = user.name ?? ""
            email = user.email
            
            // If we need to load the profile image and have a URL, load it asynchronously
            if (profileImage == nil || profileImageData == nil), 
               let profilePictureURL = user.profile_picture, 
               !profilePictureURL.isEmpty {
                Task {
                    isLoadingProfileImage = true
                    do {
                        let userService = UserService(apiService: CustomAPIService())
                        let imageURL = try await userService.getProfilePictureURL()
                        
                        // Download the image data
                        let (data, _) = try await URLSession.shared.data(from: imageURL)
                        if let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                profileImage = Image(uiImage: uiImage)
                                profileImageData = data
                                isLoadingProfileImage = false
                            }
                        } else {
                            throw NSError(domain: "ProfileImage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                        }
                    } catch {
                        print("Failed to load profile image: \(error)")
                        await MainActor.run {
                            isLoadingProfileImage = false
                        }
                    }
                }
            }
        }
    }
    
    private func initProfileEdits() {
        if let user = userProvider.currentUser {
            displayName = user.name ?? ""
            email = user.email
            // We don't need to reload the image here as it's already loaded in loadUserProfile
        }
    }
    
    private func resetProfileEdits() {
        selectedProfileImage = nil
        loadUserProfileFromCache() // This will reset everything to match the current user
    }
    
    private func saveProfile() {
        // Validate inputs
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showEmptyNameError = true
            return
        }
        
        // Set loading state
        isSavingProfile = true
        
        Task {
            do {
                print("Attempting to update profile with name: \(trimmedName)")
                
                let userService = UserService(apiService: CustomAPIService())
                var updatedUser: UserProfile

                // Check if we have a profile image to upload
                if let imageData = profileImageData, selectedProfileImage != nil {
                    // Only update image if a new one was selected
                    // Create a temporary file for the image
                    let tempDir = FileManager.default.temporaryDirectory
                    let tempFileURL = tempDir.appendingPathComponent(UUID().uuidString + ".jpg")
                    
                    do {
                        // Write to file
                        try imageData.write(to: tempFileURL)
                        
                        print("Updating profile with picture and name: \(trimmedName)")
                        // Upload both name and image at once
                        updatedUser = try await userService.updateProfileWithPicture(
                            name: trimmedName,
                            imageURL: tempFileURL
                        )
                        
                        // Clean up temp file
                        try? FileManager.default.removeItem(at: tempFileURL)
                    } catch {
                        throw NSError(domain: "ProfileUpdate", code: 2, 
                                     userInfo: [NSLocalizedDescriptionKey: "Failed to process image: \(error.localizedDescription)"])
                    }
                } else {
                    // Just update the profile name if no new image
                    print("Updating profile with name only: \(trimmedName)")
                    updatedUser = try await userService.updateProfile(
                        name: trimmedName
                    )
                }
                
                print("Profile update response: \(updatedUser)")
                
                // Update local user data
                await MainActor.run {
                    // Force update the current user with the new data
                    var updatedLocalUser = updatedUser
                    // Make sure the name is actually updated locally
                    if updatedLocalUser.name != trimmedName {
                        updatedLocalUser.name = trimmedName
                    }
                    
                    userProvider.currentUser = updatedLocalUser
                    
                    // Successfully updated, reset editing state
                    isEditingProfile = false
                    isSavingProfile = false
                    
                    // Force reload the profile only if image was updated
                    if selectedProfileImage != nil {
                        selectedProfileImage = nil
                        // Force refresh everything
                        Task {
                            await refreshUserProfile()
                        }
                    } else {
                        // Just refresh the text data
                        displayName = trimmedName
                        selectedProfileImage = nil
                    }
                    
                    hapticFeedback.notificationOccurred(.success)
                }
                
            } catch let error as NSError {
                print("Profile update error (NSError): \(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showSaveErrorAlert = true
                    isSavingProfile = false
                    hapticFeedback.notificationOccurred(.error)
                }
            } catch {
                print("Profile update error: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to save profile: \(error.localizedDescription)"
                    showSaveErrorAlert = true
                    isSavingProfile = false
                    hapticFeedback.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environmentObject(UserProvider())
}

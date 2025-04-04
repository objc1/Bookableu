import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var userProvider: UserProvider
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Logo or app title
                Image(systemName: "book.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                    .padding(.bottom, 20)
                
                Text("Bookableu")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 30)
                
                // Form fields
                VStack(spacing: 15) {
                    if !isLoginMode {
                        TextField("Name", text: $name)
                            .textContentType(.name)
                            .autocapitalization(.words)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    SecureField("Password", text: $password)
                        .textContentType(isLoginMode ? .password : .newPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Action button
                Button(action: performAction) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isLoginMode ? "Sign In" : "Create Account")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                .disabled(isLoading)
                
                // Switch mode button
                Button(action: {
                    withAnimation {
                        isLoginMode.toggle()
                    }
                }) {
                    Text(isLoginMode ? "Don't have an account? Sign Up" : "Already have an account? Sign In")
                        .foregroundColor(.blue)
                        .padding(.top, 10)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle(isLoginMode ? "Sign In" : "Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func performAction() {
        guard validateInputs() else { return }
        
        isLoading = true
        
        Task {
            do {
                if isLoginMode {
                    try await userProvider.login(email: email, password: password)
                } else {
                    try await userProvider.register(email: email, password: password, name: name)
                }
                
                // Success - reset form and switch to main app
                DispatchQueue.main.async {
                    // The app should automatically navigate to the main view
                    // since we're observing the isAuthenticated state in the app
                    isLoading = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func validateInputs() -> Bool {
        // Trim whitespace
        email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        password = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate email format
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        
        if email.isEmpty {
            alertMessage = "Please enter your email address"
            showingAlert = true
            return false
        }
        
        if !emailPred.evaluate(with: email) {
            alertMessage = "Please enter a valid email address"
            showingAlert = true
            return false
        }
        
        if password.isEmpty {
            alertMessage = "Please enter your password"
            showingAlert = true
            return false
        }
        
        if !isLoginMode && password.count < 8 {
            alertMessage = "Password must be at least 8 characters"
            showingAlert = true
            return false
        }
        
        if !isLoginMode && name.isEmpty {
            alertMessage = "Please enter your name"
            showingAlert = true
            return false
        }
        
        return true
    }
}

#Preview {
    AuthView()
        .environmentObject(UserProvider())
} 
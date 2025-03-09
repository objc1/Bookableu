import SwiftUI

struct AboutView: View {
    // Fetch app version dynamically
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (Build \(build))"
    }
    
    @State private var isAnimating = false // For animation
    private let oldFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let newFeedbackGenerator = UINotificationFeedbackGenerator()
    
    // Function to trigger haptic feedback
    private func triggerHapticFeedback() {
        oldFeedbackGenerator.impactOccurred()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // GeometryReader ensures layout remains stable
            GeometryReader { geometry in
                Image("Icon") // Ensure this matches the asset name
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .shadow(radius: 5)
                    .scaleEffect(isAnimating ? 0.9 : 1.0) // Pulsating effect
                    .position(x: geometry.size.width / 2, y: 100) // Fixed position
                    .accessibilityLabel("Bookableu App Icon")
                    .onTapGesture {
                        triggerHapticFeedback() // Trigger vibration on tap
                    }
            }
            .frame(height: 200) // Prevents shifting when scaling

            // App Title and Version
            VStack(spacing: 8) {
                Text("Bookableu")
                    .font(.title.bold())
                    .foregroundColor(.primary)
                
                Text(appVersion)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .accessibilityElement(children: .combine) // Combine for screen readers
            
            // Description
            Text("A modern book reading app built with SwiftUI.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge) // Support larger text sizes
            
            Spacer()

            // Additional Info
            VStack(spacing: 12) {
                Link("Contact Support", destination: URL(string: "mailto:support@bookableu.com")!)
                    .font(.footnote)
                    .foregroundColor(.blue)
                    .accessibilityHint("Opens email client to contact support")
                
                Link("Privacy Policy", destination: URL(string: "https://bookableu.com/privacy")!)
                    .font(.footnote)
                    .foregroundColor(.blue)
                    .accessibilityHint("Opens privacy policy in browser")
                
                Text("Developed with ♥️ by Maxim Leypunskiy")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            .padding(.top, 10)
        }
        .padding(.vertical, 20)
        .navigationTitle("About")
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}

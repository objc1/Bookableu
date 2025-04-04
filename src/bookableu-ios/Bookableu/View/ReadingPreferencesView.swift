//
//  ReadingPreferencesView.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 20/03/2025.
//

import SwiftUI

struct ReadingPreferencesView: View {
    // MARK: - Properties
    
    // State for reading preferences
    @State private var noSpoilers = true
    
    // State for LLM Preferences
    @State private var selectedModel: String = "gpt-4o"
    @State private var temperature: Float = 0.7
    @State private var maxTokens: Int = 1000
    @State private var instructionStyle: String = "concise"
    @State private var isUpdatingLLMPreferences: Bool = false
    @State private var showLLMUpdateError: Bool = false
    @State private var llmErrorMessage: String = ""
    
    // Services
    private let hapticFeedback = UINotificationFeedbackGenerator()
    
    // MARK: - Body
    
    var body: some View {
        Form {
            // Reading Experience Section
            Section(header: Text("Reading Experience")) {
                Toggle("No spoilers", isOn: $noSpoilers)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: noSpoilers) { _, newValue in
                        // Save the preference to UserDefaults
                        UserDefaults.standard.set(newValue, forKey: "noSpoilers")
                        hapticFeedback.notificationOccurred(.success)
                    }
            }
            
            // AI Assistant Section
            Section(header: Text("AI Assistant")) {
                // Model selection
                Picker("Model", selection: $selectedModel) {
                    Text("GPT-4o").tag("gpt-4o")
                    Text("GPT-3.5 Turbo").tag("gpt-3.5-turbo")
                    Text("Claude 3").tag("claude-3")
                }
                .pickerStyle(MenuPickerStyle())
                
                // Temperature slider
                VStack(alignment: .leading) {
                    HStack {
                        Text("Temperature: \(String(format: "%.1f", temperature))")
                        Spacer()
                    }
                    
                    Slider(value: $temperature, in: 0.0...1.0, step: 0.1)
                }
                
                // Max tokens stepper
                Stepper("Max Tokens: \(maxTokens)", value: $maxTokens, in: 100...1000, step: 50)
                
                // Instruction style
                Picker("Instruction Style", selection: $instructionStyle) {
                    Text("Concise").tag("concise")
                    Text("Academic").tag("academic")
                    Text("Casual").tag("casual")
                }
                .pickerStyle(MenuPickerStyle())
                
                // Save button
                HStack {
                    Spacer()
                    Button(action: updateLLMPreferences) {
                        if isUpdatingLLMPreferences {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Save AI Preferences")
                                .font(.footnote)
                                .fontWeight(.medium)
                        }
                    }
                    .disabled(isUpdatingLLMPreferences)
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding(.top, 5)
            }
            
            // Help Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About these settings")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    Text("• No spoilers: When enabled, the AI will avoid revealing plot twists and major developments when answering questions about books.")
                        .font(.caption)
                    
                    Text("• Model: Different AI models offer varying capabilities and response styles.")
                        .font(.caption)
                    
                    Text("• Temperature: Higher values (closer to 1.0) make responses more creative but less predictable. Lower values make responses more focused and deterministic.")
                        .font(.caption)
                    
                    Text("• Max Tokens: Controls the maximum length of responses.")
                        .font(.caption)
                    
                    Text("• Instruction Style: Sets the tone and formality of AI responses.")
                        .font(.caption)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Reading Preferences")
        .alert("Error Updating AI Preferences", isPresented: $showLLMUpdateError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(llmErrorMessage)
        }
        .onAppear {
            loadPreferences()
        }
    }
    
    // MARK: - Methods
    
    private func loadPreferences() {
        // Load No Spoilers setting
        noSpoilers = UserDefaults.standard.bool(forKey: "noSpoilers")
        
        // Load LLM preferences
        let defaults = UserDefaults.standard
        
        selectedModel = defaults.string(forKey: "llm_model") ?? "gpt-4o"
        
        temperature = defaults.float(forKey: "llm_temperature")
        if temperature == 0 { temperature = 0.7 } // Default if not set
        
        maxTokens = defaults.integer(forKey: "llm_max_tokens")
        if maxTokens == 0 { maxTokens = 100 } // Default if not set
        
        instructionStyle = defaults.string(forKey: "llm_instruction_style") ?? "concise"
    }
    
    private func updateLLMPreferences() {
        isUpdatingLLMPreferences = true
        
        Task {
            do {
                let userService = UserService(apiService: CustomAPIService())
                let response = try await userService.updateLLMPreferences(
                    model: selectedModel,
                    temperature: temperature,
                    maxTokens: maxTokens,
                    instructionStyle: instructionStyle
                )
                
                if response.success {
                    // Save to UserDefaults for local persistence
                    let defaults = UserDefaults.standard
                    defaults.set(selectedModel, forKey: "llm_model")
                    defaults.set(temperature, forKey: "llm_temperature")
                    defaults.set(maxTokens, forKey: "llm_max_tokens")
                    defaults.set(instructionStyle, forKey: "llm_instruction_style")
                    
                    await MainActor.run {
                        isUpdatingLLMPreferences = false
                        hapticFeedback.notificationOccurred(.success)
                    }
                } else {
                    throw NSError(domain: "LLMPreferences", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to update preferences"])
                }
            } catch {
                await MainActor.run {
                    llmErrorMessage = "Failed to update AI preferences: \(error.localizedDescription)"
                    showLLMUpdateError = true
                    isUpdatingLLMPreferences = false
                    hapticFeedback.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        ReadingPreferencesView()
    }
} 

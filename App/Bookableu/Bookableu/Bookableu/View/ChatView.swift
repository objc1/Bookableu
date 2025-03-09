//
//  ChatView.swift
//  BookableuV2
//
//  Created by Maxim Leypunskiy on 20/02/2025.
//

import SwiftUI

struct ChatView: View {
    let book: Book // The book to chat about
    @State private var messages: [Message] = [] // Chat history
    @State private var inputText = "" // User input
    @State private var isLoading = false // Loading state
    @State private var errorMessage: String? // Error feedback
    @Environment(\.dismiss) private var dismiss // For dismissing the view
    
    // API service with Mistral integration
    @StateObject private var apiService = APIService(apiKey: "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") // Assumes API key is in UserDefaults
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
                .onChange(of: messages) {
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Error Message
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .transition(.opacity)
            }
            
            // Loading Indicator
            if isLoading {
                ProgressView("Processing...")
                    .padding(.vertical, 8)
                    .transition(.opacity)
            }
            
            // Input Area
            VStack {
                Divider()
                HStack(alignment: .center, spacing: 10) {
                    TextField("Ask about \(book.title)...", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.send)
                        .disabled(isLoading)
                        .onSubmit(sendMessage)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(isLoading || inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                    }
                    .disabled(isLoading || inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
                .background(Color(.systemGray6))
            }
        }
        .navigationTitle("Chat with \(book.title)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .onAppear {
            messages.append(Message(text: "Hello! I can answer questions about \(book.title). What would you like to know?", isUser: false))
        }
    }
    
    // MARK: - Actions
    
    /// Sends the user's message and fetches an AI response for the book.
    private func sendMessage() {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmedInput.isEmpty else { return }
        
        let userMessage = Message(text: trimmedInput, isUser: true)
        messages.append(userMessage)
        inputText = ""
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await apiService.sendRequest(for: book, query: trimmedInput)
                messages.append(Message(text: response, isUser: false))
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Supporting Types

/// A single chat message with an identifier.
struct Message: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

/// A view for displaying a chat message in a bubble style.
struct ChatBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            Text(message.text)
                .padding(10)
                .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(message.isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
            if !message.isUser { Spacer() }
        }
    }
}

// MARK: - Preview

#Preview {
    let book = Book(title: "Sample Book", fileName: "sample.pdf", totalPages: 1, author: "Jane Doe")
    ChatView(book: book)
}

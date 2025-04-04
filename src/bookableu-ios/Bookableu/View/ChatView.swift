//
//  ChatView.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 20/02/2025.
//  Updated to use BookService with Python backend

import SwiftUI

struct ChatView: View {
    // Book to discuss
    let book: Book
    @State private var bookId: Int?
    
    // Input state
    @State private var inputText: String = ""
    @State private var messages: [Message] = []
    @State private var errorMessage: String?
    
    // Get no spoilers preference from UserDefaults
    @AppStorage("noSpoilers") private var noSpoilers = true
    
    // Services
    @EnvironmentObject private var bookService: BookService
    @Environment(\.dismiss) private var dismiss
    
    // Initialize and extract book ID from the book's remoteId
    init(book: Book) {
        self.book = book
        
        // Try to extract the book ID from remoteId
        if let remoteId = book.remoteId, let id = Int(remoteId) {
            self._bookId = State(initialValue: id)
        }
    }
    
    var body: some View {
        ZStack {
            // Main chat interface
            if bookId != nil {
                VStack(spacing: 0) {
                    // Drag indicator
                    Capsule()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 40, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                    
                    // Messages List
                    ScrollViewReader { scrollView in
                        List {
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            }
                            .onChange(of: messages) { _, _ in
                                if let lastId = messages.last?.id {
                                    withAnimation {
                                        scrollView.scrollTo(lastId, anchor: .bottom)
                                    }
                                }
                            }
                            
                            if bookService.isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding()
                                    Spacer()
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            }
                        }
                        .listStyle(.plain)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }
                    
                    // Input Area
                    VStack {
                        Divider()
                        HStack(alignment: .center, spacing: 10) {
                            TextField("Ask about \(book.title)...", text: $inputText)
                                .textFieldStyle(.roundedBorder)
                                .submitLabel(.send)
                                .disabled(bookService.isLoading)
                                .onSubmit(sendMessage)
                            
                            Button(action: sendMessage) {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(bookService.isLoading || inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                            }
                            .disabled(bookService.isLoading || inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                    }
                }
            } else {
                // Error view when book ID is missing
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                        .padding()
                    
                    Text("This book needs to be synchronized with the server before you can chat with it.")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("Make sure you're connected to the internet and have a user account.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        // Close chat view
                        dismiss()
                    }) {
                        Text("Go Back")
                            .fontWeight(.medium)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top, 10)
                }
                .padding()
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
            if bookId != nil {
                checkBookStatus()
            }
        }
    }
    
    // MARK: - Actions
    
    /// Checks if the book's text has been extracted
    private func checkBookStatus() {
        guard let bookId = bookId else {
            errorMessage = "Book ID not found. Please sync the book with the server."
            return
        }
        
        // Add welcome message
        messages.append(Message(
            text: "Hello! I can answer questions about \(book.title). What would you like to know?",
            isUser: false,
            sources: nil
        ))
        
        // Check if the book has been processed by the backend
        Task {
            do {
                let bookModel = try await bookService.getBook(id: bookId)
                
                if let metadata = bookModel.book_metadata,
                   let extracted = metadata.extracted, !extracted {
                    // Book hasn't been processed yet
                    DispatchQueue.main.async { 
                        self.messages.append(Message(
                            text: "The book is still being processed. Some features may be limited until processing is complete.",
                            isUser: false,
                            sources: nil
                        ))
                    }
                }
            } catch {
                // Ignore errors here, the user can still try to chat
                print("Error checking book status: \(error.localizedDescription)")
            }
        }
    }
    
    /// Sends the user's message and fetches an AI response for the book.
    private func sendMessage() {
        guard let bookId = bookId else {
            errorMessage = "Book ID not found. Please sync the book with the server."
            return
        }
        
        let trimmedInput = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmedInput.isEmpty else { return }
        
        let userMessage = Message(text: trimmedInput, isUser: true, sources: nil)
        messages.append(userMessage)
        inputText = ""
        errorMessage = nil
        
        Task {
            do {
                // Use BookService to query the book with the Python backend
                let response = try await bookService.queryBook(
                    bookId: bookId,
                    query: trimmedInput,
                    noSpoilers: noSpoilers
                )
                
                // Add AI response to messages
                DispatchQueue.main.async {
                    self.messages.append(Message(
                        text: response.chat_answer,
                        isUser: false,
                        sources: response.results
                    ))
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Supporting Types

/// A single chat message with an identifier and optional sources.
struct Message: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let sources: [QueryResult]? // Sources from backend (only for AI responses)
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

/// A view for displaying a chat message in a bubble style.
struct ChatBubble: View {
    let message: Message
    @State private var showingSources = false
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
            // Message bubble
            HStack {
                if message.isUser { Spacer() }
                Text(message.text)
                    .padding(10)
                    .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                if !message.isUser { Spacer() }
            }
            
            // Sources button (only for AI messages with sources)
            if !message.isUser && message.sources != nil && !message.sources!.isEmpty {
                Button(action: { showingSources.toggle() }) {
                    Text(showingSources ? "Hide sources" : "Show sources")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.leading, 8)
                
                // Sources content
                if showingSources {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(message.sources!, id: \.chunk_index) { source in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Relevance: \(Int(source.similarity_score * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(source.text)
                                    .font(.caption2)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.leading, 8)
                    .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

// MARK: - Preview

#Preview {
    let book = Book(title: "Sample Book", fileName: "sample.pdf", totalPages: 1, author: "Jane Doe")
    return ChatView(book: book)
        .environmentObject(BookService())
}

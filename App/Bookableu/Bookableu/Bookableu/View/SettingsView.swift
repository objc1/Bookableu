//
//  SettingsView.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 20/02/2025.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [Book]  // Fetch all books
    @State private var activeAlert: AlertType? = nil
    
    private let oldFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let newFeedbackGenerator = UINotificationFeedbackGenerator()
    
    // Use an enum to identify alerts
    enum AlertType: Identifiable {
        case clearProgress
        case clearCache
        
        var id: Int {
            switch self {
            case .clearProgress: return 1
            case .clearCache: return 2
            }
        }
    }
    
    // Computed property to calculate total pages read
    private var totalPagesRead: Int {
        books.reduce(0) { $0 + $1.lastPage }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Account Section
                Section(header: Text("Account")) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("John Doe")
                                .font(.headline)
                            Text("johndoe@example.com")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("Books in Library: \(books.count)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("Total Pages Read: \(totalPagesRead)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }

                // MARK: - Library Management Section
                Section(header: Text("Library Management")) {
                    Group {
                        Button("Clear All Reading Progress") {
                            newFeedbackGenerator.notificationOccurred(.error)
                            activeAlert = .clearProgress
                        }
                        Button("Clear Storage") {
                            newFeedbackGenerator.notificationOccurred(.error)
                            activeAlert = .clearCache
                        }
                    }
                    .foregroundColor(.red)
                }

                // MARK: - About Section
                Section(header: Text("About")) {
                    NavigationLink(destination: AboutView()) {
                        Label("About This App", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Settings")
            .alert(item: $activeAlert) { alertType in
                switch alertType {
                case .clearProgress:
                    return Alert(
                        title: Text("Clear Reading Progress"),
                        message: Text("Are you sure you want to reset all reading progress? This cannot be undone."),
                        primaryButton: .destructive(Text("Clear")) {
                            clearReadingProgress()
                        },
                        secondaryButton: .cancel()
                    )
                case .clearCache:
                    return Alert(
                        title: Text("Clear Storage"),
                        message: Text("Are you sure you want to delete all books from your library and storage? This cannot be undone."),
                        primaryButton: .destructive(Text("Clear")) {
                            clearCache()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
    }
    
    // MARK: - Actions
    private func clearCache() {
        do {
            // Fetch all books
            let fetchRequest = FetchDescriptor<Book>()
            let books = try modelContext.fetch(fetchRequest)
            
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Failed to access Documents directory.")
                return
            }
            
            // Delete each book's file from Documents directory and then from model context
            for book in books {
                let fileURL = documentsDirectory.appendingPathComponent(book.fileName)
                if fileManager.fileExists(atPath: fileURL.path) {
                    do {
                        try fileManager.removeItem(at: fileURL)
                        print("Deleted file: \(book.fileName)")
                    } catch {
                        print("Failed to delete file \(book.fileName): \(error.localizedDescription)")
                        // Continue even if one file deletion fails
                    }
                }
                modelContext.delete(book)
            }
            
            // Save the changes to the model context
            try modelContext.save()
            print("Cache cleared: All books deleted from library and storage.")
        } catch {
            print("Error clearing cache: \(error.localizedDescription)")
        }
    }
    
    private func clearReadingProgress() {
        do {
            let fetchRequest = FetchDescriptor<Book>()
            let books = try modelContext.fetch(fetchRequest)
            for book in books {
                book.lastPage = 0
            }
            try modelContext.save()
            print("Reading progress cleared")
        } catch {
            print("Error clearing progress: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
}

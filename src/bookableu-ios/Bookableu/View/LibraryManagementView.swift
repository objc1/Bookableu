//
//  LibraryManagementView.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 09/04/2025.
//

import SwiftUI
import SwiftData

struct LibraryManagementView: View {
    // MARK: - Properties
    
    // Environment
    @Environment(\.modelContext) private var modelContext
    
    // State
    @State private var activeAlert: AlertType? = nil
    
    // Feedback
    private let hapticFeedback = UINotificationFeedbackGenerator()
    
    // MARK: - Alert Types
    
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
    
    // MARK: - Body
    
    var body: some View {
        Form {
            Section(header: Text("Data Management")) {
                Button("Clear All Reading Progress") {
                    hapticFeedback.notificationOccurred(.error)
                    activeAlert = .clearProgress
                }
                .foregroundColor(.red)
                
                Button("Clear Storage") {
                    hapticFeedback.notificationOccurred(.error)
                    activeAlert = .clearCache
                }
                .foregroundColor(.red)
            }
            
            // Help section explaining the options
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About these options")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    Text("• Clear All Reading Progress: This will reset your reading progress to 0 for all books in your library. Book files will remain in your library.")
                        .font(.caption)
                        .padding(.bottom, 2)
                    
                    Text("• Clear Storage: This will delete all book files and remove all books from your library. This cannot be undone.")
                        .font(.caption)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Library Management")
        .alert(item: $activeAlert) { alertType in
            createAlert(for: alertType)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createAlert(for alertType: AlertType) -> Alert {
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
    
    // MARK: - Data Management Actions
    
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
                    } catch {
                        print("Failed to delete file \(book.fileName): \(error.localizedDescription)")
                        // Continue even if one file deletion fails
                    }
                }
                modelContext.delete(book)
            }
            
            // Save the changes to the model context
            try modelContext.save()
            hapticFeedback.notificationOccurred(.success)
        } catch {
            print("Error clearing cache: \(error.localizedDescription)")
            hapticFeedback.notificationOccurred(.error)
        }
    }
    
    private func clearReadingProgress() {
        do {
            let fetchRequest = FetchDescriptor<Book>()
            let books = try modelContext.fetch(fetchRequest)
            for book in books {
                book.currentPage = 0
            }
            try modelContext.save()
            hapticFeedback.notificationOccurred(.success)
        } catch {
            print("Error clearing progress: \(error.localizedDescription)")
            hapticFeedback.notificationOccurred(.error)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        LibraryManagementView()
    }
} 
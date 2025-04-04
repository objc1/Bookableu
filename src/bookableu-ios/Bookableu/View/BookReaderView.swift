import SwiftUI
import UniformTypeIdentifiers

struct BookReaderView: View {
    let book: Book
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var bookService: BookService

    // Active sheet to present detail or chat views.
    enum ActiveSheet: Identifiable {
        case detail(Book)
        case chat(Book)
        
        var id: Int {
            switch self {
            case .detail(let book): return book.id.hashValue
            case .chat(let book): return book.id.hashValue ^ 1
            }
        }
    }
    
    // Function to update progress on the server
    var updateProgressCallback: ((Book) -> Void)?
    
    @State private var activeSheet: ActiveSheet?
    @State private var lastBookUpdate = Date()
    
    init(book: Book, updateProgressCallback: ((Book) -> Void)? = nil) {
        self.book = book
        self.updateProgressCallback = updateProgressCallback
    }

    var body: some View {
        Group {
            if book.fileURL?.pathExtension.lowercased() == "pdf" {
                PDFReaderView(book: book, updateProgressCallback: updateProgressCallback)
            } else if book.fileURL?.pathExtension.lowercased() == "epub" {
                EPUBReaderView(book: book, updateProgressCallback: updateProgressCallback)
            } else {
                Text("Unsupported file format: \(book.fileURL?.pathExtension ?? "unknown")")
                    .foregroundColor(.red)
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit Details") {
                        activeSheet = .detail(book)
                    }
                    Button("Chat with Book") {
                        activeSheet = .chat(book)
                    }
                    Button(role: .destructive) {
                        deleteBook()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .detail(let book):
                BookDetailView(book: book)
            case .chat(let book):
                ChatView(book: book)
                    .environmentObject(bookService)
            }
        }
        // Force a save when app loses focus at the root reader level
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // Final attempt to save progress when app goes to background
                if let progressCallback = updateProgressCallback {
                    progressCallback(book)
                }
            }
        }
    }
    
    private func deleteBook() {
        modelContext.delete(book)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error deleting book: \(error.localizedDescription)")
        }
    }
}

#Preview {
    BookReaderView(book: Book(title: "Sample Title", fileName: "SampleFile.pdf", totalPages: 1, author: "Sample Author"))
        .environmentObject(BookService())
}

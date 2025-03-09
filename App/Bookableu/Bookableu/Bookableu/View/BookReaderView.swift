import SwiftUI
import UniformTypeIdentifiers

struct BookReaderView: View {
    let book: Book
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
    
    @State private var activeSheet: ActiveSheet?

    var body: some View {
        Group {
            if book.fileURL.pathExtension.lowercased() == "pdf" {
                PDFReaderView(book: book)
            } else if book.fileURL.pathExtension.lowercased() == "epub" {
                EPUBReaderView(book: book)
            } else {
                Text("Unsupported file format: \(book.fileURL.pathExtension)")
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
}

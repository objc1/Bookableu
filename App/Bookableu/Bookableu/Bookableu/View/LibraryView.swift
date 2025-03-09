import SwiftUI
import SwiftData
import PDFKit

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [Book]
    
    enum ActiveSheet: Identifiable {
        case detail(Book)
        case chat(Book)
        case picker
        
        var id: Int {
            switch self {
            case .detail(let book): return book.id.hashValue
            case .chat(let book): return book.id.hashValue ^ 1
            case .picker: return 0
            }
        }
    }
    
    @State private var activeSheet: ActiveSheet?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var bookToDelete: Book?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(books) { book in
                    NavigationLink {
                        BookReaderView(book: book)
                            .navigationTitle(book.title)
                    } label: {
                        HStack {
                            if let cover = book.coverImage {
                                cover
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 70)
                                    .clipped()
                                    .cornerRadius(5)
                            } else {
                                Image(systemName: book.bookType == .pdf ? "doc.text" : "book")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 70)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(book.title)
                                    .lineLimit(1)
                                Text("Progress: \(calculateProgress(for: book))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .contextMenu {
                        Button("Edit Details") {
                            activeSheet = .detail(book)
                        }
                        Button("Chat with Book") {
                            activeSheet = .chat(book)
                        }
                        Button(role: .destructive) {
                            bookToDelete = book
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteBooks)
            }
            .navigationTitle("My Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { activeSheet = .picker } label: {
                        Image(systemName: "plus")
                            .accessibilityLabel("Add Book")
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .detail(let book):
                    BookDetailView(book: book)
                case .chat(let book):
                    ChatView(book: book)
                case .picker:
                    DocumentPicker { result in
                        switch result {
                        case .success(let url):
                            addBook(url)
                        case .failure(let error):
                            if let dpError = error as? DocumentPicker.DocumentPickerError,
                               dpError == .duplicateFile {
                                alertMessage = dpError.errorDescription ?? "File already exists."
                            } else {
                                alertMessage = error.localizedDescription
                            }
                            showAlert = true
                        }
                        activeSheet = nil
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
            .alert("Delete Book", isPresented: $showDeleteConfirmation, presenting: bookToDelete) { book in
                Button("Delete", role: .destructive) {
                    delete(book)
                }
                Button("Cancel", role: .cancel) {
                    bookToDelete = nil
                }
            } message: { book in
                Text("Are you sure you want to delete \"\(book.title)\"?")
            }
        }
    }
    
    // MARK: - Actions
    
    private func addBook(_ fileURL: URL) {
        let fileName = fileURL.lastPathComponent
        let newBook = Book(title: fileName, fileName: fileName, totalPages: 1, author: nil)
        
        if newBook.bookType == .pdf {
            if let pdfDocument = PDFDocument(url: fileURL) {
                newBook.totalPages = pdfDocument.pageCount
            } else {
                newBook.totalPages = 0
            }
        }
        
        modelContext.insert(newBook)
        saveContext(errorMessage: "Failed to add book: \(fileName)")
    }
    
    private func delete(_ book: Book) {
        withAnimation {
            // Remove the file from Documents directory
            if let fileURL = getFileURL(for: book) {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                } catch {
                    alertMessage = "Failed to delete file from Documents directory: \(error.localizedDescription)"
                    showAlert = true
                    print(alertMessage)
                    return // Exit early if file deletion fails
                }
            }
            
            // Delete the book from the model context
            modelContext.delete(book)
            saveContext(errorMessage: "Failed to delete book: \(book.title)")
        }
        bookToDelete = nil
    }
    
    private func deleteBooks(at offsets: IndexSet) {
        withAnimation {
            let booksToDelete = offsets.map { books[$0] }
            for book in booksToDelete {
                // Remove the file from Documents directory
                if let fileURL = getFileURL(for: book) {
                    do {
                        try FileManager.default.removeItem(at: fileURL)
                    } catch {
                        alertMessage = "Failed to delete file from Documents directory: \(error.localizedDescription)"
                        showAlert = true
                        print(alertMessage)
                        continue // Continue with other deletions even if one fails
                    }
                }
                modelContext.delete(book)
            }
            saveContext(errorMessage: "Failed to delete books")
        }
    }
    
    private func saveContext(errorMessage: String) {
        do {
            try modelContext.save()
        } catch {
            alertMessage = "\(errorMessage): \(error.localizedDescription)"
            showAlert = true
            print(alertMessage)
        }
    }
    
    private func calculateProgress(for book: Book) -> Int {
        guard book.totalPages > 0 else { return 0 }
        let progress = Double(book.lastPage) / Double(book.totalPages) * 100
        return Int(progress)
    }
    
    // Helper function to get the file URL in Documents directory
    private func getFileURL(for book: Book) -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            alertMessage = "Failed to access Documents directory."
            showAlert = true
            return nil
        }
        return documentsDirectory.appendingPathComponent(book.fileName)
    }
}

#Preview {
    LibraryView()
}

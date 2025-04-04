import SwiftUI
import SwiftData
import PDFKit
import Combine
import Foundation

// MARK: - Book Row View
struct BookRowView: View {
    let book: Book
    let onSelectAction: () -> Void
    let onEditAction: () -> Void
    let onChatAction: () -> Void
    let onDeleteAction: () -> Void
    let isDownloading: Bool
    let updateProgressCallback: ((Book) -> Void)?
    
    var body: some View {
        NavigationLink(destination: {
            if let fileURL = book.fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
                BookReaderView(book: book, updateProgressCallback: updateProgressCallback)
                    .navigationTitle(book.title)
            } else {
                VStack(spacing: 20) {
                    Text("Book file not available")
                        .font(.headline)
                    
                    if isDownloading {
                        ProgressView("Downloading...")
                    } else {
                        Text("Please wait for the download to complete or try again later.")
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .padding()
                .navigationTitle(book.title)
            }
        }, label: {
            HStack {
                if let coverData = book.coverImage, let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 70)
                        .clipped()
                        .cornerRadius(5)
                } else {
                    Image(uiImage: book.generateLetterCover())
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 70)
                        .cornerRadius(5)
                }
                
                VStack(alignment: .leading) {
                    Text(book.title)
                        .lineLimit(1)
                    if isDownloading {
                        HStack {
                            Text("Downloading...")
                                .font(.caption)
                                .foregroundColor(.blue)
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    } else if book.fileURL == nil || !FileManager.default.fileExists(atPath: book.fileURL!.path) {
                        Text("File not available")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("Progress: \(calculateProgress())%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 8)
            }
        })
        .contextMenu {
            Button("Edit Details") {
                onEditAction()
            }
            Button("Chat with Book") {
                onChatAction()
            }
            Button(role: .destructive) {
                onDeleteAction()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func calculateProgress() -> Int {
        guard book.totalPages > 0 else { return 0 }
        
        // For single-page documents that have been opened, show as 100% complete
        if book.totalPages <= 1 && book.currentPage > 0 {
            return 100
        }
        
        let progress = Double(book.currentPage) / Double(book.totalPages) * 100
        return Int(progress)
    }
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    
    // Query with dynamic sorting
    @Query private var books: [Book]
    
    @StateObject private var apiService = CustomAPIService()
    @EnvironmentObject private var userProvider: UserProvider
    @EnvironmentObject private var bookService: BookService
    @State private var isLoading = false
    @State private var downloadingBooks = Set<String>()
    @State private var activeSheet: ActiveSheet?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var bookToDelete: Book?
    @State private var showDeleteConfirmation = false
    @State private var searchText = ""
    @State private var showSortMenu = false
    @State private var sortOption: SortOption = .recentlyAdded
    @State private var initialLoadCompleted = false
    
    // Sorted books array
    private var sortedBooks: [Book] {
        switch sortOption {
        case .recentlyAdded:
            // Default ordering from the database is often by insertion time
            return books
        case .title:
            return books.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .author:
            return books.sorted { 
                let author1 = $0.author ?? ""
                let author2 = $1.author ?? ""
                return author1.localizedCaseInsensitiveCompare(author2) == .orderedAscending
            }
        case .progress:
            return books.sorted { 
                let progress1 = Double($0.currentPage) / Double(max($0.totalPages, 1)) 
                let progress2 = Double($1.currentPage) / Double(max($1.totalPages, 1))
                return progress1 > progress2 // Higher progress first
            }
        }
    }

    // MARK: - Sort Options
    enum SortOption {
        case recentlyAdded
        case title
        case author
        case progress
    }
    
    enum ActiveSheet: Identifiable {
        case detail(Book)
        case chat(Book)
        case picker
        
        var id: Int {
            switch self {
            case .detail(let book): 
                return book.title.hashValue
            case .chat(let book): 
                return book.title.hashValue ^ 1
            case .picker: 
                return 0
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            listContent
                .navigationTitle("My Library")
                .transaction { transaction in 
                    // Disable animation for the navigation title
                    transaction.animation = nil
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { activeSheet = .picker } label: {
                            Image(systemName: "plus")
                                .accessibilityLabel("Add Book")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Button {
                                sortOption = .recentlyAdded
                            } label: {
                                Label("Recently Added", systemImage: "clock")
                                if sortOption == .recentlyAdded {
                                    Image(systemName: "checkmark")
                                }
                            }
                            
                            Button {
                                sortOption = .title
                            } label: {
                                Label("Title", systemImage: "textformat")
                                if sortOption == .title {
                                    Image(systemName: "checkmark")
                                }
                            }
                            
                            Button {
                                sortOption = .author
                            } label: {
                                Label("Author", systemImage: "person")
                                if sortOption == .author {
                                    Image(systemName: "checkmark")
                                }
                            }
                            
                            Button {
                                sortOption = .progress
                            } label: {
                                Label("Reading Progress", systemImage: "book")
                                if sortOption == .progress {
                                    Image(systemName: "checkmark")
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                                .accessibilityLabel("Sort Books")
                        }
                    }
                }
                .sheet(item: $activeSheet) { sheet in
                    sheetContent(for: sheet)
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
                .onAppear {
                    // Only fetch books on first appearance or if explicitly refreshed
                    if !initialLoadCompleted {
                        Task {
                            await fetchBooksFromServer()
                            initialLoadCompleted = true
                        }
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        // When app moves to background, save all currently reading books
                        saveAllReadingBooks()
                    }
                }
        }
    }
    
    private var listContent: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading books...")
                    Spacer()
                }
            }
            
            ForEach(sortedBooks) { book in
                BookRowView(
                    book: book,
                    onSelectAction: { /* Navigation handled by NavigationLink */ },
                    onEditAction: { activeSheet = .detail(book) },
                    onChatAction: { activeSheet = .chat(book) },
                    onDeleteAction: {
                        bookToDelete = book
                        showDeleteConfirmation = true
                    },
                    isDownloading: downloadingBooks.contains(book.fileName),
                    updateProgressCallback: { book in
                        updateReadingProgress(for: book)
                    }
                )
            }
            .onDelete(perform: deleteBooks)
        }
        .refreshable {
            await fetchBooksFromServer(isRefreshing: true)
        }
    }
    
    @ViewBuilder
    private func sheetContent(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .detail(let book):
            BookDetailView(book: book)
        case .chat(let book):
            ChatView(book: book)
                .environmentObject(bookService)
        case .picker:
            DocumentPicker { result in
                handleDocumentPickerResult(result)
            }
        }
    }
    
    private func handleDocumentPickerResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            // Check for authentication first
            if !userProvider.isAuthenticated {
                // If not authenticated
                alertMessage = "Please sign in to upload books to the cloud. The book will be saved locally only."
                showAlert = true
                // Still add the book locally
                addBook(url)
            } else {
                // Normal flow - add book and upload
                addBook(url)
            }
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
    
    // MARK: - Actions
    private func addBook(_ fileURL: URL) {
        // Get file manager
        let fileManager = FileManager.default
        
        // Ensure the file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            alertMessage = "The selected file no longer exists."
            showAlert = true
            return
        }
        
        // Get file properties
        let fileName = fileURL.lastPathComponent
        
        // Try to get file attributes
        var fileSize: UInt64 = 0
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            fileSize = attributes[.size] as? UInt64 ?? 0
            
            // Check if file is empty
            if fileSize == 0 {
                alertMessage = "The selected file is empty."
                showAlert = true
                return
            }
        } catch {
            print("Error reading file attributes: \(error.localizedDescription)")
            // We'll continue anyway but log the error
        }
        
        // Determine initial page count based on file type
        var initialPageCount = 1
        var bookType: BookType = .other
        
        switch fileURL.pathExtension.lowercased() {
        case "pdf":
            bookType = .pdf
            // Try to get page count from PDF if possible
            if let pdfDocument = PDFDocument(url: fileURL) {
                initialPageCount = pdfDocument.pageCount
                print("PDF page count: \(initialPageCount)")
            } else {
                print("Failed to open PDF document")
            }
        case "epub":
            bookType = .epub
            // EPUB page count will be determined later when the file is processed
            initialPageCount = 100 // Default estimate for now
        default:
            bookType = .other
        }
        
        // Create meaningful title from filename (remove extension, replace underscores)
        let rawTitle = fileURL.deletingPathExtension().lastPathComponent
        let cleanTitle = rawTitle
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        
        // Create the book object
        let newBook = Book(title: cleanTitle, fileName: fileName, totalPages: initialPageCount)
        newBook.bookType = bookType
        newBook.fileURL = fileURL
        
        // Insert book into local database
        modelContext.insert(newBook)
        saveContext(errorMessage: "Failed to add book: \(fileName)")
        
        // Upload in background
        Task {
            await uploadBookToServer(newBook, fileURL: fileURL)
        }
    }
    
    private func uploadBookToServer(_ book: Book, fileURL: URL) async {
        // Verify the file still exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            await MainActor.run {
                alertMessage = "File no longer exists at path: \(fileURL.path)"
                showAlert = true
            }
            return
        }
        
        // Determine mime type based on file extension
        let mimeType: String
        switch fileURL.pathExtension.lowercased() {
        case "pdf":
            mimeType = "application/pdf"
        case "epub":
            mimeType = "application/epub+zip"
        default:
            mimeType = "application/octet-stream"
        }
        
        // Create parameters for the upload
        let parameters: [String: String] = [
            "title": book.title,
            "author": book.author ?? "Unknown",
            "totalPages": String(book.totalPages)
        ]
        
        do {
            // First, check if we can actually read the file data
            let _ = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            
            // Now try the upload
            let response: BookUploadResponse = try await apiService.uploadFile(
                fileURL: fileURL,
                endpoint: "books/upload",
                mimeType: mimeType,
                parameters: parameters
            )
            
            // Update the book with server ID if upload succeeds
            await MainActor.run {
                book.remoteId = String(response.id)
                try? modelContext.save()
                print("Book uploaded successfully with ID: \(response.id)")
            }
        } catch let fileError as NSError where fileError.domain == NSCocoaErrorDomain && 
                                            (fileError.code == NSFileReadNoPermissionError || 
                                             fileError.code == NSFileReadUnknownError) {
            // Handle file permission errors specifically
            print("File permission error: \(fileError)")
            await MainActor.run {
                alertMessage = "Cannot access the file. Permission denied."
                showAlert = true
            }
        } catch {
            // Handle the error properly
            print("Upload error: \(error)")
            
            // Show error to the user on the main thread
            await MainActor.run {
                if let apiError = error as? CustomAPIError {
                    switch apiError {
                    case .unauthorized:
                        alertMessage = "Please sign in to upload books"
                    case .noInternet:
                        alertMessage = "No internet connection. The book is saved locally but couldn't be uploaded."
                    default:
                        alertMessage = apiError.errorDescription ?? "Failed to upload book to server"
                    }
                } else {
                    alertMessage = "Upload failed: \(error.localizedDescription)"
                }
                showAlert = true
            }
        }
    }
    
    private func delete(_ book: Book) {
        // If book has a remote ID, delete it from the server first
        if let remoteId = book.remoteId {
            Task {
                do {
                    // Send delete request to server
                    print("Deleting book from server with ID: \(remoteId)")
                    let _: BookResponse = try await apiService.delete(endpoint: "books/\(remoteId)")
                    print("Successfully deleted book from server: \(remoteId)")
                } catch {
                    // Log error but continue with local deletion
                    print("Failed to delete book from server: \(error)")
                    
                    // Only show alert for non-network errors
                    if let apiError = error as? CustomAPIError, 
                       apiError != .unauthorized && apiError != .noInternet {
                        await MainActor.run {
                            alertMessage = "Failed to delete from server: \(error.localizedDescription)"
                            showAlert = true
                        }
                    }
                }
            }
        }
        
        withAnimation {
            deleteBookFile(book)
            modelContext.delete(book)
            saveContext(errorMessage: "Failed to delete book: \(book.title)")
        }
        bookToDelete = nil
    }
    
    private func deleteBooks(at offsets: IndexSet) {
        // Convert offsets from sortedBooks to the actual books to delete
        let booksToDelete = offsets.map { sortedBooks[$0] }
        
        // Delete each book
        for book in booksToDelete {
            delete(book) // This now handles both local and server deletion
        }
    }
    
    private func deleteBookFile(_ book: Book) {
        guard let fileURL = getFileURL(for: book) else { return }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            alertMessage = "Failed to delete file: \(error.localizedDescription)"
            showAlert = true
            print(alertMessage)
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
    
    // Helper function to get the file URL in Documents directory
    private func getFileURL(for book: Book) -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            alertMessage = "Failed to access Documents directory."
            showAlert = true
            return nil
        }
        return documentsDirectory.appendingPathComponent(book.fileName)
    }
    
    private func calculateProgress(for book: Book) -> Int {
        guard book.totalPages > 0 else { return 0 }
        
        // For single-page documents that have been opened, show as 100% complete
        if book.totalPages <= 1 && book.currentPage > 0 {
            return 100
        }
        
        let progress = Double(book.currentPage) / Double(book.totalPages) * 100
        return Int(progress)
    }
    
    // MARK: - API Functions
    
    private func fetchBooksFromServer(isRefreshing: Bool = false) async {
        // Skip if not authenticated
        if !userProvider.isAuthenticated {
            return
        }
        
        // Only show loading indicator if not being called from pull-to-refresh
        if !isRefreshing {
            await MainActor.run {
                isLoading = true
            }
        }

        verifyAndFixBookFileURLs()
        
        do {
            let fetchedBooks: [BookResponse] = try await apiService.get(endpoint: "books")
            
            await MainActor.run {
                processFetchedBooks(fetchedBooks)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                print("Failed to fetch books: \(error)")
                isLoading = false
                
                // Only show alert if not due to authentication
                if let apiError = error as? CustomAPIError, apiError != .unauthorized {
                    alertMessage = "Failed to load books: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    // Update reading progress on the server
    func updateReadingProgress(for book: Book) {
        // Skip if not authenticated
        if !userProvider.isAuthenticated {
            return
        }
        
        // Skip if the book doesn't have a remote ID
        guard let remoteId = book.remoteId else {
            print("Cannot update progress for book without remote ID")
            return
        }
        
        // Capture current state values to avoid threading issues
        let currentPage = book.currentPage
        let totalPages = book.totalPages
        // Determine status based on current page and total pages
        let status = currentPage == 0 ? "unread" : (currentPage >= totalPages ? "finished" : "reading")
        
        // Check on main thread if syncing is needed
        Task { @MainActor in
            // Perform network request in the background
            Task.detached {
                do {
                    // Create form data parameters - server expects Form parameters not JSON
                    let formParameters = [
                        "current_page": String(currentPage),
                        "status": status
                    ]
                    
                    print("Sending progress update parameters: \(formParameters)")
                    
                    // Try up to 3 times to update reading progress with exponential backoff
                    var attempt = 0
                    var success = false
                    
                    while attempt < 3 && !success {
                        do {
                            // Send the update to the server using form data method
                            print("Updating reading progress for book ID: \(remoteId), page: \(currentPage), status: \(status) (attempt \(attempt + 1))")
                            let _: BookResponse = try await apiService.putWithFormData(endpoint: "books/\(remoteId)", parameters: formParameters)
                            success = true
                        } catch {
                            attempt += 1
                            if attempt < 3 {
                                // Exponential backoff
                                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                                continue
                            }
                            throw error
                        }
                    }
                    
                    // Mark the book as synced on the main thread
                    await MainActor.run {
                        // Get the book again to avoid stale references
                        if let updatedBook = try? modelContext.fetch(FetchDescriptor<Book>(predicate: #Predicate { $0.remoteId == remoteId })).first {
                            updatedBook.markAsSynced()
                            try? modelContext.save()
                            print("Successfully updated reading progress on server")
                        }
                    }
                } catch {
                    print("Failed to update reading progress: \(error)")
                    
                    // Save the failed sync attempt for retry later
                    await MainActor.run {
                        if let updatedBook = try? modelContext.fetch(FetchDescriptor<Book>(predicate: #Predicate { $0.remoteId == remoteId })).first {
                            // Setting lastSync to nil will force a retry on next read
                            updatedBook.lastSync = nil
                            try? modelContext.save()
                        }
                    }
                    
                    // Print more detailed error information for debugging
                    if let apiError = error as? CustomAPIError {
                        switch apiError {
                        case .requestFailed(let message):
                            print("API Error details: \(message)")
                        case .serverError(let code):
                            print("Server error code: \(code)")
                        default:
                            print("Other API error: \(apiError.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    private func processFetchedBooks(_ fetchedBooks: [BookResponse]) {
        // Create a set of existing remote IDs for faster lookup
        let existingRemoteIds = Set(books.compactMap { $0.remoteId })
        
        for bookResponse in fetchedBooks {
            let remoteId = String(bookResponse.id)
            
            // Skip if we already have this book
            if existingRemoteIds.contains(remoteId) {
                continue
            }
            
            // Extract file name from file path
            let fileName = URL(string: bookResponse.fileName ?? "")?.lastPathComponent ?? "\(bookResponse.id).pdf"
            
            // Get the destination file path
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Failed to access documents directory")
                continue
            }
            
            let localFileURL = documentsDirectory.appendingPathComponent(fileName)
            let localFilePath = localFileURL.path
            
            // Create a new book from the response
            let newBook = Book(title: bookResponse.title, 
                              fileName: fileName, 
                              totalPages: bookResponse.totalPages)
            
            // Set additional properties
            newBook.remoteId = remoteId
            newBook.author = bookResponse.author
            newBook.bookType = determineBookType(from: fileName)
            
            // Set fileURL if the file exists locally
            if FileManager.default.fileExists(atPath: localFilePath) {
                newBook.fileURL = localFileURL
                print("Book file exists, setting fileURL: \(localFileURL.path)")
            } else {
                print("Book file doesn't exist at: \(localFilePath)")
            }
            
            // Insert the new book into the database
            modelContext.insert(newBook)
            
            // Only download if file doesn't exist locally
            if !FileManager.default.fileExists(atPath: localFilePath) {
                Task {
                    await downloadBook(fileKey: "", fileName: fileName)
                }
            } else {
                print("Book already exists locally, skipping download: \(fileName)")
            }
        }
        
        // Save the context
        saveContext(errorMessage: "Failed to save fetched books")
    }
    
    private func downloadBook(fileKey: String, fileName: String) async {
        // Check if we have remote ID
        guard let book = books.first(where: { $0.fileName == fileName && $0.remoteId != nil }) else {
            print("Cannot download book without remote ID: \(fileName)")
            return
        }
        
        guard let remoteId = book.remoteId else { return }
        
        // Add to downloading set
        _ = await MainActor.run {
            downloadingBooks.insert(fileName)
        }
        
        // Ensure download status is removed when function exits
        defer {
            Task { @MainActor in
                downloadingBooks.remove(fileName)
            }
        }
        
        do {
            // Get documents directory
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Failed to access documents directory")
                return
            }
            
            // Set destination path
            let destinationURL = documentsDirectory.appendingPathComponent(fileName)
            print("Destination path: \(destinationURL.path)")
            
            // Check if file already exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                print("Book already exists locally: \(fileName)")
                
                // Update book's fileURL even if we're not downloading
                await MainActor.run {
                    book.fileURL = destinationURL
                    try? modelContext.save()
                }
                return
            }
            
            // Step 1: Get the presigned URL from the backend
            print("Requesting download URL for book ID: \(remoteId)")
            let response: [String: String] = try await apiService.get(endpoint: "books/download/\(remoteId)")
            
            // Extract the download URL from the response
            guard let downloadURLString = response["download_url"], 
                  let downloadURL = URL(string: downloadURLString) else {
                throw CustomAPIError.invalidResponse
            }
            
            print("Received presigned URL: \(downloadURLString)")
            
            // Step 2: Download the actual file from the presigned URL
            print("Downloading book file from presigned URL")
            let (data, _) = try await URLSession.shared.data(from: downloadURL)
            
            // Save file to documents directory
            try data.write(to: destinationURL)
            
            print("Successfully downloaded book: \(fileName)")
            
            // Update the book with the file URL
            await MainActor.run {
                book.fileURL = destinationURL
                try? modelContext.save()
                print("Updated book with fileURL: \(destinationURL.path)")
            }
        } catch {
            print("Failed to download book: \(fileName), error: \(error)")
            
            // Show error to the user on the main thread for serious errors
            if let apiError = error as? CustomAPIError, 
                apiError != .unauthorized && apiError != .noInternet {
                await MainActor.run {
                    alertMessage = "Failed to download \(fileName): \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func determineBookType(from fileName: String) -> BookType {
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        switch fileExtension {
        case "pdf":
            return .pdf
        case "epub":
            return .epub
        default:
            return .other
        }
    }
    
    // Save progress for all books that are currently being read
    private func saveAllReadingBooks() {
        let booksBeingRead = books.filter { $0.readingStatus == .reading }
        
        if !booksBeingRead.isEmpty {
            do {
                try modelContext.save()
                print("Saved progress for \(booksBeingRead.count) reading books on app background")
                
                // Attempt to sync with server for each book
                for book in booksBeingRead {
                    if let _ = book.remoteId {
                        updateReadingProgress(for: book)
                    }
                }
            } catch {
                print("Error saving reading progress on app background: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Verify and fix book file URLs
    private func verifyAndFixBookFileURLs() {
        print("Verifying and fixing book file URLs...")
        
        // Get documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Failed to access documents directory")
            return
        }
        
        // Check each book's fileURL and update if needed
        for book in books {
            let expectedFileURL = documentsDirectory.appendingPathComponent(book.fileName)
            let fileExists = FileManager.default.fileExists(atPath: expectedFileURL.path)
            
            // Check if fileURL needs updating
            let needsUpdate = book.fileURL == nil || 
                              !FileManager.default.fileExists(atPath: book.fileURL!.path) ||
                              book.fileURL!.lastPathComponent != book.fileName
            
            if fileExists && needsUpdate {
                print("Fixing file URL for book: \(book.title) - \(book.fileName)")
                book.fileURL = expectedFileURL
            } else if !fileExists && book.fileURL != nil {
                print("File doesn't exist, clearing fileURL for book: \(book.title)")
                book.fileURL = nil
            }
        }
        
        // Save the updated fileURLs
        do {
            try modelContext.save()
            print("Successfully updated book file URLs")
        } catch {
            print("Error saving updated book file URLs: \(error.localizedDescription)")
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(UserProvider())
}

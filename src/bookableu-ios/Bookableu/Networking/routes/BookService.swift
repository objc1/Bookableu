//
//  BookService.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 10/03/2025.
//  Updated to match Python FastAPI backend

import Foundation
import Combine
import os.log

/// A service class that handles all book-related API operations including fetching, uploading, updating, and querying books.
/// This class manages the state of books and provides methods to interact with the backend API.
@MainActor
final class BookService: ObservableObject, Sendable {
    private let apiService: CustomAPIService
    private let logger = Logger(subsystem: "Bookableu", category: "BookService")
    
    /// Published array of books that can be observed for changes
    @Published var books: [BookModel] = []
    
    /// Published flag indicating if an API operation is in progress
    @Published var isLoading = false
    
    /// Published error that can occur during API operations
    @Published var error: Error?
    
    /// Initializes a new BookService instance
    /// - Parameter apiService: The API service to use for network requests. Defaults to a new CustomAPIService instance.
    init(apiService: CustomAPIService = CustomAPIService()) {
        self.apiService = apiService
    }
    
    /// Fetches a paginated list of books for the current user
    /// - Parameters:
    ///   - skip: Number of items to skip from the beginning of the list (for pagination)
    ///   - limit: Maximum number of items to return in the response
    /// - Returns: An array of BookModel objects
    /// - Throws: CustomAPIError if the request fails
    func getBooks(skip: Int = 0, limit: Int = 10) async throws -> [BookModel] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let endpoint = "books?skip=\(skip)&limit=\(limit)"
            let fetchedBooks: [BookModel] = try await apiService.get(endpoint: endpoint)
            
            books = fetchedBooks
            error = nil
            
            return fetchedBooks
        } catch let fetchError {
            self.error = fetchError
            throw fetchError
        }
    }
    
    /// Retrieves detailed information about a specific book by its ID
    /// - Parameter id: The unique identifier of the book to fetch
    /// - Returns: A BookModel containing the book's details
    /// - Throws: CustomAPIError if the book is not found or the request fails
    func getBook(id: Int) async throws -> BookModel {
        return try await apiService.get(endpoint: "books/\(id)")
    }
    
    /// Uploads a new book file to the server
    /// - Parameters:
    ///   - fileURL: The local URL of the book file to upload
    ///   - title: The title of the book. If nil, the filename will be used as the title
    ///   - author: The author of the book (optional)
    ///   - totalPages: The total number of pages in the book (optional)
    /// - Returns: A BookModel containing the details of the uploaded book
    /// - Throws: CustomAPIError if the upload fails or the file format is unsupported
    func uploadBook(fileURL: URL, title: String? = nil, author: String? = nil, totalPages: Int? = nil) async throws -> BookModel {
        isLoading = true
        defer { isLoading = false }
        
        let bookTitle = title ?? fileURL.deletingPathExtension().lastPathComponent
        
        // Create multipart form data
        var formData = [String: String]()
        formData["title"] = bookTitle
        
        if let author = author {
            formData["author"] = author
        }
        
        if let totalPages = totalPages {
            formData["total_pages"] = String(totalPages)
        }
        
        // Determine MIME type based on file extension
        let ext = fileURL.pathExtension.lowercased()
        let mimeType: String
        switch ext {
        case "pdf":
            mimeType = "application/pdf"
        case "epub":
            mimeType = "application/epub+zip"
        default:
            throw CustomAPIError.invalidRequest("Unsupported file format")
        }
        
        do {
            let response: BookModel = try await apiService.uploadFile(
                fileURL: fileURL,
                endpoint: "books/upload",
                mimeType: mimeType,
                parameters: formData
            )
            
            // Refresh the book list
            _ = try? await getBooks()
            
            return response
        } catch {
            logger.error("Failed to upload book: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Updates the reading status and current page of a book
    /// - Parameters:
    ///   - bookId: The unique identifier of the book to update
    ///   - status: The new reading status to set for the book
    ///   - currentPage: The current page number the user has reached
    /// - Returns: An updated BookModel reflecting the changes
    /// - Throws: CustomAPIError if the update fails
    func updateBook(bookId: Int, status: BookStatus, currentPage: Int) async throws -> BookModel {
        isLoading = true
        defer { isLoading = false }
        
        var formData = [String: String]()
        formData["status"] = status.rawValue
        formData["current_page"] = String(currentPage)
        
        do {
            let response: BookModel = try await apiService.putWithFormData(
                endpoint: "books/\(bookId)",
                parameters: formData
            )
            
            // Update the local book list
            if let index = books.firstIndex(where: { $0.id == bookId }) {
                if index < books.count {
                    books[index] = response
                }
            }
            
            return response
        } catch {
            logger.error("Failed to update book: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Deletes a book from the user's library
    /// - Parameter bookId: The unique identifier of the book to delete
    /// - Returns: The deleted BookModel
    /// - Throws: CustomAPIError if the deletion fails
    func deleteBook(bookId: Int) async throws -> BookModel {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: BookModel = try await apiService.delete(endpoint: "books/\(bookId)")
            
            // Remove from local book list
            books.removeAll { $0.id == bookId }
            
            return response
        } catch {
            logger.error("Failed to delete book: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Retrieves a download URL for a specific book
    /// - Parameter bookId: The unique identifier of the book to download
    /// - Returns: A URL that can be used to download the book file
    /// - Throws: CustomAPIError if the download URL cannot be generated
    func getDownloadURL(bookId: Int) async throws -> URL {
        let response: DownloadResponse = try await apiService.get(endpoint: "books/download/\(bookId)")
        guard let url = URL(string: response.download_url) else {
            throw CustomAPIError.invalidResponse
        }
        return url
    }
    
    /// Queries a book using natural language to get AI-generated answers about its content
    /// - Parameters:
    ///   - bookId: The unique identifier of the book to query
    ///   - query: The natural language question to ask about the book
    ///   - noSpoilers: Whether to avoid revealing plot spoilers in the response (default: false)
    /// - Returns: A BookQueryResponse containing the AI-generated answer and relevant context
    /// - Throws: CustomAPIError if the query fails
    func queryBook(bookId: Int, query: String, noSpoilers: Bool = false) async throws -> BookQueryResponse {
        isLoading = true
        defer { isLoading = false }
        
        let endpoint = "books/query/\(bookId)?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&no_spoilers=\(noSpoilers)"
        
        do {
            let response: BookQueryResponse = try await apiService.get(endpoint: endpoint)
            return response
        } catch {
            logger.error("Failed to query book: \(error.localizedDescription)")
            throw error
        }
    }
}

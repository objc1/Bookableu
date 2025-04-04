//
//  Book.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 15/02/2025.
//  Updated to work with Python backend

import Foundation
import SwiftData
import SwiftUI

/// Represents the supported file formats for books in the application
enum BookType: String, Codable {
    case pdf
    case epub
    case other
}

/// Represents the current reading status of a book
enum ReadingStatus: String, Codable {
    case notStarted = "not_started"  // Book has been added but not opened
    case reading = "reading"         // Book is currently being read
    case completed = "completed"     // Book has been finished
    case processing = "processing"   // Book is being processed (e.g., metadata extraction)
}

/// A model representing a book in the application.
/// This class manages both local and remote book data, including reading progress,
/// metadata, and synchronization status.
@Model
class Book {
    // MARK: - Local Properties
    
    /// The title of the book
    var title: String
    
    /// The filename of the book's source file
    var fileName: String
    
    /// The local URL where the book file is stored
    var fileURL: URL?
    
    /// Total number of pages in the book
    var totalPages: Int
    
    /// Current page number the user is on (0-based)
    var currentPage: Int = 0
    
    /// The author of the book (optional)
    var author: String?
    
    /// The file format of the book (PDF, EPUB, or other)
    var bookType: BookType = BookType.other
    
    /// Current reading status of the book
    var readingStatus: ReadingStatus = ReadingStatus.notStarted
    
    /// Timestamp of when the book was last opened
    var lastOpened: Date?
    
    /// Binary data of the book's cover image
    var coverImage: Data?
    
    /// User's notes about the book
    var notes: String?
    
    // MARK: - Remote Properties
    
    /// Unique identifier for the book on the remote server
    var remoteId: String?
    
    /// Indicates whether the book's metadata has been extracted
    var isExtracted: Bool = false
    
    /// Timestamp of the last successful sync with the remote server
    var lastSync: Date?
    
    // MARK: - Initialization
    
    /// Creates a new book instance with basic information
    /// - Parameters:
    ///   - title: The title of the book
    ///   - fileName: The name of the book's file
    ///   - totalPages: Total number of pages in the book
    ///   - author: Optional author of the book
    init(title: String, fileName: String, totalPages: Int, author: String? = nil) {
        self.title = title
        self.fileName = fileName
        self.totalPages = totalPages
        self.author = author
        
        // Automatically determine the book type based on file extension
        if fileName.lowercased().hasSuffix(".pdf") {
            self.bookType = .pdf
        } else if fileName.lowercased().hasSuffix(".epub") {
            self.bookType = .epub
        } else {
            self.bookType = .other
        }
    }
    
    // MARK: - Codable Implementation
    
    /// Coding keys for the Book model
    enum CodingKeys: String, CodingKey {
        case title, fileName, fileURL, totalPages, currentPage, author, bookType, readingStatus, lastOpened, coverImage, notes, remoteId, isExtracted, lastSync
    }
    
    /// Initializes a book from a decoder, handling both new and legacy data formats
    /// - Parameter decoder: The decoder containing the book data
    /// - Throws: DecodingError if the data is invalid
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties
        title = try container.decode(String.self, forKey: .title)
        fileName = try container.decode(String.self, forKey: .fileName)
        fileURL = try container.decodeIfPresent(URL.self, forKey: .fileURL)
        totalPages = try container.decode(Int.self, forKey: .totalPages)
        currentPage = try container.decode(Int.self, forKey: .currentPage)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        readingStatus = try container.decode(ReadingStatus.self, forKey: .readingStatus)
        lastOpened = try container.decodeIfPresent(Date.self, forKey: .lastOpened)
        coverImage = try container.decodeIfPresent(Data.self, forKey: .coverImage)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        remoteId = try container.decodeIfPresent(String.self, forKey: .remoteId)
        isExtracted = try container.decode(Bool.self, forKey: .isExtracted)
        lastSync = try container.decodeIfPresent(Date.self, forKey: .lastSync)
        
        // Initialize bookType with default value
        bookType = .other
        
        // Try to decode bookType from container or determine from filename
        if let decodedBookType = try? container.decodeIfPresent(BookType.self, forKey: .bookType) {
            bookType = decodedBookType
        } else {
            // Fallback to determining type from filename for legacy data
            let lowerFileName = fileName.lowercased()
            if lowerFileName.hasSuffix(".pdf") {
                bookType = .pdf
            } else if lowerFileName.hasSuffix(".epub") {
                bookType = .epub
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Calculates the reading progress as a percentage (0.0 to 1.0)
    var readingProgress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }
    
    /// Determines if the book needs to be synced with the remote server
    /// Returns true if the last sync was more than an hour ago or if never synced
    var needsSync: Bool {
        guard let lastSync = lastSync else { return true }
        return Date().timeIntervalSince(lastSync) > 3600 // Sync if last sync was more than an hour ago
    }
    
    // MARK: - Public Methods
    
    /// Updates the last sync timestamp to the current time
    func markAsSynced() {
        lastSync = Date()
    }
    
    /// Updates the reading progress and handles related status changes
    /// - Parameter page: The new page number to set
    func updateProgress(page: Int) {
        let newPage = max(0, min(page, totalPages))
        
        // Special handling for single-page documents
        if totalPages <= 1 && newPage > 0 {
            currentPage = totalPages
            readingStatus = .completed
            lastOpened = Date()
            return
        }
        
        // Only update if there's an actual change
        if currentPage != newPage {
            currentPage = newPage
            
            // Update reading status based on progress
            if currentPage == 0 {
                readingStatus = .notStarted
            } else if currentPage >= totalPages {
                readingStatus = .completed
            } else {
                readingStatus = .reading
            }
            
            // Update last opened timestamp
            lastOpened = Date()
        }
    }

        func generateLetterCover() -> UIImage {
        let width: CGFloat = 200
        let height: CGFloat = 280
        
        // Get first letter (or "?" if empty title)
        let letter = String(title.prefix(1).uppercased())
        
        // Generate consistent color based on book title
        let hash = abs(title.hashValue)
        let hue = CGFloat(hash % 256) / 256.0
        let color = UIColor(hue: hue, saturation: 0.7, brightness: 0.8, alpha: 1.0)
        
        // Create renderer and draw
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            // Draw background
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            
            // Draw letter
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 100, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            
            let textSize = letter.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (width - textSize.width) / 2,
                y: (height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            letter.draw(in: textRect, withAttributes: attributes)
        }
    }
}

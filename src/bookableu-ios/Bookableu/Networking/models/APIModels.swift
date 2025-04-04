//
//  APIModels.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 10/03/2025.
//  Updated to match Python FastAPI backend

import Foundation

// MARK: - API Request/Response Models
// This file contains all the data models used for API communication between the iOS app and the backend server.
// Models are structured to match the FastAPI backend's data structures and include proper Codable conformance.

// MARK: - Authentication Models
// Models for handling user authentication and registration
struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let name: String?  // Optional name field for registration
}

struct AuthResponse: Codable {
    let access_token: String
    let token_type: String
    
    enum CodingKeys: String, CodingKey {
        case access_token
        case token_type
    }
}

// MARK: - User Preferences
// Model for storing user preferences and settings
struct Preference: Codable {
    let theme: String?  // UI theme preference (e.g., "light", "dark", "system")
    let notificationsEnabled: Bool?  // Whether push notifications are enabled
    
    enum CodingKeys: String, CodingKey {
        case theme
        case notificationsEnabled
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Set default values if fields are missing
        theme = try container.decodeIfPresent(String.self, forKey: .theme) ?? "default"
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
    }
}

// MARK: - User Profile
// Comprehensive model for user profile data with flexible decoding
struct UserProfile: Codable, Identifiable {
    // Required core identifier fields
    let id: String
    let email: String
    
    // Optional profile information
    var name: String?
    let profile_picture: String?
    let created_at: Date?
    let updated_at: Date?
    let preferences: Preference?
    let books_finished: Int?
    
    // Additional user metadata
    let role: String?
    let is_active: Bool?
    let last_login: Date?
    
    // Manual initializer for creating instances
    init(
        id: String,
        email: String,
        name: String? = nil,
        profile_picture: String? = nil,
        created_at: Date? = nil,
        updated_at: Date? = nil,
        preferences: Preference? = nil,
        books_finished: Int? = 0,
        role: String? = nil,
        is_active: Bool? = nil,
        last_login: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.profile_picture = profile_picture
        self.created_at = created_at
        self.updated_at = updated_at
        self.preferences = preferences
        self.books_finished = books_finished
        self.role = role
        self.is_active = is_active
        self.last_login = last_login
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case profile_picture
        case created_at
        case updated_at
        case preferences
        case books_finished
        case role
        case is_active
        case last_login
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        do {
            id = try container.decode(String.self, forKey: .id)
        } catch {
            // Try to decode as Int and convert to String if needed
            if let idInt = try? container.decode(Int.self, forKey: .id) {
                id = String(idInt)
            } else {
                print("Failed to decode id field: \(error)")
                throw error
            }
        }
        
        do {
            email = try container.decode(String.self, forKey: .email)
        } catch {
            print("Failed to decode email field: \(error)")
            throw error
        }
        
        // Optional fields
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        profile_picture = try? container.decodeIfPresent(String.self, forKey: .profile_picture)
        
        // Parse books_finished more flexibly
        if let booksFinished = try? container.decodeIfPresent(Int.self, forKey: .books_finished) {
            books_finished = booksFinished
        } else if let booksFinishedStr = try? container.decodeIfPresent(String.self, forKey: .books_finished),
                  let booksFinishedNum = Int(booksFinishedStr) {
            books_finished = booksFinishedNum
        } else {
            books_finished = 0
        }
        
        // Parse preferences
        preferences = try? container.decodeIfPresent(Preference.self, forKey: .preferences)
        
        // Boolean and string fields
        role = try? container.decodeIfPresent(String.self, forKey: .role)
        is_active = try? container.decodeIfPresent(Bool.self, forKey: .is_active)
        
        // Date fields - handle with care using static method
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .created_at) {
            created_at = UserProfile.parseDate(dateString)
        } else {
            created_at = nil
        }
        
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .updated_at) {
            updated_at = UserProfile.parseDate(dateString)
        } else {
            updated_at = nil
        }
        
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .last_login) {
            last_login = UserProfile.parseDate(dateString)
        } else {
            last_login = nil
        }
    }
    
    // Static helper function to parse dates
    static func parseDate(_ dateString: String) -> Date? {
        // Try ISO8601 first
        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // Fall back to other formats
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd"] {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }
        
        print("Failed to parse date string: \(dateString)")
        return nil
    }
}

// MARK: - Dynamic Coding Support
// Utilities for handling flexible JSON decoding with dynamic keys
struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

// MARK: - Decoding Extensions
// Extension to support decoding of various data types
extension KeyedDecodingContainer {
    func decodeAnyIfPresent(forKey key: K) -> Any? {
        // Try each type in sequence
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Float.self, forKey: key) {
            return value
        }
        // Can't handle nested containers with this simpler approach
        return nil
    }
}

// MARK: - Flexible JSON Decoder
// Custom decoder implementation to handle various JSON formats and date strings
class FlexibleDecoder {
    static func decode<T>(data: Data, type: T.Type) -> T? where T: Decodable {
        // Try standard decoding
        if let result = try? JSONDecoder().decode(type, from: data) {
            return result
        }
        
        // Try with snake case
        let snakeCaseDecoder = JSONDecoder()
        snakeCaseDecoder.keyDecodingStrategy = .convertFromSnakeCase
        if let result = try? snakeCaseDecoder.decode(type, from: data) {
            return result
        }
        
        // Try with custom date handling
        let dateDecoder = JSONDecoder()
        dateDecoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // First try ISO8601
            let iso8601Formatter = ISO8601DateFormatter()
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            
            // Fall back to other formats
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd"] {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, 
                debugDescription: "Cannot decode date string \(dateString)")
        }
        
        if let result = try? dateDecoder.decode(type, from: data) {
            return result
        }
        
        // Try with combined strategies
        let combinedDecoder = JSONDecoder()
        combinedDecoder.keyDecodingStrategy = .convertFromSnakeCase
        combinedDecoder.dateDecodingStrategy = dateDecoder.dateDecodingStrategy
        
        if let result = try? combinedDecoder.decode(type, from: data) {
            return result
        }
        
        return nil
    }
    
    // Convert raw JSON to dictionary
    static func jsonToDictionary(data: Data) -> [String: Any]? {
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

// MARK: - Profile Update
// Model for updating user profile information
struct UpdateProfileRequest: Codable {
    let name: String?
}

// MARK: - Book Models
// Models for handling book-related data and operations
enum BookStatus: String, Codable {
    case unread = "unread"      // Book has been added but not started
    case reading = "reading"    // Book is currently being read
    case finished = "finished"  // Book has been completed
    case processing = "processing"  // Book is being processed by the backend
}

// Metadata about book processing and indexing
struct BookMetadata: Codable {
    let extracted: Bool?        // Whether text has been extracted from the book
    let index_key: String?      // Key for accessing the book's search index
}

// Main book model representing a book in the user's library
struct BookModel: Codable, Identifiable {
    let id: Int
    let title: String
    let file_key: String
    let text_key: String?
    let author: String?
    let total_pages: Int?
    let current_page: Int
    let status: BookStatus
    let user_id: String
    var book_metadata: BookMetadata?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case file_key
        case text_key
        case author
        case total_pages
        case current_page
        case status
        case user_id
        case book_metadata
    }
}

// MARK: - API Response Types
struct BookResponse: Codable, Identifiable {
    let id: Int
    let title: String
    let author: String
    let totalPages: Int
    let fileName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case totalPages = "total_pages"
        case fileName = "file_key"
    }
}

// Response model for successful book upload
struct BookUploadResponse: Codable, Identifiable {
    let id: Int
    let title: String
    let file_key: String
}

// Model for updating book status and progress
struct BookUpdateRequest: Codable {
    let status: BookStatus?
    let current_page: Int?
}

// MARK: - Query Models
// Models for handling book content queries and search results
struct BookQueryResponse: Codable {
    let results: [QueryResult]  // Array of matching text segments
    let chat_answer: String     // AI-generated response to the query
}

struct QueryResult: Codable {
    let text: String           // The matching text segment
    let similarity_score: Float // Relevance score of the match
    let chunk_index: Int       // Position of the text in the book
}

// MARK: - Utility Models
// Simple models for basic API operations
struct EmptyRequest: Codable {}  // Used for endpoints that don't require request body
struct EmptyResponse: Codable {} // Used for endpoints that don't return data

struct StatusResponse: Codable {
    let success: Bool
    let message: String
}

struct DownloadResponse: Codable {
    let download_url: String  // URL for downloading book content
}

// MARK: - LLM Configuration
// Models for managing Large Language Model preferences and settings
struct LLMPreferences: Codable {
    let model: String?           // Name of the LLM model to use
    let temperature: Float?      // Controls randomness in responses (0.0-1.0)
    let max_tokens: Int?        // Maximum length of generated responses
    let instruction_style: String?  // Style of instructions to use with the model
}

struct LLMPreferencesResponse: Codable {
    let success: Bool
    let preferences: LLMPreferences
}

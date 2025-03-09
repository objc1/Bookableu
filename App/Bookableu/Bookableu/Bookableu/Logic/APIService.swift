//
//  APIService.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 20/02/2025.
//

import Foundation
import PDFKit
import os.log

/// A structure for decoding the Mistral model's response from the Hugging Face API.
struct MistralResponse: Decodable {
    let generatedText: String
    
    enum CodingKeys: String, CodingKey {
        case generatedText = "generated_text"
    }
}

/// Configuration for the APIService.
struct APIConfig {
    static let baseURL = "https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.3"
    static let maxContextCharacters = 20_000 // Increased from 10,000
    static let defaultParameters: [String: Any] = [
        "max_new_tokens": 500, // Increased from 150
        "temperature": 0.7,
        "return_full_text": false
    ]
}

/// A service class for interacting with the Mistral AI model via the Hugging Face Inference API.
class APIService: ObservableObject {
    // MARK: - Properties
    
    private let apiKey: String
    private let urlSession: URLSession
    private let config = APIConfig()
    private let logger = Logger(subsystem: "Bookableu", category: "APIService")
    
    // MARK: - Initialization
    
    init(apiKey: String = "", urlSession: URLSession = .shared) {
        self.apiKey = apiKey.isEmpty ? UserDefaults.standard.string(forKey: "mistralAPIKey") ?? "" : apiKey
        self.urlSession = urlSession
    }
    
    // MARK: - API Methods
    
    func sendRequest(for book: Book?, query: String) async throws -> String {
        try validateInput(apiKey: apiKey, query: query)
        
        let url = try validateURL(string: APIConfig.baseURL)
        let prompt = try buildPrompt(book: book, query: query)
        logger.debug("Prompt sent: \(prompt, privacy: .public)")
        
        let request = try createRequest(url: url, prompt: prompt)
        let (data, response) = try await urlSession.data(for: request)
        
        if let rawResponse = String(data: data, encoding: .utf8) {
            logger.debug("Raw API response: \(rawResponse, privacy: .public)")
        }
        
        _ = try validateResponse(response)
        return try decodeResponse(data: data)
    }
    
    // MARK: - Request Helpers
    
    private func validateInput(apiKey: String, query: String) throws {
        guard !apiKey.isEmpty else { throw APIError.missingAPIKey }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.invalidQuery
        }
    }
    
    private func validateURL(string: String) throws -> URL {
        guard let url = URL(string: string) else { throw URLError(.badURL) }
        return url
    }
    
    private func createRequest(url: URL, prompt: String) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["inputs": prompt, "parameters": APIConfig.defaultParameters]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    private func validateResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200: return httpResponse
        case 401: throw APIError.unauthorized
        case 429: throw APIError.rateLimitExceeded
        default: throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    private func decodeResponse(data: Data) throws -> String {
        let results = try JSONDecoder().decode([MistralResponse].self, from: data)
        guard let generatedText = results.first?.generatedText, !generatedText.isEmpty else {
            throw APIError.noOutput
        }
        if generatedText.hasSuffix("...") || generatedText.count < 50 { // Heuristic for truncation
            logger.warning("Possible truncated response detected: \(generatedText, privacy: .public)")
            throw APIError.truncatedResponse(generatedText)
        }
        return generatedText
    }
    
    // MARK: - Prompt Building
    
    private func buildPrompt(book: Book?, query: String) throws -> String {
        guard let book = book else { return "[INST] \(query) [/INST]" }
        
        guard let bookContent = extractTextFromBook(at: book.fileURL) else {
            throw APIError.contentExtractionFailed
        }
        
        let optimizedContent = optimizeContent(bookContent, for: query)
        return "[INST] Based on the following book content, answer the question: \(query)\n\nContent: \(optimizedContent) [/INST]"
    }
    
    private func optimizeContent(_ content: String, for query: String) -> String {
        let queryWords = tokenizeQuery(query)
        let contentLowercased = content.lowercased()
        var scoredSnippets: [(range: Range<String.Index>, score: Int)] = []
        let windowSize = APIConfig.maxContextCharacters / 4 // Smaller window for precision
        
        for word in queryWords {
            var searchStart = contentLowercased.startIndex
            while let range = contentLowercased[searchStart...].range(of: word) {
                let start = contentLowercased.index(range.lowerBound, offsetBy: -1 * windowSize, limitedBy: contentLowercased.startIndex) ?? contentLowercased.startIndex
                let end = contentLowercased.index(range.upperBound, offsetBy: windowSize, limitedBy: contentLowercased.endIndex) ?? contentLowercased.endIndex
                let existing = scoredSnippets.firstIndex { $0.range == start..<end }
                if let index = existing {
                    scoredSnippets[index].score += 1
                } else {
                    scoredSnippets.append((start..<end, 1))
                }
                searchStart = range.upperBound
            }
        }
        
        let sortedSnippets = scoredSnippets.sorted { $0.score > $1.score }
        var optimizedText = ""
        for snippet in sortedSnippets {
            let text = String(content[snippet.range])
            if optimizedText.count + text.count <= APIConfig.maxContextCharacters {
                optimizedText += text + "\n"
            } else {
                let remainingSpace = APIConfig.maxContextCharacters - optimizedText.count
                optimizedText += String(text.prefix(remainingSpace))
                break
            }
        }
        
        return optimizedText.isEmpty ? String(content.prefix(APIConfig.maxContextCharacters)) : optimizedText
    }
    
    private func tokenizeQuery(_ query: String) -> [String] {
        query.lowercased()
            .split(separator: " ", omittingEmptySubsequences: true)
            .flatMap { $0.split(whereSeparator: { !($0.isLetter || $0.isNumber) }) }
            .map(String.init)
            .filter { !$0.isEmpty }
    }
    
    private func mergeRanges(_ ranges: [Range<String.Index>]) -> [Range<String.Index>] {
        let sortedRanges = ranges.sorted { $0.lowerBound < $1.lowerBound }
        var merged: [Range<String.Index>] = []
        
        for range in sortedRanges {
            if let last = merged.last, last.upperBound >= range.lowerBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        return merged
    }
    
    // MARK: - Text Extraction
    
    private func extractTextFromBook(at url: URL) -> String? {
        let fileExtension = url.pathExtension.lowercased()
        switch fileExtension {
        case "pdf": return extractTextFromPDF(at: url)
        case "epub": return extractTextFromEPUB(at: url)
        default:
            logger.error("Unsupported file type: \(fileExtension, privacy: .public)")
            return nil
        }
    }
    
    private func extractTextFromPDF(at url: URL) -> String? {
        guard let pdfDocument = PDFDocument(url: url) else {
            logger.error("Unable to load PDF from \(url.absoluteString, privacy: .public)")
            return nil
        }
        let fullText = (0..<pdfDocument.pageCount)
            .compactMap { pdfDocument.page(at: $0)?.string }
            .joined(separator: "\n")
        return fullText.isEmpty ? nil : fullText
    }
    
    private func extractTextFromEPUB(at url: URL) -> String? {
        do {
            let chapterURLs = try EPUBManager.shared.prepareEPUB(from: url)
            let fullText = chapterURLs
                .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
                .map(stripHTML)
                .joined(separator: "\n")
            return fullText.isEmpty ? nil : fullText
        } catch {
            logger.error("Failed to extract text from EPUB: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    private func stripHTML(from html: String) -> String {
        guard let data = html.data(using: .utf8),
              let attributedString = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html,
                          .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
              ) else {
            return html
        }
        return attributedString.string
    }
}

// MARK: - Error Types

enum APIError: Error, LocalizedError {
    case missingAPIKey
    case invalidQuery
    case contentExtractionFailed
    case invalidResponse
    case unauthorized
    case rateLimitExceeded
    case serverError(statusCode: Int)
    case noOutput
    case truncatedResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "API key is missing. Please configure it in settings."
        case .invalidQuery: return "Query cannot be empty."
        case .contentExtractionFailed: return "Failed to extract book content."
        case .invalidResponse: return "Invalid server response."
        case .unauthorized: return "Unauthorized: Invalid API key."
        case .rateLimitExceeded: return "Rate limit exceeded. Try again later."
        case .serverError(let statusCode): return "Server error: HTTP \(statusCode)"
        case .noOutput: return "No response generated by the model."
        case .truncatedResponse(let text): return "Response appears truncated: \(text.prefix(50))..."
        }
    }
}

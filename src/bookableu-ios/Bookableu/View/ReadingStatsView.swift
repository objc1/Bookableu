//
//  ReadingStatsView.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 09/04/2025.
//

import SwiftUI
import SwiftData

struct ReadingStatsView: View {
    // MARK: - Properties
    
    // Query
    @Query private var books: [Book]  // Fetch all books
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Computed Properties
    
    private var totalPagesRead: Int {
        books.reduce(into: 0) { total, book in
            if book.readingStatus == .completed {
                total += book.totalPages
            } else if book.readingStatus == .reading {
                total += book.currentPage
            }
        }
    }
    
    private var averageProgress: String {
        guard !books.isEmpty else { return "0%" }
        
        let totalProgress = books.reduce(into: 0.0) { result, book in
            result += (Double(book.currentPage) / Double(book.totalPages)) * 100
        }
        
        return "\(Int(totalProgress / Double(books.count)))%"
    }
    
    private var daysUsingSince: Int {
        let defaults = UserDefaults.standard
        let firstUseKey = "firstUseDate"
        
        // If first use date doesn't exist, set it to now
        if defaults.object(forKey: firstUseKey) == nil {
            defaults.set(Date(), forKey: firstUseKey)
        }
        
        guard let firstUseDate = defaults.object(forKey: firstUseKey) as? Date else {
            return 0
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: firstUseDate, to: Date())
        return max(components.day ?? 0, 1) // At least 1 day
    }
    
    private var averagePagesPerDay: String {
        let days = daysUsingSince
        guard days > 0 else { return "0" }
        
        let pagesPerDay = Double(totalPagesRead) / Double(days)
        return String(format: "%.1f", pagesPerDay)
    }
    
    private var completedBooksCount: Int {
        books.filter { $0.readingStatus == .completed }.count
    }
    
    // MARK: - Body
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Books in Library")
                    Spacer()
                    Text("\(books.count)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Books Completed")
                    Spacer()
                    Text("\(completedBooksCount)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Pages Read")
                    Spacer()
                    Text("\(totalPagesRead)")
                        .foregroundColor(.secondary)
                }
                
                if !books.isEmpty {
                    HStack {
                        Text("Average Progress")
                        Spacer()
                        Text(averageProgress)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Avg. Pages Per Day")
                    Spacer()
                    Text(averagePagesPerDay)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Days Using Bookableu")
                    Spacer()
                    Text("\(daysUsingSince)")
                        .foregroundColor(.secondary)
                }
            }
            
            // Additional reading stats could be added here in the future
            Section(header: Text("Reading Habits")) {
                Text("More detailed reading statistics will be available in future updates.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Reading Statistics")
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        ReadingStatsView()
    }
} 

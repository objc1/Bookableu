//
//  ProgressBar.swift
//  BookableuV2
//
//  Created by Maxim Leypunskiy on 08/03/2025.
//

import SwiftUI

struct ProgressBar: View {
    let currentPage: Int
    let totalPages: Int
    
    // Internal scroll progress calculation
    private var scrollProgress: Double {
        guard totalPages > 0 else { return 0.0 }
        return Double(currentPage) / Double(totalPages)
    }
    
    // Check if we're dealing with a single-page document
    private var isSinglePage: Bool {
        return totalPages <= 1
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    // For single-page documents, show complete progress
                    // For multi-page documents, show proportional progress
                    Rectangle()
                        .fill(Color.blue)
                        .frame(
                            width: isSinglePage ? geometry.size.width : max(0, min(geometry.size.width * CGFloat(scrollProgress), geometry.size.width)),
                            height: 4
                        )
                }
            }
            .frame(height: 4)
            
            HStack {
                if isSinglePage {
                    Text("Single page document")
                        .font(.caption)
                    Spacer()
                    Text("Complete")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Page: \(currentPage + 1) of \(totalPages)")
                        .font(.caption)
                    Spacer()
                    Text("Progress: \(Int(scrollProgress * 100))%")
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

// Preview provider
#Preview {
    ProgressBar(
        currentPage: 5,
        totalPages: 100
    )
}

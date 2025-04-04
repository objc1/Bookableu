//
//  SocialView.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 10/02/2025.
//

import SwiftUI

struct SocialView: View {
    var body: some View {
        VStack {
            Text("Social Features")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 10)
            
            Text("Coming Soon!")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Image(systemName: "person.3.fill")
                .font(.system(size: 100))
                .padding(.top, 40)
                .foregroundColor(.blue.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    SocialView()
} 
//
//  NavView.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 10/02/2025.
//

import SwiftUI

struct NavView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
//            ChatView(book: Book(title: "", fileName: ""))
//                .tabItem {
//                    Label("Chat", systemImage: "ellipsis.message.fill")
//                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    NavView()
}

//
//  BookableuApp.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 20/02/2025.
//

import SwiftUI
import SwiftData

@main
struct BookableuApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Book.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            NavView()
        }
        .modelContainer(sharedModelContainer)
    }
}

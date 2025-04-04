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
    @StateObject private var userProvider = UserProvider()
    @StateObject private var bookService = BookService()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Book.self,
        ])
        
        let isRunningOnMac: Bool = {
            #if targetEnvironment(macCatalyst)
            return true
            #elseif os(macOS)
            return true
            #else
            if #available(iOS 14.0, *) {
                return ProcessInfo.processInfo.isiOSAppOnMac
            }
            return false
            #endif
        }()
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isRunningOnMac
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Log the error and try a more aggressive approach
            print("SwiftData error: \(error)")
            
            // If the standard initialization fails, try with destructive migration
            do {
                let recoveryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                return try ModelContainer(for: schema, configurations: [recoveryConfig])
            } catch {
                fatalError("Could not create ModelContainer even with destructive migration: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if userProvider.isAuthenticated {
                    NavView()
                        .environmentObject(userProvider)
                        .environmentObject(bookService)
                } else {
                    AuthView()
                        .environmentObject(userProvider)
                }
            }
            .modelContainer(sharedModelContainer)
        }
    }
}

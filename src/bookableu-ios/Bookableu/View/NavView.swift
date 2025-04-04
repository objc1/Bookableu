//
//  NavView.swift
//  Bookableu
//
//  Created by Maxim Leypunskiy on 10/02/2025.
//

import SwiftUI

struct NavView: View {
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedTab = 0
    @EnvironmentObject private var userProvider: UserProvider
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            SocialView()
                .tabItem {
                    Label("Social", systemImage: "person.3.fill")
                }
                .tag(1)
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .onAppear {
            // Initialize API configuration
            setupErrorHandling()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func setupErrorHandling() {
        // Set up global error handler for uncaught exceptions
        NSSetUncaughtExceptionHandler(exceptionHandler)
    }
    
    // Global exception handler
    private let exceptionHandler: @convention(c) (NSException) -> Void = { exception in
        print("Uncaught exception: \(exception.name), reason: \(exception.reason ?? "unknown"), userInfo: \(exception.userInfo ?? [:])")
    }
}

#Preview {
    NavView()
        .environmentObject(UserProvider())
}

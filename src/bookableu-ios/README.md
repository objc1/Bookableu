# Bookableu

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2016.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

<img src="../../demo/logo.png" width="200" style="border-radius: 20px;"/>

<p>A modern, feature-rich e-reader application for iOS that allows users to read, manage, and share their e-book collection.</p>

## Features

- **Multiple Format Support**: Read PDF and EPUB documents seamlessly
- **Library Management**: Organize and manage your entire book collection
- **Reading Preferences**: Customize your reading experience with font settings, themes, and more
- **Reading Statistics**: Track your reading habits and progress with visual analytics
- **Cloud Synchronization**: Access your library across multiple devices with seamless sync
- **Social Features**: Share your reading activity and connect with other readers
- **Chat**: Discuss books with other users in real-time

## Getting Started

### Prerequisites

- Xcode 14.0 or later
- iOS 16.0 or later
- macOS Ventura or later (for development)
- Swift 5.9 or later

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/Bookableu.git
```

2. Open the project in Xcode:
```bash
cd Bookableu
open Bookableu.xcodeproj
```

3. Configure your signing certificate in the project settings

4. Build and run the application on your device or simulator

### Secrets Management

Bookableu uses a configuration file to manage API keys and other sensitive information:

1. Create a copy of `Config.xcconfig.example` and rename it to `Config.xcconfig`
2. Fill in your API keys and other required secrets
3. Never commit your `Config.xcconfig` file to version control

The app uses KeychainService to securely store user credentials and sensitive data locally on the device. API keys for external services are managed through environment variables in the build configuration.

## Project Structure

```
Bookableu/
├── Info.plist                             # App configuration and permissions
├── Config.xcconfig                        # Environment variables and API keys
├── Logic/                                 # Business logic and utilities
│   ├── Configuration.swift                # App configuration and settings
│   ├── DocumentPicker.swift               # File selection and import logic
│   └── EPUBManager.swift                  # EPUB file processing and rendering
├── BookableuApp.swift                     # App entry point and main configuration
├── Model/                                 # Data models and persistence layer
│   ├── Book.swift                         # Core book data model
│   └── UserProvider.swift                 # User authentication and profile management
├── View/                                  # SwiftUI views and UI components
│   ├── LibraryView.swift                  # Main book collection view
│   ├── AuthView.swift                     # Authentication view
│   ├── PDFReaderView.swift                # PDF document reader
│   ├── EPUBReaderView.swift               # EPUB document reader
│   ├── BookReaderView.swift               # Generic reader container
│   ├── SettingsView.swift                 # User preferences and settings
│   ├── ReadingStatsView.swift             # Reading statistics and analytics
│   ├── ChatView.swift                     # User messaging interface
│   ├── BookDetailView.swift               # Detailed book information view
│   ├── SocialView.swift                   # Social interactions and sharing
│   ├── AboutView.swift                    # App information and credits
│   ├── NavView.swift                      # Navigation container
│   ├── ProgressBar.swift                  # Reading progress visualization
│   ├── LibraryManagementView.swift        # Library organization tools
│   ├── ReadingPreferencesView.swift       # Reading settings configuration
│   └── Base.lproj/                        # Base localization resources
├── Networking/                            # API services and networking code
│   ├── CustomAPIService.swift             # Main API client
│   ├── KeychainService.swift              # Secure credential storage
│   ├── routes/                            # API route definitions
│   │   ├── UserService.swift              # User profile API endpoints
│   │   ├── AuthService.swift              # Authentication API endpoints
│   │   └── BookService.swift              # Book management API endpoints
│   └── models/                            # Network data models
│       └── APIModels.swift                # API request/response data structures
└── Assets.xcassets/                       # App assets, icons, and images
```

## Architecture

Bookableu is built using SwiftUI and follows the MVVM (Model-View-ViewModel) architecture:

- **Model**: Core data structures like `Book`
- **View**: SwiftUI views for displaying content and handling user interactions
- **Networking**: API services for backend communication
- **Logic**: Business logic and app functionality

## Key Components

- **SwiftData**: Used for local data persistence and offline access to books
- **Authentication**: Secure user authentication system with token management
- **Book Processing**: Parses and displays different book formats with customizable reading experience
- **Preferences Management**: Handles user reading preferences, themes, and accessibility settings
- **Custom API Services**: Communicates with backend services for library synchronization

## Usage

### Adding Books to Your Library

1. Tap the "+" button in the Library view
2. Select a book file from your device or cloud storage
3. The book will be processed and added to your library

### Reading a Book

1. Tap on a book in your library
2. Use the reader controls to navigate, adjust settings, or add notes
3. Your progress is automatically saved

## Code Statistics

The project consists of the following code distribution:

```
-------------------------------------------------------------------------------
Language                     files          blank        comment           code
-------------------------------------------------------------------------------
Swift                           27            833            779           4536
XML                              6              0              0            161
Markdown                         1             40              0            140
JSON                             4              0              0             74
-------------------------------------------------------------------------------
SUM:                            38            873            779           4911
-------------------------------------------------------------------------------
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- [SwiftData](https://developer.apple.com/documentation/swiftdata)
- [PDFKit](https://developer.apple.com/documentation/pdfkit)
- [FolioReaderKit](https://github.com/FolioReader/FolioReaderKit) for EPUB rendering

## Contact

- Email: max.leypunskiy@outlook.com
- Project Link: [https://github.com/yourusername/Bookableu](https://github.com/yourusername/Bookableu)

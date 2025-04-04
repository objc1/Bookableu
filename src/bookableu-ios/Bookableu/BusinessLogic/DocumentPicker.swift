import SwiftUI
import UniformTypeIdentifiers
import Foundation

struct DocumentPicker: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let onPick: (Result<URL, Error>) -> Void
    
    init(allowedContentTypes: [UTType] = [.pdf, .epub],
         onPick: @escaping (Result<URL, Error>) -> Void) {
        self.allowedContentTypes = allowedContentTypes
        self.onPick = onPick
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Using importHandler method instead of delegate pattern for better file access reliability
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes)
        // Important: Don't use asCopy here as it can cause permission issues
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }
}

extension DocumentPicker {
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Result<URL, Error>) -> Void
        
        init(onPick: @escaping (Result<URL, Error>) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let sourceURL = urls.first else {
                onPick(.failure(DocumentPickerError.noFileSelected))
                return
            }
            
            // Securely access the resource
            guard sourceURL.startAccessingSecurityScopedResource() else {
                onPick(.failure(DocumentPickerError.accessDenied))
                return
            }
            
            defer {
                sourceURL.stopAccessingSecurityScopedResource()
            }
            
            // Copy to Documents directory
            do {
                let documentsDirectory = try FileManager.default.url(
                    for: .documentDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                
                let destinationURL = documentsDirectory.appendingPathComponent(sourceURL.lastPathComponent)
                
                // Check for duplicate
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    onPick(.failure(DocumentPickerError.duplicateFile))
                    return
                }
                
                // Read the data directly and write to the destination
                let data = try Data(contentsOf: sourceURL)
                try data.write(to: destinationURL)
                
                onPick(.success(destinationURL))
            } catch {
                print("File copy error: \(error)")
                onPick(.failure(DocumentPickerError.fileCopyFailed(error.localizedDescription)))
            }
        }
    }
}

extension DocumentPicker {
    enum DocumentPickerError: LocalizedError, Equatable {
        case noFileSelected
        case cancelled
        case failedToAccessDocumentsDirectory
        case duplicateFile
        case fileCopyFailed(String)
        case accessDenied
        case fileNotFound
        case emptyFile
        
        var errorDescription: String? {
            switch self {
            case .noFileSelected:
                return "No file was selected."
            case .cancelled:
                return "The document picker was cancelled."
            case .failedToAccessDocumentsDirectory:
                return "Failed to access the Documents directory."
            case .duplicateFile:
                return "A file with this name already exists in your library."
            case .fileCopyFailed(let message):
                return "File copy failed: \(message)"
            case .accessDenied:
                return "Permission to access the selected file was denied."
            case .fileNotFound:
                return "The selected file could not be found."
            case .emptyFile:
                return "The selected file is empty."
            }
        }
        
        static func == (lhs: DocumentPickerError, rhs: DocumentPickerError) -> Bool {
            switch (lhs, rhs) {
            case (.noFileSelected, .noFileSelected),
                 (.cancelled, .cancelled),
                 (.failedToAccessDocumentsDirectory, .failedToAccessDocumentsDirectory),
                 (.duplicateFile, .duplicateFile),
                 (.accessDenied, .accessDenied),
                 (.fileNotFound, .fileNotFound),
                 (.emptyFile, .emptyFile):
                return true
            case (.fileCopyFailed(let lhsMsg), .fileCopyFailed(let rhsMsg)):
                return lhsMsg == rhsMsg
            default:
                return false
            }
        }
    }
}

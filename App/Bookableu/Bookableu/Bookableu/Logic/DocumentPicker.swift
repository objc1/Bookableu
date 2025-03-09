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
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
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
            copyFileToDocumentsDirectory(from: sourceURL)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(.failure(DocumentPickerError.cancelled))
        }
        
        private func copyFileToDocumentsDirectory(from sourceURL: URL) {
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                onPick(.failure(DocumentPickerError.failedToAccessDocumentsDirectory))
                return
            }
            
            let destURL = documentsDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            let fileManager = FileManager.default
            
            // Check for duplicate file
            if fileManager.fileExists(atPath: destURL.path) {
                onPick(.failure(DocumentPickerError.duplicateFile))
                return
            }
            
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                try fileManager.copyItem(at: sourceURL, to: destURL)
                onPick(.success(destURL))
            } catch {
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
            }
        }
    }
}

import SwiftUI
import SwiftData
import PhotosUI

struct BookDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var book: Book

    // Local state variables to edit the book properties.
    @State private var title: String
    @State private var author: String
    
    // Local state for cover image editing.
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var coverImage: Image? = nil
    @State private var coverImageData: Data? = nil

    // Initialize the state with the current values from the book.
    init(book: Book) {
        self.book = book
        _title = State(initialValue: book.title)
        _author = State(initialValue: book.author ?? "")
        if let data = book.coverImage, let uiImage = UIImage(data: data) {
            _coverImage = State(initialValue: Image(uiImage: uiImage))
            _coverImageData = State(initialValue: data)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section for displaying and editing the cover image.
                Section(header: Text("Cover Image")) {
                    HStack {
                        Spacer()
                        if let coverImage = coverImage {
                            coverImage
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(10)
                        } else {
                            Image(systemName: "book")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    // Buttons to select or reset the cover image.
                    HStack {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Text("Select Cover Image")
                        }
                        .onChange(of: selectedItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    coverImage = Image(uiImage: uiImage)
                                    coverImageData = data
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button("Reset") {
                            // Reset the cover image and its data.
                            coverImage = nil
                            coverImageData = nil
                            selectedItem = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                // Section for editing the book's title and author.
                Section(header: Text("Book Information")) {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                }
            }
            .navigationTitle("Edit Book")
            .toolbar {
                // Save button: updates the book and saves to the model context.
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
                // Cancel button: dismisses the view.
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    /// Updates the book’s properties and saves the changes.
    private func saveChanges() {
        book.title = title
        book.author = author.isEmpty ? nil : author
        // Update cover image data.
        book.coverImage = coverImageData
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving changes: \(error.localizedDescription)")
        }
    }
}

#Preview {
    BookDetailView(book: Book(title: "Sample Title", fileName: "SampleFile.pdf", totalPages: 1, author: "Sample Author"))
}

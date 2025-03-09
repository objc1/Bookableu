import Foundation
import SwiftData
import UIKit
import SwiftUICore

@Model
final class Book {
    var title: String
    var fileName: String
    var author: String?
    var coverImageData: Data?
    var lastPage: Int = 0
    var totalPages: Int

    init(title: String, fileName: String, totalPages: Int, author: String? = nil, coverImageData: Data? = nil) {
        self.title = title
        self.fileName = fileName
        self.author = author
        self.coverImageData = coverImageData
        self.totalPages = totalPages
    }
    
    var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    var bookType: BookType {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return BookType(rawValue: ext) ?? .unknown
    }
    
    var coverImage: Image? {
        if let data = coverImageData, let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        return nil
    }
}

enum BookType: String {
    case pdf, epub, unknown
}


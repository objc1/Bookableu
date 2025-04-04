import Foundation
import ZipArchive

final class EPUBManager {
    static let shared = EPUBManager()
    
    private init() {}
    
    /// Unzip the EPUB and return URLs for all chapters in reading order.
    func prepareEPUB(from epubURL: URL) throws -> [URL] {
        let destinationFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        try FileManager.default.createDirectory(
            at: destinationFolder,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        print("EPUB URL:", epubURL.absoluteString)
        print("File exists?", FileManager.default.fileExists(atPath: epubURL.path))
        print("Is readable?", FileManager.default.isReadableFile(atPath: epubURL.path))
        
        guard FileManager.default.fileExists(atPath: epubURL.path),
              FileManager.default.isReadableFile(atPath: epubURL.path) else {
            print("File is not accessible")
            throw EPUBError.accessDenied
        }
        
        // Replace with SSZipArchive if needed (add via SPM: https://github.com/ZipArchive/ZipArchive)
        #if os(macOS)
         try FileManager.default.unzipItem(at: epubURL, to: destinationFolder)
        #else
         guard SSZipArchive.unzipFile(atPath: epubURL.path, toDestination: destinationFolder.path) else {
             throw EPUBError.unzipFailed
         }
        #endif
        print("Unzipped to:", destinationFolder.path)
        
        let metaInfURL = destinationFolder
            .appendingPathComponent("META-INF")
            .appendingPathComponent("container.xml")
        
        guard FileManager.default.fileExists(atPath: metaInfURL.path),
              let containerXML = try? String(contentsOf: metaInfURL, encoding: .utf8) else {
            throw EPUBError.missingContainer
        }
        
        guard let opfPath = parseContainerXML(containerXML) else {
            throw EPUBError.missingOPF
        }
        
        let opfURL = destinationFolder.appendingPathComponent(opfPath)
        guard FileManager.default.fileExists(atPath: opfURL.path) else {
            throw EPUBError.missingOPF
        }
        
        let chapterURLs = try parseOPFforAllItems(opfURL: opfURL, baseFolder: opfURL.deletingLastPathComponent())
        return chapterURLs
    }
    
    // MARK: - Helper Parsing Methods
    
    private func parseContainerXML(_ containerXML: String) -> String? {
        guard let rangeOfFullPath = containerXML.range(of: "full-path=\"") else {
            return nil
        }
        let substringFromFullPath = containerXML[rangeOfFullPath.upperBound...]
        guard let closingQuote = substringFromFullPath.firstIndex(of: "\"") else {
            return nil
        }
        return String(substringFromFullPath[..<closingQuote])
    }
    
    private func parseOPFforAllItems(opfURL: URL, baseFolder: URL) throws -> [URL] {
        let opfContent = try String(contentsOf: opfURL, encoding: .utf8)
        
        // Extract all itemrefs from the spine
        guard let spineRangeStart = opfContent.range(of: "<spine"),
              let spineRangeEnd = opfContent.range(of: "</spine>"),
              spineRangeStart.upperBound < spineRangeEnd.lowerBound else {
            throw EPUBError.noSpineItems
        }
        
        let spineContent = opfContent[spineRangeStart.upperBound..<spineRangeEnd.lowerBound]
        var idrefs: [String] = []
        
        // Find all idrefs in the spine
        var currentIndex = spineContent.startIndex
        while let idrefStart = spineContent[currentIndex...].range(of: "idref=\"") {
            let substringFromIdref = spineContent[idrefStart.upperBound...]
            guard let idrefEnd = substringFromIdref.firstIndex(of: "\"") else { break }
            let idref = String(substringFromIdref[..<idrefEnd])
            idrefs.append(idref)
            currentIndex = idrefEnd
        }
        
        if idrefs.isEmpty {
            throw EPUBError.noSpineItems
        }
        
        // Map idrefs to hrefs in the manifest
        var chapterURLs: [URL] = []
        for idref in idrefs {
            guard let itemRangeStart = opfContent.range(of: "<item id=\"\(idref)\""),
                  let itemRangeEnd = opfContent[itemRangeStart.lowerBound...].range(of: "/>") else {
                continue
            }
            let itemTag = opfContent[itemRangeStart.lowerBound..<itemRangeEnd.upperBound]
            guard let hrefStart = itemTag.range(of: "href=\"") else { continue }
            let substringFromHref = itemTag[hrefStart.upperBound...]
            guard let hrefEnd = substringFromHref.firstIndex(of: "\"") else { continue }
            let href = String(substringFromHref[..<hrefEnd])
            let chapterURL = baseFolder.appendingPathComponent(href)
            chapterURLs.append(chapterURL)
        }
        
        if chapterURLs.isEmpty {
            throw EPUBError.noSpineItems
        }
        return chapterURLs
    }
    
    /// Prepare combined HTML and chapter titles from EPUB (without SWXMLHash)
    func prepareCombinedHTML(from epubURL: URL) throws -> (html: String, titles: [String]) {
        let chapterURLs = try prepareEPUB(from: epubURL)
        
        var combinedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body>
        """
        var chapterTitles: [String] = []
        
        for (index, chapterURL) in chapterURLs.enumerated() {
            guard FileManager.default.fileExists(atPath: chapterURL.path),
                  let chapterContent = try? String(contentsOf: chapterURL, encoding: .utf8) else {
                print("Skipping chapter at \(chapterURL.path) - not found or unreadable")
                continue
            }
            
            // Extract title using basic string matching
            var title = "Chapter \(index + 1)"
            if let titleRangeStart = chapterContent.range(of: "<title>"),
               let titleRangeEnd = chapterContent[titleRangeStart.upperBound...].range(of: "</title>") {
                title = String(chapterContent[titleRangeStart.upperBound..<titleRangeEnd.lowerBound])
            } else if let h1RangeStart = chapterContent.range(of: "<h1"),
                      let h1RangeEnd = chapterContent[h1RangeStart.upperBound...].range(of: "</h1>") {
                title = String(chapterContent[h1RangeStart.upperBound..<h1RangeEnd.lowerBound])
            }
            
            chapterTitles.append(title)
            combinedHTML += "<div id=\"chapter\(index)\">\(chapterContent)</div>"
        }
        
        combinedHTML += "</body></html>"
        
        if chapterTitles.isEmpty {
            throw EPUBError.noSpineItems
        }
        
        return (combinedHTML, chapterTitles)
    }
    
    enum EPUBError: Error {
        case missingContainer
        case missingOPF
        case noSpineItems
        case accessDenied
        case unzipFailed
    }
}

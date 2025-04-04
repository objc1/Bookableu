import SwiftUI
import WebKit

struct EPUBReaderView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    
    // Reference to parent view to access updateReadingProgress method
    var updateProgressCallback: ((Book) -> Void)?
    
    @State private var htmlContent: String = "" // Combined HTML for all chapters
    @State private var chapterTitles: [String] = [] // For chapter navigation
    @State private var errorMessage: String?
    @State private var scrollProgress: Double = 0.0 // For progress bar
    @State private var selectedChapter: Int? = nil // For chapter navigation
    @State private var timer: Timer? = nil // Timer for periodic saving
    
    init(book: Book, updateProgressCallback: ((Book) -> Void)? = nil) {
        self.book = book
        self.updateProgressCallback = updateProgressCallback
    }
    
    var body: some View {
        VStack {
            if !htmlContent.isEmpty {
                WebViewContainer(
                    htmlContent: htmlContent,
                    scrollProgress: $scrollProgress,
                    selectedChapter: $selectedChapter
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: scrollProgress) { _, newValue in
                    // Update estimated page when scroll progress changes significantly
                    let estimatedPage = Int(newValue * Double(book.totalPages))
                    if abs(estimatedPage - book.currentPage) > max(1, book.totalPages / 100) {
                        saveReadingProgress()
                    }
                }
                
                // Progress bar and label
                VStack {
                    ProgressView(value: scrollProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 8)
                    Text("Reading Progress: \(Int(scrollProgress * 100))%")
                        .font(.caption)
                }
                .padding(.horizontal)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.red)
                    Text("Error: \(errorMessage)")
                        .padding()
                }
            } else {
                ProgressView("Loading EPUB…")
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !chapterTitles.isEmpty {
                    Menu("Chapters") {
                        ForEach(0..<chapterTitles.count, id: \.self) { index in
                            Button(chapterTitles[index]) {
                                selectedChapter = index
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            prepareEPUB()
            
            // Set up a timer to periodically save reading progress
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                saveReadingProgress()
            }
        }
        .onDisappear {
            // Invalidate the timer when view disappears
            timer?.invalidate()
            timer = nil
            
            // Save the final reading progress
            saveReadingProgress()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                // Save progress when app moves to background or becomes inactive
                saveReadingProgress()
            }
        }
    }
    
    private func saveReadingProgress() {
        // Update the book model on the main thread
        Task { @MainActor in
            // Update the book model using scroll progress to estimate page
            let estimatedPage = Int(scrollProgress * Double(book.totalPages))
            book.updateProgress(page: estimatedPage)
            
            // Save to local database
            do {
                try modelContext.save()
                print("Saved reading progress locally: \(Int(scrollProgress * 100))%")
                
                // Sync with server if callback is provided
                updateProgressCallback?(book)
            } catch {
                print("Error saving reading progress: \(error.localizedDescription)")
            }
        }
    }
    
    private func prepareEPUB() {
        Task {
            do {
                let (combinedHTML, titles) = try EPUBManager.shared.prepareCombinedHTML(from: book.fileURL!)
                self.htmlContent = combinedHTML
                self.chapterTitles = titles
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct WebViewContainer: UIViewRepresentable {
    let htmlContent: String
    @Binding var scrollProgress: Double
    @Binding var selectedChapter: Int?
    
    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        let parent: WebViewContainer
        
        init(_ parent: WebViewContainer) {
            self.parent = parent
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let contentHeight = scrollView.contentSize.height - scrollView.bounds.height
            let offset = scrollView.contentOffset.y
            if contentHeight > 0 {
                parent.scrollProgress = min(max(offset / contentHeight, 0.0), 1.0)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.isPagingEnabled = false
        webView.scrollView.delegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        
        // Base CSS for readability
        let css = """
        body {
            font-size: 16px;
            line-height: 1.6;
            padding: 15px;
        }
        h1, h2, h3 {
            margin-top: 20px;
        }
        """
        let script = WKUserScript(
            source: "var style = document.createElement('style'); style.innerHTML = '\(css)'; document.head.appendChild(style);",
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        webView.configuration.userContentController.addUserScript(script)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url == nil { // Only load if not already loaded
            uiView.loadHTMLString(htmlContent, baseURL: nil)
        }
        
        if let chapter = selectedChapter {
            uiView.evaluateJavaScript("document.getElementById('chapter\(chapter)').scrollIntoView();") { _, error in
                if let error = error {
                    print("Scroll error: \(error)")
                }
            }
            // Reset selectedChapter after scrolling
            DispatchQueue.main.async {
                self.selectedChapter = nil
            }
        }
    }
}

import SwiftUI
import WebKit

struct EPUBReaderView: View {
    let book: Book
    
    @State private var htmlContent: String = "" // Combined HTML for all chapters
    @State private var chapterTitles: [String] = [] // For chapter navigation
    @State private var errorMessage: String?
    @State private var scrollProgress: Double = 0.0 // For progress bar
    @State private var selectedChapter: Int? = nil // For chapter navigation
    
    var body: some View {
        VStack {
            if !htmlContent.isEmpty {
                WebViewContainer(
                    htmlContent: htmlContent,
                    scrollProgress: $scrollProgress,
                    selectedChapter: $selectedChapter
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
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
        }
    }
    
    private func prepareEPUB() {
        Task {
            do {
                let (combinedHTML, titles) = try EPUBManager.shared.prepareCombinedHTML(from: book.fileURL)
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

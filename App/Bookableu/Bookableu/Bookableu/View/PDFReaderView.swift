import SwiftUI
import PDFKit

struct PDFReaderView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    @State private var currentPage: Int

    init(book: Book) {
        self.book = book
        _currentPage = State(initialValue: book.lastPage)
    }

    var body: some View {
        VStack(spacing: 0) {
            PDFKitView(
                url: book.fileURL,
                currentPage: $currentPage
            )

            Divider()

            ProgressBar(
                currentPage: currentPage,
                totalPages: book.totalPages
            )
        }
        .onDisappear {
            book.lastPage = currentPage
            do {
                try modelContext.save()
            } catch {
                print("Error saving reading progress: \(error.localizedDescription)")
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    @Binding var currentPage: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true)
        pdfView.delegate = context.coordinator

        if let document = PDFDocument(url: url) {
            pdfView.document = document
            if let initialPage = document.page(at: currentPage) {
                pdfView.go(to: initialPage)
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        // Hide scrollbars after PDFView finishes loading its internal scrollView
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            hideScrollIndicators(from: pdfView)
        }

        return pdfView
    }

    private func hideScrollIndicators(from view: UIView) {
        if let scrollView = view as? UIScrollView {
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
        } else {
            for subview in view.subviews {
                hideScrollIndicators(from: subview)
            }
        }
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        guard let document = pdfView.document else { return }

        // Update only if necessary
        if let targetPage = document.page(at: currentPage),
           pdfView.currentPage != targetPage,
           !context.coordinator.isUserScrolling {
            pdfView.go(to: targetPage)
        }
    }

    class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFKitView
        var isUserScrolling = false

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        // Properly handle page changes
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let document = pdfView.document,
                  let currentPDFPage = pdfView.currentPage else { return }

            let newPageIndex = document.index(for: currentPDFPage)
            if parent.currentPage != newPageIndex {
                DispatchQueue.main.async {
                    self.parent.currentPage = newPageIndex
                }
            }
        }

        // Detect scrolling gesture start
        func pdfViewWillBeginDragging(_ pdfView: PDFView) {
            isUserScrolling = true
        }

        // Detect scrolling gesture end
        func pdfViewDidEndDragging(_ pdfView: PDFView, willDecelerate decelerate: Bool) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isUserScrolling = false
            }
        }
    }
}

#Preview {
    PDFReaderView(book: Book(title: "Title", fileName: "", totalPages: 10))
}

import UIKit
import Vision
import PDFKit
import UniformTypeIdentifiers

enum ReceiptScanError: LocalizedError {
    case ocrFailed(String)
    case noTextFound
    case invalidImage
    case invalidPDF
    case cancelled
    case unreadablePDF
    case noPDFText

    var errorDescription: String? {
        switch self {
        case .ocrFailed(let reason): return "OCR failed: \(reason)"
        case .noTextFound: return "Could not detect receipt text. Try a clearer PDF or image."
        case .invalidImage: return "Could not read this image."
        case .invalidPDF: return "Could not read this PDF. Try saving it to Files again or choose another file."
        case .unreadablePDF: return "Could not read this PDF. Try saving it to Files again or choose another file."
        case .noPDFText: return "Could not detect receipt text. Try a clearer PDF or image."
        case .cancelled: return "Scan cancelled."
        }
    }
}

final class ReceiptScanService {

    static let shared = ReceiptScanService()

    private init() {}

    // MARK: - Image OCR

    func recognizeText(from image: UIImage, completion: @escaping (Result<String, ReceiptScanError>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(.invalidImage))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(.ocrFailed(error.localizedDescription)))
                return
            }

            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let lines = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            guard !lines.isEmpty else {
                completion(.failure(.noTextFound))
                return
            }

            let text = lines.joined(separator: "\n")
            completion(.success(text))
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(.ocrFailed(error.localizedDescription)))
            }
        }
    }

    // MARK: - PDF OCR (robust flow)

    /// Process a picked PDF URL. The URL is copied into app-controlled temp storage
    /// first so we never depend on the system Inbox URL remaining valid. We do NOT
    /// rely on QuickLook thumbnails at all.
    func recognizeText(from pdfURL: URL, completion: @escaping (Result<String, ReceiptScanError>) -> Void) {
        print("[ReceiptImport] Picked file URL: \(pdfURL.path)")

        let didStartScoped = pdfURL.startAccessingSecurityScopedResource()
        print("[ReceiptImport] Security scoped access: \(didStartScoped)")
        defer {
            if didStartScoped {
                pdfURL.stopAccessingSecurityScopedResource()
            }
        }

        // Copy to app-controlled temp storage.
        let fm = FileManager.default
        let destinationURL = fm.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        do {
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.removeItem(at: destinationURL)
            }
            try fm.copyItem(at: pdfURL, to: destinationURL)
        } catch {
            print("[ReceiptImport] Copy failed: \(error.localizedDescription)")
            completion(.failure(.unreadablePDF))
            return
        }

        print("[ReceiptImport] Copied PDF to: \(destinationURL.path)")
        let fileExists = fm.fileExists(atPath: destinationURL.path)
        print("[ReceiptImport] File exists after copy: \(fileExists)")

        let data: Data
        do {
            data = try Data(contentsOf: destinationURL)
        } catch {
            print("[ReceiptImport] Data(contentsOf:) failed: \(error.localizedDescription)")
            try? fm.removeItem(at: destinationURL)
            completion(.failure(.unreadablePDF))
            return
        }
        print("[ReceiptImport] Readable data size: \(data.count) bytes")

        // 1) Try PDFKit text extraction first.
        if let pdfText = extractTextWithPDFKit(from: destinationURL) {
            print("[ReceiptImport] PDFKit extracted text length: \(pdfText.count)")
            try? fm.removeItem(at: destinationURL)
            if pdfText.isEmpty {
                completion(.failure(.noPDFText))
            } else {
                completion(.success(pdfText))
            }
            return
        }

        // 2) Fall back to page-render + Vision OCR (scanned PDFs).
        print("[ReceiptImport] Falling back to OCR for scanned PDF")
        recognizeTextByRenderingPages(of: destinationURL) { result in
            try? fm.removeItem(at: destinationURL)
            // QuickLook thumbnail errors are non-fatal; we only fail here if the
            // actual rendering/OCR step produced nothing usable.
            switch result {
            case .success(let text):
                completion(.success(text))
            case .failure(.noTextFound):
                completion(.failure(.noPDFText))
            case .failure(let other):
                completion(.failure(other))
            }
        }
    }

    // MARK: - PDFKit text extraction

    private func extractTextWithPDFKit(from url: URL) -> String? {
        guard let document = PDFDocument(url: url) else {
            print("[ReceiptImport] PDFKit could not open document")
            return nil
        }
        let pageCount = document.pageCount
        print("[ReceiptImport] PDFDocument page count: \(pageCount)")

        var combined = ""
        // Limit text-based extraction to a reasonable page count for V1.
        let textPages = min(pageCount, 10)
        for i in 0..<textPages {
            guard let page = document.page(at: i) else { continue }
            let pageText = page.string ?? ""
            combined += pageText
            combined += "\n"
        }

        let trimmed = combined.trimmingCharacters(in: .whitespacesAndNewlines)
        // If the PDF has very little embedded text, treat as scanned and let OCR try.
        if trimmed.count < 20 {
            return ""
        }
        return trimmed
    }

    // MARK: - Rendered-page OCR fallback

    private func recognizeTextByRenderingPages(of url: URL,
                                               completion: @escaping (Result<String, ReceiptScanError>) -> Void) {
        guard let document = CGPDFDocument(url as CFURL) else {
            completion(.failure(.invalidPDF))
            return
        }
        let totalPages = document.numberOfPages
        let pagesToProcess = min(totalPages, 5)
        print("[ReceiptImport] OCR fallback over \(pagesToProcess) of \(totalPages) pages")

        var collected = ""
        let group = DispatchGroup()
        let lock = NSLock()

        for i in 0..<pagesToProcess {
            guard let page = document.page(at: i + 1) else { continue }
            let pageRect = page.getBoxRect(.mediaBox)
            guard pageRect.width > 0, pageRect.height > 0 else { continue }

            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(pageRect)
                ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
                ctx.cgContext.scaleBy(x: 1, y: -1)
                ctx.cgContext.drawPDFPage(page)
            }

            group.enter()
            recognizeText(from: image) { result in
                defer { group.leave() }
                if case .success(let text) = result {
                    lock.lock()
                    collected += text
                    collected += "\n"
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            let trimmed = collected.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                completion(.failure(.noTextFound))
            } else {
                completion(.success(trimmed))
            }
        }
    }

    // MARK: - Picker presentation

    func presentImagePicker(from viewController: UIViewController, delegate: UIImagePickerControllerDelegate & UINavigationControllerDelegate & UIDocumentPickerDelegate) {
        let alert = UIAlertController(title: "Import Receipt", message: nil, preferredStyle: .actionSheet)

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "Take Photo", style: .default) { _ in
                let picker = UIImagePickerController()
                picker.sourceType = .camera
                picker.delegate = delegate
                viewController.present(picker, animated: true)
            })
        }

        alert.addAction(UIAlertAction(title: "Choose Photo", style: .default) { _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = delegate
            viewController.present(picker, animated: true)
        })

        alert.addAction(UIAlertAction(title: "Choose PDF", style: .default) { _ in
            // asCopy:true hands us an Inbox copy up front, but we still re-copy into
            // our own temp dir in recognizeText(from:) so we don't depend on the
            // Inbox URL or any QuickLook-generated thumbnail.
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
            picker.delegate = delegate
            viewController.present(picker, animated: true)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
        }

        viewController.present(alert, animated: true)
    }
}

import UIKit
import Vision
import UniformTypeIdentifiers

enum ReceiptScanError: LocalizedError {
    case ocrFailed(String)
    case noTextFound
    case invalidImage
    case invalidPDF
    case cancelled

    var errorDescription: String? {
        switch self {
        case .ocrFailed(let reason): return "OCR failed: \(reason)"
        case .noTextFound: return "No text could be read from this receipt."
        case .invalidImage: return "Could not read this image."
        case .invalidPDF: return "Could not read this PDF."
        case .cancelled: return "Scan cancelled."
        }
    }
}

final class ReceiptScanService {

    static let shared = ReceiptScanService()

    private init() {}

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

    func recognizeText(from pdfURL: URL, completion: @escaping (Result<String, ReceiptScanError>) -> Void) {
        guard let document = CGPDFDocument(pdfURL as CFURL) else {
            completion(.failure(.invalidPDF))
            return
        }

        guard let page = document.page(at: 1) else {
            completion(.failure(.invalidPDF))
            return
        }

        let pageRect = page.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let image = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            ctx.cgContext.drawPDFPage(page)
        }

        recognizeText(from: image, completion: completion)
    }

    func presentImagePicker(from viewController: UIViewController, delegate: UIImagePickerControllerDelegate & UINavigationControllerDelegate) {
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
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
            picker.delegate = viewController as? UIDocumentPickerDelegate
            if let vc = viewController as? UIDocumentPickerDelegate {
                picker.delegate = vc
            }
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

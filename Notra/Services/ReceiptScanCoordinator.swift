import UIKit
import UniformTypeIdentifiers

final class ReceiptScanCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate {

    private weak var presentingViewController: UIViewController?
    private var token: String = ""
    private var completion: ((GeminiReceiptResult?) -> Void)?
    private weak var loadingAlert: UIAlertController?
    private var didFinish = false
    private var tempFileURL: URL?

    // Duplicate / in-flight request guards
    private var activeScanID: UUID?
    private var isGeminiRequestInFlight = false

    private let scanService = ReceiptScanService.shared

    func start(from viewController: UIViewController, token: String, completion: @escaping (GeminiReceiptResult?) -> Void) {
        let scanID = UUID()
        print("[ReceiptScan] Scan ID: \(scanID.uuidString.prefix(8))...")
        self.activeScanID = scanID
        self.presentingViewController = viewController
        self.token = token
        self.completion = completion
        self.didFinish = false
        self.isGeminiRequestInFlight = false

        print("[ReceiptScan] Gemini key exists: \(GeminiKeychainService.shared.hasAPIKey())")

        if GeminiKeychainService.shared.hasAPIKey() {
            presentFilePicker(from: viewController)
        } else {
            presentKeySetup(from: viewController)
        }
    }

    private func finish(with result: GeminiReceiptResult?) {
        guard !didFinish else { return }
        didFinish = true
        cleanup()
        completion?(result)
    }

    private func cleanup() {
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
            tempFileURL = nil
        }
    }

    // MARK: - Gemini Key Setup

    private func presentKeySetup(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Gemini API Key Required",
            message: "AI receipt scanning uses Gemini to parse receipts. Your key is stored securely in Keychain and never shared.\n\nReceipt text or files may be sent to Gemini for parsing. Please review extracted items before saving.",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Paste your Gemini API key"
            tf.isSecureTextEntry = true
            tf.autocorrectionType = .no
            tf.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: "Save Key", style: .default) { [weak self, weak alert] _ in
            guard let self = self, let key = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces), !key.isEmpty else { return }
            do {
                try GeminiKeychainService.shared.saveAPIKey(key)
                self.presentFilePicker(from: viewController)
            } catch {
                self.showError(error.localizedDescription, on: viewController)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.finish(with: nil)
        })
        viewController.present(alert, animated: true)
    }

    // MARK: - File Picker

    private func presentFilePicker(from viewController: UIViewController) {
        let sheet = UIAlertController(title: "Import Receipt", message: nil, preferredStyle: .actionSheet)

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "Take Photo", style: .default) { [weak self] _ in
                let picker = UIImagePickerController()
                picker.sourceType = .camera
                picker.delegate = self
                viewController.present(picker, animated: true)
            })
        }
        sheet.addAction(UIAlertAction(title: "Choose Photo", style: .default) { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            viewController.present(picker, animated: true)
        })
        sheet.addAction(UIAlertAction(title: "Choose PDF", style: .default) { [weak self] _ in
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
            picker.delegate = self
            viewController.present(picker, animated: true)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.finish(with: nil)
        })
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
        }
        viewController.present(sheet, animated: true)
    }

    // MARK: - UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self = self, let vc = self.presentingViewController else { return }
            if let image = info[.originalImage] as? UIImage {
                self.processImage(image, in: vc)
            } else {
                self.finish(with: nil)
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [weak self] in self?.finish(with: nil) }
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        controller.dismiss(animated: true) { [weak self] in
            guard let self = self, let vc = self.presentingViewController, let url = urls.first else {
                self?.finish(with: nil)
                return
            }
            self.processPDF(url: url, in: vc)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true) { [weak self] in self?.finish(with: nil) }
    }

    // MARK: - Processing

    private func processImage(_ image: UIImage, in viewController: UIViewController) {
        guard let vc = presentingViewController else { return }
        showLoading(message: "Extracting text...", in: vc)
        print("[ReceiptImport] Detected type: image")

        // Save image to temp file for potential file-mode fallback
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        if let jpegData = image.jpegData(compressionQuality: 0.85) {
            try? jpegData.write(to: tempURL)
            tempFileURL = tempURL
            print("[ReceiptImport] Copied file to: \(tempURL.path)")
            print("[ReceiptImport] File size: \(jpegData.count)")
        }

        scanService.recognizeText(from: image) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let text):
                    print("[ReceiptExtraction] Extracted text length: \(text.count)")
                    self?.sendToGemini(extractedText: text, fileURL: self?.tempFileURL, mimeType: "image/jpeg", in: viewController)
                case .failure:
                    // OCR failed, try file mode directly
                    self?.sendToGemini(extractedText: "", fileURL: self?.tempFileURL, mimeType: "image/jpeg", in: viewController)
                }
            }
        }
    }

    private func processPDF(url: URL, in viewController: UIViewController) {
        guard let vc = presentingViewController else { return }
        showLoading(message: "Extracting text...", in: vc)
        print("[ReceiptImport] Picked file URL: \(url.path)")
        print("[ReceiptImport] Detected type: pdf")

        let didStartScoped = url.startAccessingSecurityScopedResource()
        defer { if didStartScoped { url.stopAccessingSecurityScopedResource() } }

        // Copy to temp storage
        let destURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: url, to: destURL)
            tempFileURL = destURL
            let size = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int) ?? 0
            print("[ReceiptImport] Copied file to: \(destURL.path)")
            print("[ReceiptImport] File exists after copy: \(FileManager.default.fileExists(atPath: destURL.path))")
            print("[ReceiptImport] File size: \(size)")
        } catch {
            print("[ReceiptImport] Copy failed: \(error.localizedDescription)")
            hideLoading { [weak self] in
                self?.showError("Could not read the selected file.", on: viewController)
            }
            return
        }

        scanService.recognizeText(from: destURL) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let text):
                    print("[ReceiptExtraction] Extracted text length: \(text.count)")
                    self?.sendToGemini(extractedText: text, fileURL: destURL, mimeType: "application/pdf", in: viewController)
                case .failure:
                    self?.sendToGemini(extractedText: "", fileURL: destURL, mimeType: "application/pdf", in: viewController)
                }
            }
        }
    }

    // MARK: - Gemini

    private func sendToGemini(extractedText: String, fileURL: URL?, mimeType: String, in viewController: UIViewController) {
        // Guard: only one Gemini request per scan session
        guard !isGeminiRequestInFlight else {
            print("[ReceiptScan] Ignoring duplicate Gemini request (already in flight)")
            return
        }
        isGeminiRequestInFlight = true

        guard let apiKey = GeminiKeychainService.shared.loadAPIKey() else {
            hideLoading { [weak self] in
                self?.showError("Gemini API key not found. Please set up your key in Settings.", on: viewController)
            }
            return
        }

        let isGoodQuality = ExtractionQualityEvaluator.isGoodQuality(extractedText)
        let mode: GeminiReceiptParser.ParseMode
        if isGoodQuality {
            mode = .text(extractedText)
        } else if let url = fileURL {
            mode = .file(url, mimeType)
        } else {
            mode = .text(extractedText)
        }

        updateLoadingMessage("Parsing with AI...")

        GeminiReceiptParser.shared.parse(mode: mode, apiKey: apiKey) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isGeminiRequestInFlight = false
                self.hideLoading {
                    switch result {
                    case .success(let geminiResult):
                        print("[ReceiptReview] Presenting review with \(geminiResult.items.count) items")
                        self.finish(with: geminiResult)
                    case .failure(let error):
                        self.presentGeminiError(error, on: viewController)
                    }
                }
            }
        }
    }

    // MARK: - Error Handling

    private func presentGeminiError(_ error: GeminiParserError, on viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Scan Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in
            guard let self = self, let completion = self.completion else { return }
            self.didFinish = false
            self.start(from: viewController, token: self.token, completion: completion)
        })
        alert.addAction(UIAlertAction(title: "Enter Manually", style: .default) { [weak self] _ in
            let empty = GeminiReceiptResult(
                merchant: nil,
                platform: nil,
                date: Date(),
                orderNumber: nil,
                currency: "USD",
                items: [],
                summary: GeminiReceiptSummary(),
                adjustments: [],
                warnings: ["Enter items manually."],
                rawText: ""
            )
            self?.finish(with: empty)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.finish(with: nil)
        })
        viewController.present(alert, animated: true)
    }

    private func showError(_ message: String, on viewController: UIViewController) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in self?.finish(with: nil) })
        viewController.present(alert, animated: true)
    }

    // MARK: - Loading

    private func showLoading(message: String, in viewController: UIViewController) {
        let alert = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.startAnimating()
        alert.view.addSubview(indicator)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            indicator.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 60),
            indicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
        ])
        loadingAlert = alert
        viewController.present(alert, animated: true)
    }

    private func updateLoadingMessage(_ message: String) {
        loadingAlert?.title = message
    }

    private func hideLoading(completion: @escaping () -> Void) {
        guard let alert = loadingAlert else {
            DispatchQueue.main.async(execute: completion)
            return
        }
        loadingAlert = nil
        alert.dismiss(animated: true) { completion() }
    }
}

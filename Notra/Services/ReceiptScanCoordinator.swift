import UIKit

final class ReceiptScanCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate {

    private weak var presentingViewController: UIViewController?
    private var token: String = ""
    private var completion: ((ReceiptParseResult?) -> Void)?

    private let scanService = ReceiptScanService.shared
    private let parserService = ReceiptParserService.shared

    func start(from viewController: UIViewController, token: String, completion: @escaping (ReceiptParseResult?) -> Void) {
        self.presentingViewController = viewController
        self.token = token
        self.completion = completion

        scanService.presentImagePicker(from: viewController, delegate: self)
    }

    // MARK: - UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            if let image = info[.originalImage] as? UIImage {
                self.processImage(image)
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [weak self] in
            self?.completion?(nil)
        }
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            completion?(nil)
            return
        }
        processPDF(url: url)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion?(nil)
    }

    // MARK: - Processing

    private func processImage(_ image: UIImage) {
        guard let vc = presentingViewController else { return }
        showLoading(in: vc)

        scanService.recognizeText(from: image) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleOCRResult(result, viewController: vc)
            }
        }
    }

    private func processPDF(url: URL) {
        guard let vc = presentingViewController else { return }
        showLoading(in: vc)

        scanService.recognizeText(from: url) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleOCRResult(result, viewController: vc)
            }
        }
    }

    private func handleOCRResult(_ result: Result<String, ReceiptScanError>, viewController: UIViewController) {
        hideLoading(from: viewController)

        switch result {
        case .success(let text):
            let parseResult = parserService.parse(text: text)
            completion?(parseResult)

        case .failure(let error):
            completion?(nil)
            let alert = UIAlertController(
                title: "Scan Failed",
                message: "\(error.localizedDescription)\n\nYou can add items manually.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in
                self?.start(from: viewController, token: self?.token ?? "", completion: self?.completion ?? { _ in })
            })
            alert.addAction(UIAlertAction(title: "Enter Manually", style: .default) { [weak self] _ in
                let emptyResult = ReceiptParseResult(
                    merchantName: nil,
                    date: Date(),
                    items: [],
                    subtotal: nil,
                    tax: nil,
                    total: nil,
                    warnings: ["Enter items manually."],
                    rawText: ""
                )
                self?.completion?(emptyResult)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
                self?.completion?(nil)
            })
            viewController.present(alert, animated: true)
        }
    }

    private func showLoading(in viewController: UIViewController) {
        let alert = UIAlertController(title: "Scanning Receipt...", message: nil, preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.startAnimating()
        alert.view.addSubview(indicator)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            indicator.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 60),
            indicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
        ])
        viewController.present(alert, animated: true)
    }

    private func hideLoading(from viewController: UIViewController) {
        if let alert = viewController.presentedViewController as? UIAlertController,
           alert.title == "Scanning Receipt..." {
            alert.dismiss(animated: true)
        }
    }
}

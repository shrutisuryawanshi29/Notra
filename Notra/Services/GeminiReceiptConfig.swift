import Foundation

struct GeminiReceiptConfig {
    /// Default model used when none has been selected in Settings.
    static let defaultModelName = "gemini-3.5-flash"

    /// User-selected model name, persisted in UserDefaults.
    static var modelName: String {
        get {
            UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.geminiModelName)
                ?? defaultModelName
        }
        set {
            UserDefaults.standard.set(newValue, forKey: AppConstants.UserDefaultsKeys.geminiModelName)
        }
    }

    static let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    static var generateContentURL: String {
        "\(baseURL)/\(modelName):generateContent"
    }

    /// Supported models for the Settings picker.
    static let availableModels: [(displayName: String, modelID: String)] = [
        ("Gemini 2.0 Flash", "gemini-2.0-flash"),
        ("Gemini 3.5 Flash", "gemini-3.5-flash")
    ]

    // Extraction quality thresholds
    static let qualityMinLength = 300
    static let qualityMinMoneyValues = 3
    static let qualityKeywords = ["total", "subtotal", "tax", "item", "order", "qty",
                                   "delivered", "price", "quantity", "receipt", "amount"]
    static let qualityMinKeywords = 2
}

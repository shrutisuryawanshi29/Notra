import Foundation

// MARK: - Errors

enum GeminiParserError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case networkError(String)
    case invalidResponse
    case malformedRequest
    case modelUnavailable
    case serverError
    case noItemsFound
    case jsonDecodeFailed(String)
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is missing. Please set up your key in Settings."
        case .invalidAPIKey:
            return "Gemini key failed. Please update your key in Settings."
        case .rateLimited:
            return "Gemini quota reached for this API key/model. Try again later or choose another model."
        case .networkError(let msg):
            return "Could not connect to Gemini. Check your internet connection. (\(msg))"
        case .malformedRequest:
            return "Gemini request failed. The selected model may not support this request format."
        case .modelUnavailable:
            return "Gemini model is unavailable. Please choose another model in Settings."
        case .serverError:
            return "Gemini is temporarily unavailable. Try again."
        case .invalidResponse:
            return "Gemini returned an unreadable result. Please try again."
        case .noItemsFound:
            return "No receipt items were detected. Try another file or enter manually."
        case .jsonDecodeFailed:
            return "Gemini returned an unreadable result. Please try again."
        case .fileTooLarge:
            return "File is too large to send to Gemini. Try a smaller image or PDF."
        }
    }
}

// MARK: - Parser

final class GeminiReceiptParser {

    static let shared = GeminiReceiptParser()
    private init() {}

    enum ParseMode {
        case text(String)
        case file(URL, String)   // (fileURL, mimeType e.g. "application/pdf")
    }

    // MARK: - Parse Receipt

    func parse(mode: ParseMode, apiKey: String, completion: @escaping (Result<GeminiReceiptResult, GeminiParserError>) -> Void) {
        print("[GeminiReceiptParser] Model: \(GeminiReceiptConfig.modelName)")
        print("[GeminiReceiptParser] Mode: \(modeDescription(mode))")
        if case .text(let text) = mode {
            print("[GeminiReceiptParser] Request text chars: \(text.count)")
        } else if case .file(_, let mime) = mode {
            print("[GeminiReceiptParser] Request file type: \(mime)")
        }
        print("[GeminiReceiptParser] Request started")

        let urlString = "\(GeminiReceiptConfig.generateContentURL)?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidResponse))
            return
        }

        var rawText = ""
        let requestBody: [String: Any]

        switch mode {
        case .text(let text):
            rawText = text
            requestBody = buildTextRequest(text: text)

        case .file(let fileURL, let mimeType):
            do {
                let fileData = try Data(contentsOf: fileURL)
                guard fileData.count < 20 * 1024 * 1024 else {
                    completion(.failure(.fileTooLarge))
                    return
                }
                let base64 = fileData.base64EncodedString()
                requestBody = buildFileRequest(base64Data: base64, mimeType: mimeType)
            } catch {
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(.invalidResponse))
            return
        }
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                print("[GeminiReceiptParser] Network error: \(error.localizedDescription)")
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                print("[GeminiReceiptParser] Response is not HTTP (unexpected)")
                completion(.failure(.invalidResponse))
                return
            }

            // Log HTTP status
            print("[GeminiReceiptParser] HTTP status: \(http.statusCode)")

            guard (200...299).contains(http.statusCode) else {
                // Log sanitized error body for diagnostics
                if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let err = body["error"] as? [String: Any] {
                    let errStatus = err["status"] as? String ?? "nil"
                    let errCode = err["code"] as? Int ?? 0
                    let errMsg = (err["message"] as? String ?? "nil").prefix(120)
                    print("[GeminiReceiptParser] Error status: \(errStatus)")
                    print("[GeminiReceiptParser] Error code: \(errCode)")
                    print("[GeminiReceiptParser] Error message: \(errMsg)")
                }

                switch http.statusCode {
                case 400:
                    // Bad request — malformed payload or schema issue
                    completion(.failure(.malformedRequest))
                case 401, 403:
                    completion(.failure(.invalidAPIKey))
                case 404:
                    completion(.failure(.modelUnavailable))
                case 429:
                    completion(.failure(.rateLimited))
                case 500...599:
                    completion(.failure(.serverError))
                default:
                    // Try to extract meaningful API error status
                    if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let err = body["error"] as? [String: Any],
                       let status = err["status"] as? String {
                        if status == "UNAUTHENTICATED" || status == "PERMISSION_DENIED" {
                            completion(.failure(.invalidAPIKey))
                        } else if status == "RESOURCE_EXHAUSTED" {
                            completion(.failure(.rateLimited))
                        } else {
                            print("[GeminiReceiptParser] Unhandled Gemini error status: \(status)")
                            completion(.failure(.invalidResponse))
                        }
                    } else {
                        print("[GeminiReceiptParser] HTTP error: \(http.statusCode)")
                        completion(.failure(.invalidResponse))
                    }
                }
                return
            }

            print("[GeminiReceiptParser] Response received")
            self.handleResponse(data: data, rawText: rawText, completion: completion)
        }.resume()
    }

    // MARK: - Test Key

    func testAPIKey(_ key: String, completion: @escaping (Result<Void, GeminiParserError>) -> Void) {
        let urlString = "\(GeminiReceiptConfig.generateContentURL)?key=\(key)"
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidResponse))
            return
        }
        let body: [String: Any] = [
            "contents": [["parts": [["text": "Reply with one word: OK"]]]],
            "generationConfig": ["maxOutputTokens": 5]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            // Log sanitized error body for diagnostics
            if !(200...299).contains(http.statusCode), let data = data,
               let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = body["error"] as? [String: Any] {
                let errStatus = err["status"] as? String ?? "nil"
                let errCode = err["code"] as? Int ?? 0
                print("[GeminiReceiptParser] Test key HTTP: \(http.statusCode), status: \(errStatus), code: \(errCode)")
            } else {
                print("[GeminiReceiptParser] Test key HTTP: \(http.statusCode)")
            }
            switch http.statusCode {
            case 200...299: completion(.success(()))
            case 401, 403: completion(.failure(.invalidAPIKey))
            case 404: completion(.failure(.modelUnavailable))
            case 429: completion(.failure(.rateLimited))
            case 500...599: completion(.failure(.serverError))
            default: completion(.failure(.invalidResponse))
            }
        }.resume()
    }

    // MARK: - Response Handling

    private func handleResponse(data: Data, rawText: String, completion: @escaping (Result<GeminiReceiptResult, GeminiParserError>) -> Void) {
        guard let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = responseJSON["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let jsonText = firstPart["text"] as? String else {
            print("[GeminiReceiptParser] Failed to extract text from Gemini response")
            completion(.failure(.invalidResponse))
            return
        }

#if DEBUG
        if let jsonData = try? JSONSerialization.data(withJSONObject: responseJSON, options: [.prettyPrinted, .withoutEscapingSlashes]),
           let pretty = String(data: jsonData, encoding: .utf8) {
            print("[GeminiReceiptParser] Raw JSON response:\n\(pretty)")
        }
#endif

        var cleaned = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip any markdown code fences Gemini might add despite our instructions
        if cleaned.hasPrefix("```json") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let jsonData = cleaned.data(using: .utf8) else {
            print("[GeminiReceiptParser] Could not convert response text to data")
            completion(.failure(.jsonDecodeFailed("encoding failed")))
            return
        }

        do {
            let decoded = try JSONDecoder().decode(GeminiReceiptResponse.self, from: jsonData)
            print("[GeminiReceiptParser] JSON decode success")

            print("[GeminiReceiptParser] Parsed items:")
            for item in decoded.items {
                print("[GeminiReceiptParser] - \(item.name), finalPrice=\(item.finalPrice), quantity=\(item.quantity.map { "\($0)" } ?? "nil"), rawText=\(item.rawText ?? "nil")")
            }
            print("[GeminiReceiptParser] Parsed adjustments:")
            for adj in decoded.adjustments ?? [] {
                print("[GeminiReceiptParser] - \(adj.name), type=\(adj.type ?? "nil"), amount=\(adj.amount.map { "\($0)" } ?? "nil"), description=\(adj.description ?? "nil")")
            }
            if let s = decoded.summary {
                print("[GeminiReceiptParser] Summary: itemsSubtotal=\(s.itemsSubtotal.map { "\($0)" } ?? "nil"), tax=\(s.tax.map { "\($0)" } ?? "nil"), serviceFee=\(s.serviceFee.map { "\($0)" } ?? "nil"), deliveryFee=\(s.deliveryFee.map { "\($0)" } ?? "nil"), tip=\(s.tip.map { "\($0)" } ?? "nil"), discount=\(s.discount.map { "\($0)" } ?? "nil"), total=\(s.total.map { "\($0)" } ?? "nil"), totalCharged=\(s.totalCharged.map { "\($0)" } ?? "nil")")
            }

            let result = GeminiReceiptValidator.validate(decoded, rawText: rawText)
            completion(.success(result))
        } catch {
            print("[GeminiReceiptParser] JSON decode failure: \(error)")
            completion(.failure(.jsonDecodeFailed(error.localizedDescription)))
        }
    }

    // MARK: - Request Builders

    private func buildTextRequest(text: String) -> [String: Any] {
        let prompt = """
You are a receipt and grocery order parser.
Parse the receipt text below and return JSON ONLY.
No markdown. No code blocks. No explanation.

Return a JSON object with this exact structure:
{
  "merchant": "string or null",
  "platform": "string or null",
  "date": "YYYY-MM-DD or null",
  "orderNumber": "string or null",
  "currency": "USD",
  "items": [{"name": "string", "quantity": null_or_number, "unitPrice": null_or_number, "finalPrice": number, "categoryHint": "string or null", "rawText": "string or null"}],
  "summary": {"itemsSubtotal": null_or_number, "tax": null_or_number, "serviceFee": null_or_number, "deliveryFee": null_or_number, "tip": null_or_number, "discount": null_or_number, "total": null_or_number, "totalCharged": null_or_number},
  "adjustments": [{"name": "string", "type": "refund|weightAdjustment|substitution|discount|fee|unknown", "amount": null_or_number, "description": "string or null"}],
  "warnings": ["string"]
}

RULES:
- items must contain ONLY real purchased products
- do NOT include subtotal, tax, total, payment, delivery fee, tip, service fee, authorization, or order number as items
- put ALL fees, taxes, tips, delivery, and discounts in summary
- put refunds, NOT CHARGED, and zero-amount adjustments in adjustments
- CHARGED weight adjustments are real purchase items — include them in items with their final charged price
- for Instacart, parse by sections:
  • ITEMS FOUND section → items
  • ADJUSTMENTS / WEIGHT ADJUSTMENTS section → include CHARGED adjusted items (positive amount) in items, NOT in adjustments
  • NOT CHARGED / refunded items → adjustments only, do NOT include as items
  • ORDER TOTALS / CHARGES section → summary only
- for Walmart: product lines with Qty and price -> items; Free delivery/Tax/Tip/Subtotal/Total -> summary
- use final charged prices, not original unit prices or delta amounts
- the sum of items[].finalPrice should match summary.itemsSubtotal when possible
- for Instacart loyalty savings, use the final price shown after savings
- when uncertain, add a warning instead of inventing data

Receipt text:
\(text)
"""
        return [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json"]
        ]
    }

    private func buildFileRequest(base64Data: String, mimeType: String) -> [String: Any] {
        let prompt = """
You are a receipt and grocery order parser.
Parse the receipt document attached and return JSON ONLY.
No markdown. No code blocks. No explanation.

Return a JSON object with this exact structure:
{
  "merchant": "string or null",
  "platform": "string or null",
  "date": "YYYY-MM-DD or null",
  "orderNumber": "string or null",
  "currency": "USD",
  "items": [{"name": "string", "quantity": null_or_number, "unitPrice": null_or_number, "finalPrice": number, "categoryHint": "string or null", "rawText": "string or null"}],
  "summary": {"itemsSubtotal": null_or_number, "tax": null_or_number, "serviceFee": null_or_number, "deliveryFee": null_or_number, "tip": null_or_number, "discount": null_or_number, "total": null_or_number, "totalCharged": null_or_number},
  "adjustments": [{"name": "string", "type": "refund|weightAdjustment|substitution|discount|fee|unknown", "amount": null_or_number, "description": "string or null"}],
  "warnings": ["string"]
}

RULES:
- items must contain ONLY real purchased products
- do NOT include subtotal, tax, total, payment, delivery fee, tip, service fee, authorization as items
- put ALL fees, taxes, tips, delivery, and discounts in summary
- put refunds, NOT CHARGED, and zero-amount adjustments in adjustments
- CHARGED weight adjustments are real purchase items — include them in items with their final charged price
- for Instacart, parse by sections:
  • ITEMS FOUND section → items
  • ADJUSTMENTS / WEIGHT ADJUSTMENTS section → include CHARGED adjusted items (positive amount) in items, NOT in adjustments
  • NOT CHARGED / refunded items → adjustments only, do NOT include as items
  • ORDER TOTALS / CHARGES section → summary only
- for Walmart: product lines with Qty and price -> items; Free delivery/Tax/Tip/Subtotal/Total -> summary
- use final charged prices, not original unit prices or delta amounts
- the sum of items[].finalPrice should match summary.itemsSubtotal when possible
- for Instacart loyalty savings, use the final price shown after savings
- when uncertain, add a warning instead of inventing data
"""
        return [
            "contents": [[
                "parts": [
                    ["inlineData": ["mimeType": mimeType, "data": base64Data]],
                    ["text": prompt]
                ]
            ]],
            "generationConfig": ["responseMimeType": "application/json"]
        ]
    }

    private func modeDescription(_ mode: ParseMode) -> String {
        switch mode {
        case .text: return "text"
        case .file(_, let mime): return "file(\(mime))"
        }
    }
}

// MARK: - Extraction Quality Evaluator

struct ExtractionQualityEvaluator {
    static func isGoodQuality(_ text: String) -> Bool {
        let len = text.count
        guard len >= GeminiReceiptConfig.qualityMinLength else {
            print("[ReceiptExtraction] Quality: poor (length \(len))")
            return false
        }
        let moneyRegex = try? NSRegularExpression(pattern: "\\$\\s*\\d+\\.\\d{2}")
        let range = NSRange(location: 0, length: text.utf16.count)
        let moneyCount = moneyRegex?.numberOfMatches(in: text, options: [], range: range) ?? 0
        guard moneyCount >= GeminiReceiptConfig.qualityMinMoneyValues else {
            print("[ReceiptExtraction] Quality: poor (money values \(moneyCount))")
            return false
        }
        let lower = text.lowercased()
        let kwCount = GeminiReceiptConfig.qualityKeywords.filter { lower.contains($0) }.count
        guard kwCount >= GeminiReceiptConfig.qualityMinKeywords else {
            print("[ReceiptExtraction] Quality: poor (keywords \(kwCount))")
            return false
        }
        print("[ReceiptExtraction] Quality: good (len:\(len) money:\(moneyCount) kw:\(kwCount))")
        return true
    }
}

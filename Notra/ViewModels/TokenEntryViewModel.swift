//
//  TokenEntryViewModel.swift
//  Notra
//

import Foundation

protocol TokenEntryViewModelDelegate: AnyObject {
    func tokenEntryDidSave()
    func tokenEntryDidFailValidation(_ message: String)
}

final class TokenEntryViewModel {
    weak var delegate: TokenEntryViewModelDelegate?

    func validateAndSave(token: String) {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedToken.isEmpty else {
            delegate?.tokenEntryDidFailValidation("Please enter your Notion Integration token.")
            return
        }

        guard trimmedToken.hasPrefix("secret_") else {
            delegate?.tokenEntryDidFailValidation("Invalid token format. Token should start with 'secret_'.")
            return
        }

        UserDefaultsManager.shared.notionToken = trimmedToken
        delegate?.tokenEntryDidSave()
    }
}
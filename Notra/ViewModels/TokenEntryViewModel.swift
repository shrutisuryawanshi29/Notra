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

        UserDefaultsManager.shared.notionToken = trimmedToken

        if AppConstants.Debug.enabled {
            print("[TokenEntryViewModel] Token saved successfully")
        }

        delegate?.tokenEntryDidSave()
    }
}

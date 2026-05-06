//
//  PagePickerViewModel.swift
//  Notra
//

import Foundation

protocol PagePickerViewModelDelegate: AnyObject {
    func pagePickerDidStartLoading()
    func pagePickerDidFinishLoading(pages: [NotionPage])
    func pagePickerDidFail(_ error: String)
}

final class PagePickerViewModel {
    weak var delegate: PagePickerViewModelDelegate?

    private(set) var pages: [NotionPage] = []

    func fetchPages() {
        guard let token = UserDefaultsManager.shared.notionToken else {
            delegate?.pagePickerDidFail("No token found. Please enter your Notion token first.")
            return
        }

        delegate?.pagePickerDidStartLoading()

        NotionService.shared.fetchTopLevelPages(token: token) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let fetchedPages):
                self.pages = fetchedPages
                self.delegate?.pagePickerDidFinishLoading(pages: fetchedPages)
            case .failure(let error):
                self.delegate?.pagePickerDidFail(error.localizedDescription)
            }
        }
    }

    func selectPage(at index: Int) {
        guard index >= 0 && index < pages.count else { return }

        let page = pages[index]
        UserDefaultsManager.shared.selectedPageId = page.id
        UserDefaultsManager.shared.selectedPageTitle = page.title

        if AppConstants.Debug.enabled {
            print("[PagePickerViewModel] Selected page ID: \(page.id)")
            print("[PagePickerViewModel] Selected page title: \(page.title)")
        }
    }
}
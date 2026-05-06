//
//  UserDefaultsManager.swift
//  Notra
//

import Foundation

final class UserDefaultsManager {
    static let shared = UserDefaultsManager()

    private let defaults = UserDefaults.standard

    private init() {}

    var notionToken: String? {
        get { defaults.string(forKey: AppConstants.UserDefaultsKeys.notionToken) }
        set { defaults.set(newValue, forKey: AppConstants.UserDefaultsKeys.notionToken) }
    }

    var selectedPageId: String? {
        get { defaults.string(forKey: AppConstants.UserDefaultsKeys.selectedPageId) }
        set { defaults.set(newValue, forKey: AppConstants.UserDefaultsKeys.selectedPageId) }
    }

    var selectedPageTitle: String? {
        get { defaults.string(forKey: AppConstants.UserDefaultsKeys.selectedPageTitle) }
        set { defaults.set(newValue, forKey: AppConstants.UserDefaultsKeys.selectedPageTitle) }
    }

    func clearAll() {
        defaults.removeObject(forKey: AppConstants.UserDefaultsKeys.notionToken)
        defaults.removeObject(forKey: AppConstants.UserDefaultsKeys.selectedPageId)
        defaults.removeObject(forKey: AppConstants.UserDefaultsKeys.selectedPageTitle)
    }

    var hasSetupComplete: Bool {
        notionToken != nil && selectedPageId != nil
    }
}
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
        get {
            return defaults.string(forKey: AppConstants.UserDefaultsKeys.notionToken)
        }
        set {
            defaults.set(newValue, forKey: AppConstants.UserDefaultsKeys.notionToken)
            if AppConstants.Debug.enabled {
                print("[UserDefaultsManager] Token saved: \(newValue != nil)")
            }
        }
    }

    var selectedPageId: String? {
        get {
            return defaults.string(forKey: AppConstants.UserDefaultsKeys.selectedPageId)
        }
        set {
            defaults.set(newValue, forKey: AppConstants.UserDefaultsKeys.selectedPageId)
            if AppConstants.Debug.enabled {
                print("[UserDefaultsManager] Page ID saved: \(newValue ?? "nil")")
            }
        }
    }

    var selectedPageTitle: String? {
        get {
            return defaults.string(forKey: AppConstants.UserDefaultsKeys.selectedPageTitle)
        }
        set {
            defaults.set(newValue, forKey: AppConstants.UserDefaultsKeys.selectedPageTitle)
            if AppConstants.Debug.enabled {
                print("[UserDefaultsManager] Page title saved: \(newValue ?? "nil")")
            }
        }
    }

    func clearAll() {
        defaults.removeObject(forKey: AppConstants.UserDefaultsKeys.notionToken)
        defaults.removeObject(forKey: AppConstants.UserDefaultsKeys.selectedPageId)
        defaults.removeObject(forKey: AppConstants.UserDefaultsKeys.selectedPageTitle)
        if AppConstants.Debug.enabled {
            print("[UserDefaultsManager] All data cleared")
        }
    }

    func hasSetupComplete() -> Bool {
        return notionToken != nil && selectedPageId != nil
    }
}
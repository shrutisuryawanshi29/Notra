//
//  AppConstants.swift
//  Notra
//

import Foundation

struct AppConstants {
    struct API {
        static let notionBaseURL = "https://api.notion.com/v1"
        static let searchEndpoint = "/search"
        static let notionVersion = "2022-06-28"
    }

    struct UserDefaultsKeys {
        static let notionToken = "notionToken"
        static let selectedPageId = "selectedPageId"
        static let selectedPageTitle = "selectedPageTitle"
    }

    struct Storyboard {
        static let mainStoryboard = "Main"
    }

    struct Debug {
        static let enabled = true
    }
}
//
//  AppConstants.swift
//  Notra
//

import UIKit

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
        static let databaseMappings = "databaseMappings"
        static let columnMappings = "columnMappings"
        static let categoryValues = "categoryValues"
    }
}

struct AppTheme {
    struct Colors {
        static let background = UIColor(red: 250/255, green: 249/255, blue: 247/255, alpha: 1)
        static let cardBackground = UIColor.white
        static let expense = UIColor(red: 248/255, green: 117/255, blue: 117/255, alpha: 1)
        static let income = UIColor(red: 93/255, green: 217/255, blue: 168/255, alpha: 1)
        static let accent = UIColor(red: 167/255, green: 139/255, blue: 250/255, alpha: 1)
        static let accentSecondary = UIColor(red: 94/255, green: 234/255, blue: 212/255, alpha: 1)
        static let textPrimary = UIColor(red: 31/255, green: 41/255, blue: 55/255, alpha: 1)
        static let textSecondary = UIColor(red: 107/255, green: 114/255, blue: 128/255, alpha: 1)
        static let textTertiary = UIColor(red: 156/255, green: 163/255, blue: 175/255, alpha: 1)
    }

    struct Fonts {
        static let headingLarge = UIFont.systemFont(ofSize: 28, weight: .bold)
        static let headingMedium = UIFont.systemFont(ofSize: 20, weight: .semibold)
        static let body = UIFont.systemFont(ofSize: 16, weight: .regular)
        static let bodyBold = UIFont.systemFont(ofSize: 16, weight: .semibold)
        static let caption = UIFont.systemFont(ofSize: 13, weight: .regular)
        static let captionBold = UIFont.systemFont(ofSize: 14, weight: .semibold)
    }

    struct Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
        static let section: CGFloat = 24
        static let cardPadding: CGFloat = 16
    }

    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 14
        static let extraLarge: CGFloat = 16
        static let button: CGFloat = 14
        static let card: CGFloat = 16
    }

    static func applyCardStyle(to view: UIView) {
        view.backgroundColor = Colors.cardBackground
        view.layer.cornerRadius = CornerRadius.card
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.04
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
    }

    static func applySoftButtonStyle(to button: UIButton, backgroundColor: UIColor, textColor: UIColor) {
        button.backgroundColor = backgroundColor
        button.setTitleColor(textColor, for: .normal)
        button.titleLabel?.font = Fonts.bodyBold
        button.layer.cornerRadius = CornerRadius.button
    }
}
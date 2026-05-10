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
    // MARK: - Background Colors
    struct Colors {
        // App Backgrounds
        static let background = UIColor(red: 246/255, green: 239/255, blue: 227/255, alpha: 1) // Warm cream #F6EFE3
        static let backgroundLight = UIColor(red: 239/255, green: 227/255, blue: 210/255, alpha: 1) // Light beige #EFE3D2
        static let backgroundIvory = UIColor(red: 250/255, green: 247/255, blue: 240/255, alpha: 1) // Soft ivory #FAF7F0

        // Primary Brown
        static let primaryBrown = UIColor(red: 107/255, green: 70/255, blue: 56/255, alpha: 1) // Deep mocha #6B4638
        static let primaryBrownLight = UIColor(red: 122/255, green: 80/255, blue: 66/255, alpha: 1) // Cocoa #7A5042

        // Secondary Brown
        static let secondaryBrown = UIColor(red: 217/255, green: 168/255, blue: 117/255, alpha: 1) // Muted caramel #D9A875
        static let secondaryTan = UIColor(red: 232/255, green: 201/255, blue: 166/255, alpha: 1) // Soft tan #E8C9A6

        // Card Backgrounds
        static let cardBackground = UIColor(red: 255/255, green: 249/255, blue: 241/255, alpha: 1) // Warm off-white #FFF9F1
        static let cardBackgroundAlt = UIColor(red: 244/255, green: 232/255, blue: 216/255, alpha: 1) // Pale beige #F4E8D8

        // Text Colors
        static let textPrimary = UIColor(red: 74/255, green: 51/255, blue: 44/255, alpha: 1) // #4A332C
        static let textSecondary = UIColor(red: 138/255, green: 106/255, blue: 91/255, alpha: 1) // #8A6A5B
        static let textMuted = UIColor(red: 180/255, green: 154/255, blue: 138/255, alpha: 1) // #B49A8A

        // Expense Accent (Soft coral/clay)
        static let expense = UIColor(red: 217/255, green: 139/255, blue: 125/255, alpha: 1) // #D98B7D
        static let expenseLight = UIColor(red: 231/255, green: 163/255, blue: 154/255, alpha: 1) // #E7A39A

        // Income Accent (Soft sage green)
        static let income = UIColor(red: 167/255, green: 200/255, blue: 162/255, alpha: 1) // #A7C8A2
        static let incomeLight = UIColor(red: 200/255, green: 221/255, blue: 190/255, alpha: 1) // #C8DDBE

        // Border/Divider
        static let border = UIColor(red: 227/255, green: 210/255, blue: 193/255, alpha: 1) // Soft beige #E3D2C1

        // Accent
        static let accent = secondaryBrown
        static let accentSecondary = secondaryTan
    }

    // MARK: - Typography
    struct Fonts {
        // Large Titles
        static let headingLarge = UIFont.systemFont(ofSize: 28, weight: .bold)
        static let headingLargeRounded = UIFont.systemFont(ofSize: 28, weight: .bold)

        // Medium Titles
        static let headingMedium = UIFont.systemFont(ofSize: 22, weight: .semibold)
        static let headingMediumRounded = UIFont.systemFont(ofSize: 22, weight: .semibold)

        // Section Headers
        static let sectionHeader = UIFont.systemFont(ofSize: 18, weight: .semibold)

        // Body Text
        static let body = UIFont.systemFont(ofSize: 16, weight: .regular)
        static let bodyMedium = UIFont.systemFont(ofSize: 16, weight: .medium)
        static let bodyBold = UIFont.systemFont(ofSize: 16, weight: .semibold)

        // Captions
        static let caption = UIFont.systemFont(ofSize: 14, weight: .regular)
        static let captionMedium = UIFont.systemFont(ofSize: 14, weight: .medium)
        static let captionBold = UIFont.systemFont(ofSize: 14, weight: .semibold)

        // Small Text
        static let small = UIFont.systemFont(ofSize: 12, weight: .regular)
        static let smallMedium = UIFont.systemFont(ofSize: 12, weight: .medium)

        // Buttons
        static let buttonLarge = UIFont.systemFont(ofSize: 17, weight: .semibold)
        static let buttonMedium = UIFont.systemFont(ofSize: 15, weight: .semibold)
        static let buttonSmall = UIFont.systemFont(ofSize: 13, weight: .medium)
    }

    // MARK: - Spacing
    struct Spacing {
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
        static let section: CGFloat = 24
        static let largeSection: CGFloat = 32
        static let cardPadding: CGFloat = 16
        static let screenPadding: CGFloat = 20
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
        static let button: CGFloat = 12
        static let card: CGFloat = 16
        static let pill: CGFloat = 20
    }

    // MARK: - Shadows
    struct Shadow {
        static func apply(to view: UIView, opacity: Float = 0.06, radius: CGFloat = 8, offset: CGSize = CGSize(width: 0, height: 2)) {
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOpacity = opacity
            view.layer.shadowOffset = offset
            view.layer.shadowRadius = radius
            view.layer.masksToBounds = false
        }

        static func applySoft(to view: UIView) {
            apply(to: view, opacity: 0.05, radius: 10, offset: CGSize(width: 0, height: 3))
        }

        static func applyCard(to view: UIView) {
            apply(to: view, opacity: 0.08, radius: 12, offset: CGSize(width: 0, height: 4))
        }
    }

    // MARK: - Card Style
    static func applyCardStyle(to view: UIView) {
        view.backgroundColor = Colors.cardBackground
        view.layer.cornerRadius = CornerRadius.card
        Shadow.applyCard(to: view)
    }

    static func applyCardStyleAlt(to view: UIView) {
        view.backgroundColor = Colors.cardBackgroundAlt
        view.layer.cornerRadius = CornerRadius.card
        Shadow.apply(to: view)
    }

    // MARK: - Button Styles
    static func applyPrimaryButtonStyle(to button: UIButton) {
        button.backgroundColor = Colors.primaryBrown
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = Fonts.buttonLarge
        button.layer.cornerRadius = CornerRadius.button
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 24)
    }

    static func applySecondaryButtonStyle(to button: UIButton) {
        button.backgroundColor = Colors.secondaryTan
        button.setTitleColor(Colors.primaryBrown, for: .normal)
        button.titleLabel?.font = Fonts.buttonMedium
        button.layer.cornerRadius = CornerRadius.button
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
    }

    static func applyExpenseButtonStyle(to button: UIButton) {
        button.backgroundColor = Colors.expense
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = Fonts.buttonLarge
        button.layer.cornerRadius = CornerRadius.button
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 24)
    }

    static func applyIncomeButtonStyle(to button: UIButton) {
        button.backgroundColor = Colors.income
        button.setTitleColor(Colors.textPrimary, for: .normal)
        button.titleLabel?.font = Fonts.buttonLarge
        button.layer.cornerRadius = CornerRadius.button
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 24)
    }

    // MARK: - Input Field Style
    static func applyInputFieldStyle(to textField: UITextField) {
        textField.backgroundColor = Colors.cardBackgroundAlt
        textField.textColor = Colors.textPrimary
        textField.font = Fonts.body
        textField.layer.cornerRadius = CornerRadius.medium
        textField.layer.borderWidth = 1
        textField.layer.borderColor = Colors.border.cgColor

        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        textField.rightView = paddingView
        textField.rightViewMode = .always
    }

    // MARK: - Navigation Bar Style
    static func styleNavigationBar(_ navigationBar: UINavigationBar) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Colors.background
        appearance.titleTextAttributes = [
            .foregroundColor: Colors.textPrimary,
            .font: Fonts.headingMedium
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: Colors.textPrimary,
            .font: Fonts.headingLargeRounded
        ]
        appearance.shadowColor = .clear

        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = Colors.primaryBrown
    }

    // MARK: - Tab Bar Style
    static func styleTabBar(_ tabBar: UITabBar) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Colors.cardBackground

        appearance.stackedLayoutAppearance.normal.iconColor = Colors.textMuted
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: Colors.textMuted]
        appearance.stackedLayoutAppearance.selected.iconColor = Colors.primaryBrown
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: Colors.primaryBrown]

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    // MARK: - Table View Style
    static func styleTableView(_ tableView: UITableView) {
        tableView.backgroundColor = Colors.background
        tableView.separatorColor = Colors.border
        tableView.separatorInset = UIEdgeInsets(top: 0, left: Spacing.screenPadding, bottom: 0, right: Spacing.screenPadding)
    }

    // MARK: - Cell Style
    static func applyCellStyle(to cell: UITableViewCell) {
        cell.backgroundColor = Colors.cardBackground
        cell.selectionStyle = .none
    }

    // MARK: - Section Header Style
    static func styleSectionHeader(_ headerView: UIView) {
        headerView.backgroundColor = Colors.background
    }
}
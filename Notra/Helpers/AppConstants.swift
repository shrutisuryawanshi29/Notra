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
    // MARK: - Theme Mode
    enum ThemeMode {
        case light
        case dark
    }

    struct Palette {
        let background: UIColor
        let backgroundLight: UIColor
        let backgroundIvory: UIColor
        let primaryBrown: UIColor
        let primaryBrownLight: UIColor
        let secondaryBrown: UIColor
        let secondaryTan: UIColor
        let cardBackground: UIColor
        let cardBackgroundAlt: UIColor
        let textPrimary: UIColor
        let textSecondary: UIColor
        let textMuted: UIColor
        let expense: UIColor
        let expenseLight: UIColor
        let income: UIColor
        let incomeLight: UIColor
        let border: UIColor
        let accent: UIColor
        let accentSecondary: UIColor
        let warning: UIColor
        let shadow: UIColor
    }

    static let lightPalette = Palette(
        background: UIColor(red: 246/255, green: 239/255, blue: 227/255, alpha: 1), // #F6EFE3
        backgroundLight: UIColor(red: 239/255, green: 227/255, blue: 210/255, alpha: 1), // #EFE3D2
        backgroundIvory: UIColor(red: 250/255, green: 247/255, blue: 240/255, alpha: 1), // #FAF7F0
        primaryBrown: UIColor(red: 107/255, green: 70/255, blue: 56/255, alpha: 1), // #6B4638
        primaryBrownLight: UIColor(red: 122/255, green: 80/255, blue: 66/255, alpha: 1), // #7A5042
        secondaryBrown: UIColor(red: 217/255, green: 168/255, blue: 117/255, alpha: 1), // #D9A875
        secondaryTan: UIColor(red: 232/255, green: 201/255, blue: 166/255, alpha: 1), // #E8C9A6
        cardBackground: UIColor(red: 255/255, green: 249/255, blue: 241/255, alpha: 1), // #FFF9F1
        cardBackgroundAlt: UIColor(red: 244/255, green: 232/255, blue: 216/255, alpha: 1), // #F4E8D8
        textPrimary: UIColor(red: 74/255, green: 51/255, blue: 44/255, alpha: 1), // #4A332C
        textSecondary: UIColor(red: 138/255, green: 106/255, blue: 91/255, alpha: 1), // #8A6A5B
        textMuted: UIColor(red: 180/255, green: 154/255, blue: 138/255, alpha: 1), // #B49A8A
        expense: UIColor(red: 217/255, green: 139/255, blue: 125/255, alpha: 1), // #D98B7D
        expenseLight: UIColor(red: 231/255, green: 163/255, blue: 154/255, alpha: 1), // #E7A39A
        income: UIColor(red: 167/255, green: 200/255, blue: 162/255, alpha: 1), // #A7C8A2
        incomeLight: UIColor(red: 200/255, green: 221/255, blue: 190/255, alpha: 1), // #C8DDBE
        border: UIColor(red: 227/255, green: 210/255, blue: 193/255, alpha: 1), // #E3D2C1
        accent: UIColor(red: 217/255, green: 168/255, blue: 117/255, alpha: 1), // #D9A875
        accentSecondary: UIColor(red: 232/255, green: 201/255, blue: 166/255, alpha: 1), // #E8C9A6
        warning: UIColor(red: 210/255, green: 160/255, blue: 90/255, alpha: 1), // #D2A05A
        shadow: UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 1) // black
    )

    static let darkPalette = Palette(
        background: UIColor(red: 43/255, green: 36/255, blue: 30/255, alpha: 1), // #2B241E
        backgroundLight: UIColor(red: 51/255, green: 42/255, blue: 35/255, alpha: 1), // #332A23
        backgroundIvory: UIColor(red: 31/255, green: 26/255, blue: 22/255, alpha: 1), // #1F1A16
        primaryBrown: UIColor(red: 237/255, green: 225/255, blue: 209/255, alpha: 1), // #EDE1D1
        primaryBrownLight: UIColor(red: 216/255, green: 198/255, blue: 180/255, alpha: 1), // #D8C6B4
        secondaryBrown: UIColor(red: 201/255, green: 145/255, blue: 82/255, alpha: 1), // #C99152
        secondaryTan: UIColor(red: 169/255, green: 120/255, blue: 69/255, alpha: 1), // #A97845
        cardBackground: UIColor(red: 54/255, green: 45/255, blue: 37/255, alpha: 1), // #362D25
        cardBackgroundAlt: UIColor(red: 64/255, green: 52/255, blue: 43/255, alpha: 1), // #40342B
        textPrimary: UIColor(red: 244/255, green: 233/255, blue: 218/255, alpha: 1), // #F4E9DA
        textSecondary: UIColor(red: 203/255, green: 185/255, blue: 167/255, alpha: 1), // #CBB9A7
        textMuted: UIColor(red: 155/255, green: 135/255, blue: 120/255, alpha: 1), // #9B8778
        expense: UIColor(red: 199/255, green: 116/255, blue: 90/255, alpha: 1), // #C7745A
        expenseLight: UIColor(red: 224/255, green: 154/255, blue: 130/255, alpha: 1), // #E09A82
        income: UIColor(red: 140/255, green: 163/255, blue: 125/255, alpha: 1), // #8CA37D
        incomeLight: UIColor(red: 178/255, green: 197/255, blue: 166/255, alpha: 1), // #B2C5A6
        border: UIColor(red: 76/255, green: 64/255, blue: 54/255, alpha: 1), // #4C4036
        accent: UIColor(red: 201/255, green: 145/255, blue: 82/255, alpha: 1), // #C99152
        accentSecondary: UIColor(red: 169/255, green: 120/255, blue: 69/255, alpha: 1), // #A97845
        warning: UIColor(red: 196/255, green: 154/255, blue: 90/255, alpha: 1), // #C49A5A
        shadow: UIColor(red: 18/255, green: 14/255, blue: 11/255, alpha: 1) // #120E0B
    )

    // Switch to .dark for dark theme preview; .light restores original appearance
    static var currentMode: ThemeMode = .dark

    static var activePalette: Palette {
        switch currentMode {
        case .light:
            return lightPalette
        case .dark:
            return darkPalette
        }
    }

    // MARK: - Colors
    struct Colors {
        // App Backgrounds
        static var background: UIColor { AppTheme.activePalette.background }
        static var backgroundLight: UIColor { AppTheme.activePalette.backgroundLight }
        static var backgroundIvory: UIColor { AppTheme.activePalette.backgroundIvory }

        // Primary Brown
        static var primaryBrown: UIColor { AppTheme.activePalette.primaryBrown }
        static var primaryBrownLight: UIColor { AppTheme.activePalette.primaryBrownLight }

        // Secondary Brown
        static var secondaryBrown: UIColor { AppTheme.activePalette.secondaryBrown }
        static var secondaryTan: UIColor { AppTheme.activePalette.secondaryTan }

        // Card Backgrounds
        static var cardBackground: UIColor { AppTheme.activePalette.cardBackground }
        static var cardBackgroundAlt: UIColor { AppTheme.activePalette.cardBackgroundAlt }

        // Text Colors
        static var textPrimary: UIColor { AppTheme.activePalette.textPrimary }
        static var textSecondary: UIColor { AppTheme.activePalette.textSecondary }
        static var textMuted: UIColor { AppTheme.activePalette.textMuted }

        // Expense Accent (Soft coral/clay)
        static var expense: UIColor { AppTheme.activePalette.expense }
        static var expenseLight: UIColor { AppTheme.activePalette.expenseLight }

        // Income Accent (Soft sage green)
        static var income: UIColor { AppTheme.activePalette.income }
        static var incomeLight: UIColor { AppTheme.activePalette.incomeLight }

        // Border/Divider
        static var border: UIColor { AppTheme.activePalette.border }

        // Accent
        static var accent: UIColor { AppTheme.activePalette.accent }
        static var accentSecondary: UIColor { AppTheme.activePalette.accentSecondary }

        // Warning
        static var warning: UIColor { AppTheme.activePalette.warning }

        // Semantic surfaces (stay dark in both modes for buttons/pills)
        static var buttonSurface: UIColor {
            AppTheme.currentMode == .dark ? AppTheme.darkPalette.cardBackgroundAlt : AppTheme.lightPalette.primaryBrown
        }
        static var buttonContent: UIColor {
            AppTheme.currentMode == .dark ? AppTheme.darkPalette.textPrimary : .white
        }
        static var pillContent: UIColor {
            AppTheme.currentMode == .dark ? AppTheme.darkPalette.accent : .white
        }
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
            view.layer.shadowColor = AppTheme.activePalette.shadow.cgColor
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
        button.backgroundColor = Colors.buttonSurface
        button.setTitleColor(Colors.buttonContent, for: .normal)
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
//
//  SceneDelegate.swift
//  Notra
//
//  Created by Shruti Suryawanshi on 5/6/26.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private var pendingDeepLink: DeepLink?
    private var navigationController: UINavigationController?

    struct DeepLink {
        let route: DeepLinkRoute
        let params: [String: String]

        enum DeepLinkRoute: String {
            case addExpense = "add-expense"
            case addIncome = "add-income"
        }
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)

        let nextStep = SetupStateManager.shared.nextRequiredScreen()
        let rootViewController = createViewController(for: nextStep)
        let navigationController = UINavigationController(rootViewController: rootViewController)

        window.rootViewController = navigationController
        self.window = window
        self.navigationController = navigationController
        
        window.overrideUserInterfaceStyle = AppTheme.currentMode == .dark ? .dark : .light
        
        window.makeKeyAndVisible()

        if let urlContext = connectionOptions.urlContexts.first {
            handleDeepLink(url: urlContext.url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleDeepLink(url: url)
    }

    private func handleDeepLink(url: URL) {
        print("[DeepLink] Received URL: \(url.absoluteString)")

        guard url.scheme == "notra" else {
            print("[DeepLink] Invalid scheme: \(url.scheme ?? "nil")")
            return
        }

        let path = url.host ?? ""
        let params = parseQueryParameters(url)

        let route: DeepLink.DeepLinkRoute?
        switch path {
        case "add-expense":
            route = .addExpense
        case "add-income":
            route = .addIncome
        default:
            print("[DeepLink] Unknown route: \(path)")
            route = nil
        }

        guard let validRoute = route else { return }

        let deepLink = DeepLink(route: validRoute, params: params)
        print("[DeepLink] Parsed: \(validRoute.rawValue) with params: \(params)")

        if SetupStateManager.shared.isSetupComplete() {
            navigateToAddTransaction(deepLink: deepLink)
        } else {
            print("[DeepLink] Setup not complete, storing for later")
            pendingDeepLink = deepLink
            showSetupIncompleteMessage()
        }
    }

    private func parseQueryParameters(_ url: URL) -> [String: String] {
        var params: [String: String] = [:]
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return params
        }

        for item in queryItems {
            if let value = item.value {
                params[item.name] = value
            }
        }
        return params
    }

    private func showSetupIncompleteMessage() {
        guard let nav = navigationController else { return }

        let alert = UIAlertController(
            title: "Setup Required",
            message: "Please complete Notra setup before adding transactions.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        nav.present(alert, animated: true)
    }

    private func navigateToAddTransaction(deepLink: DeepLink) {
        guard let nav = navigationController else {
            print("[DeepLink] No navigation controller available")
            return
        }

        let role: DatabaseRole = deepLink.route == .addExpense ? .expense : .income

        nav.dismiss(animated: false) {
            let addTransactionVC = AddTransactionViewController(prefillData: deepLink.params, initialRole: role)
            let addNav = UINavigationController(rootViewController: addTransactionVC)
            addNav.modalPresentationStyle = .fullScreen
            nav.present(addNav, animated: true)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        if let deepLink = pendingDeepLink, SetupStateManager.shared.isSetupComplete() {
            pendingDeepLink = nil
            navigateToAddTransaction(deepLink: deepLink)
        }
    }

    private func createViewController(for step: SetupStep) -> UIViewController {
        switch step {
        case .tokenEntry:
            return TokenEntryViewController()

        case .pagePicker:
            return PagePickerViewController()

        case .databaseRoleAssignment:
            return DatabaseRoleAssignmentViewController()

        case .columnMapping:
            return DatabaseRoleAssignmentViewController()

        case .dashboard:
            if let token = UserDefaultsManager.shared.notionToken {
                return DashboardViewController(token: token)
            }
            return TokenEntryViewController()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}
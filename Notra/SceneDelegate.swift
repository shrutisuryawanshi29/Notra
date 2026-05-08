//
//  SceneDelegate.swift
//  Notra
//
//  Created by Shruti Suryawanshi on 5/6/26.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)

        let nextStep = SetupStateManager.shared.nextRequiredScreen()
        let rootViewController = createViewController(for: nextStep)
        let navigationController = UINavigationController(rootViewController: rootViewController)

        window.rootViewController = navigationController
        self.window = window
        window.makeKeyAndVisible()
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

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}
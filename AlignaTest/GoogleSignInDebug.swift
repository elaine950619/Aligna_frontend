import Foundation
import UIKit
import SafariServices
import GoogleSignIn
import FirebaseAuth
import FirebaseCore

extension UIApplication {
    var topVC_debug: UIViewController? {
        guard let window = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { return nil }
        var vc = window.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }
}

/// 仅用于定位“网页弹不出/像断网”的问题
enum GoogleSignInDebug {
    static func signInWithStrongLogging(
        onNewUserGoOnboarding: @escaping () -> Void,
        onExistingUserGoLogin: @escaping (_ message: String) -> Void,
        onError: @escaping (_ message: String) -> Void
    ) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            onError("Missing Firebase clientID."); return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = UIApplication.shared.topVC_debug else {
            onError("No presenting view controller."); return
        }

        print("🟦 [GSID] will present Google sheet (ASWebAuthenticationSession)…")

        var fallbackArmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if fallbackArmed, let vc = UIApplication.shared.topVC_debug,
               vc.presentedViewController == nil {
                print("🟨 [GSID] No sheet after 0.8s, opening SFSafari for diagnostics…")
                presentAccountsInSafari(from: vc)
            }
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { signInResult, signInError in
            fallbackArmed = false
            if let e = signInError {
                print("🟥 [GSID] Google sign-in failed: \(e.localizedDescription)")
                onError("Google sign-in failed: \(e.localizedDescription)")
                return
            }
            guard
                let user = signInResult?.user,
                let idToken = user.idToken?.tokenString
            else {
                print("🟥 [GSID] Empty Google sign-in result.")
                onError("Empty Google sign-in result.")
                return
            }

            print("🟩 [GSID] Got Google tokens, signing in Firebase…")
            let cred = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            Auth.auth().signIn(with: cred) { authResult, err in
                if let err = err {
                    print("🟥 [GSID] Firebase auth failed: \(err.localizedDescription)")
                    onError("Firebase auth failed: \(err.localizedDescription)")
                    return
                }
                let isNew = authResult?.additionalUserInfo?.isNewUser ?? false
                print("🟩 [GSID] Firebase ok, isNew=\(isNew)")
                if isNew { onNewUserGoOnboarding() }
                else { onExistingUserGoLogin("This Google account is already registered. Please sign in instead.") }
            }
        }
    }

    private static func presentAccountsInSafari(from vc: UIViewController) {
        guard let url = URL(string: "https://accounts.google.com") else { return }
        let safari = SFSafariViewController(url: url)
        safari.dismissButtonStyle = .close
        vc.present(safari, animated: true)
    }
}


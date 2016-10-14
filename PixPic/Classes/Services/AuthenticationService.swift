//
//  AuthenticationService.swift
//  PixPic
//
//  Created by anna on 1/18/16.
//  Copyright © 2016 Yalantis. All rights reserved.
//

import Foundation
import Parse
import ParseFacebookUtilsV4

enum AuthenticationError: Int {
    
    case facebookError = 701
    case parseError = 702
    case parseCurrentUserNotExist = 703
    case invalidAccessToken = 704
    
}

class AuthenticationService {

    func signInWithPermission(_ completion: @escaping (User?, Error?) -> Void) {
        guard let token = FBSDKAccessToken.current() else {
            let accessTokenError = NSError.authenticationError(.invalidAccessToken)
            completion(nil, accessTokenError)

            return
        }
        PFFacebookUtils.logInInBackground(with: token) { [weak self] user, error in
            if let user = user as? User {
                if user.isNew || user.facebookId == nil {
                    self?.updateUserInfoViaFacebook(user) { user, error in
                        completion(user, nil)
                    }
                } else {
                    completion(user, nil)
                }
            } else if let error = error {
                completion(nil, error)
            } else {
                let userError = NSError.authenticationError(.facebookError)
                completion(nil, userError)

                return
            }
        }
    }

    func signInWithFacebookInController(_ controller: UIViewController, completion: @escaping (FBSDKLoginManagerLoginResult?, Error?) -> Void) {
        let loginManager = FBSDKLoginManager()
        let permissions = ["public_profile", "email", "user_photos"]

        loginManager.loginBehavior = .native
        loginManager.logIn(withReadPermissions: permissions, from: controller) { result, error in
            if error != nil || (result?.isCancelled)! {
                loginManager.logOut()
                completion(nil, error)
            } else {
                completion(result, nil)
            }
        }
    }

    func updateUserInfoViaFacebook(_ user: User, completion: @escaping (User?, Error?) -> Void) {
        let parameters = ["fields": "id, name, first_name, last_name, picture.type(large), email"]
        let fbRequest = FBSDKGraphRequest(
            graphPath: "me",
            parameters: parameters
        )
        fbRequest?.start { _, result, error in
            if error == nil && result != nil {
                guard let facebookInfo = result as? [String: AnyObject],
                    let picture = facebookInfo["picture"] as? [String: AnyObject],
                    let data = picture["data"] as? [String: AnyObject],
                    let url = data["url"] as? String else {
                        completion(nil, nil)

                        return
                }
                if let avatarURL = NSURL(string: url) {
                    let avatarFile = PFFile(
                        name: Constants.UserKey.avatar,
                        data: NSData(contentsOf: avatarURL as URL)! as Data
                    )
                    user.avatar = avatarFile
                }
                if let email = facebookInfo["email"] as? String {
                    user.email = email
                }
                user.facebookId = facebookInfo["id"] as? String
                if let firstname = facebookInfo["first_name"] as? String,
                    let lastname = facebookInfo["last_name"] as? String {
                        user.username = "\(firstname) \(lastname)"
                }
                completion(user, nil)
            } else {
                completion(nil, error)
            }
        }
    }

    func anonymousLogIn(completion: @escaping (_ object: User?) -> Void, failure: @escaping (_ error: Error?) -> Void) {
        PFAnonymousUtils.logIn { user, error in
            if let error = error {
                failure(error)
            } else if let user = user as? User {
                completion(user)
                PFInstallation.addPFUserToCurrentInstallation()
            }
        }
    }

    func logOut() {
        User.logOut()
        FBSDKLoginManager().logOut()
    }

}

//
//  UserService.swift
//  PixPic
//
//  Created by Jack Lapin on 16.02.16.
//  Copyright © 2016 Yalantis. All rights reserved.
//

import Foundation

typealias LoadingUserCompletion = (_ object: User?, _ error: Error?) -> Void

private let messageDataSuccessfullyUpdated = NSLocalizedString("user_data_updated", comment: "")
private let messageDataNotUpdated = NSLocalizedString("check_later", comment: "")

class UserService {

    func uploadUserChanges(_ user: User, avatar: PFFile, nickname: String, completion: @escaping (Bool?, String?) -> Void) {
        user.avatar = avatar
        user.username = nickname
        user.saveInBackground { succeeded, error in
            if succeeded {
                completion(true, nil)
                AlertManager.sharedInstance.showSimpleAlert(messageDataSuccessfullyUpdated)
            } else {
                AlertManager.sharedInstance.showSimpleAlert(messageDataNotUpdated)
                if let error = error?.localizedDescription {
                    completion(false, error)
                }
            }
        }
    }

    func fetchUser(_ userId: String, completion: @escaping (_ user: User?, _ error: Error?) -> Void) {
        let query = User.sortedQuery
        query.whereKey(Constants.UserKey.id, equalTo: userId)
        query.findObjectsInBackground { objects, error in
            if let error = error {
                completion(nil, error)
            } else if let user = objects?.first as? User {
                completion(user, nil)
            }
        }
    }

}

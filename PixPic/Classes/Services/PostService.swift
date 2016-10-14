//
//  PostService.swift
//  PixPic
//
//  Created by Jack Lapin on 16.02.16.
//  Copyright © 2016 Yalantis. All rights reserved.
//

import Foundation

private let messageUploadSuccessful = NSLocalizedString("upload_successful", comment: "")

typealias LoadingPostsCompletion = (_ posts: [Post]?, _ error: Error?) -> Void

class PostService {

    // MARK: - Public methods
    func loadPosts(_ user: User? = nil, completion: @escaping LoadingPostsCompletion) {
        let query = Post.sortedQuery
        query.cachePolicy = .networkElseCache
        query.limit = Constants.DataSource.queryLimit
        loadPosts(user, query: query, completion: completion)
    }

    func loadPagedPosts(_ user: User? = nil, offset: Int = 0, completion: @escaping LoadingPostsCompletion) {
        let query = Post.sortedQuery
        query.cachePolicy = .networkElseCache
        query.limit = Constants.DataSource.queryLimit
        query.skip = offset
        loadPosts(user, query: query, completion: completion)
    }

    func savePost(_ image: PFFile, comment: String? = nil) {
        image.saveInBackground({ succeeded, error in
            if succeeded {
                log.debug("Saved!")
                self.uploadPost(image, comment: comment)
            } else if let error = error {
                log.debug(error.localizedDescription)
            }
            }, progressBlock: { progress in
                log.debug("Uploaded: \(progress)%")
        })
    }

    func removePost(_ post: Post, completion: @escaping (Bool, Error?) -> Void) {
        post.deleteInBackground(block: completion)
    }

    // MARK: - Private methods
    fileprivate func uploadPost(_ image: PFFile, comment: String?) {
        guard let user = User.current() else {
            // Authentication service
            return
        }
        let post = Post(image: image, user: user, comment: comment)
        post.saveInBackground { succeeded, error in
            if succeeded {
                AlertManager.sharedInstance.showSimpleAlert(messageUploadSuccessful)
                NotificationCenter.default.post(name:
                    NSNotification.Name(rawValue: Constants.NotificationName.newPostIsUploaded),
                    object: nil
                )
            } else {
                if let error = error?.localizedDescription {
                    log.debug(error)
                }
            }
        }
    }

    fileprivate func loadPosts(_ user: User?, query: PFQuery<PFObject>, completion: @escaping LoadingPostsCompletion) {
        if User.isAbsent {
            log.debug("No user signUP")
            fetchPosts(query, completion: completion)

            return
        }
        query.cachePolicy = .networkElseCache

        if let user = user {
            query.whereKey("user", equalTo: user)
            fetchPosts(query, completion: completion)

        } else if SettingsHelper.isShownOnlyFollowingUsersPosts && !User.notAuthorized {
            let followersQuery = PFQuery(className: Activity.parseClassName())
            followersQuery.cachePolicy = .cacheThenNetwork
            followersQuery.whereKey(Constants.ActivityKey.fromUser, equalTo: User.current()!)
            followersQuery.whereKey(Constants.ActivityKey.type, equalTo: ActivityType.Follow.rawValue)
            followersQuery.includeKey(Constants.ActivityKey.toUser)

            var arrayOfFollowers: [User] = [User.current()!]
            followersQuery.findObjectsInBackground { [weak self] activities, error in
                if let error = error {
                    log.debug(error.localizedDescription)
                } else if let activities = activities as? [Activity] {
                    let friends = activities.flatMap { $0[Constants.ActivityKey.toUser] as? User }
                    arrayOfFollowers.append(contentsOf: friends)
                }
                query.whereKey("user", containedIn: arrayOfFollowers)
                self?.fetchPosts(query, completion: completion)
            }
        } else {
            fetchPosts(query, completion: completion)
        }
    }

    fileprivate func fetchPosts(_ query: PFQuery<PFObject>, completion: @escaping LoadingPostsCompletion) {
        var posts = [Post]()
        query.findObjectsInBackground { objects, error in
            if let objects = objects {
                for object in objects {
                    posts.append(object as! Post)
                    object.saveEventually()
                }
                completion(posts, nil)
            } else if let error = error {
                log.debug(error.localizedDescription)
                completion(nil, error)
            } else {
                completion(nil, nil)
            }
        }
    }

}

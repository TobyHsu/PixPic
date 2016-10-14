//
//  ActivityService.swift
//  PixPic
//
//  Created by Jack Lapin on 04.03.16.
//  Copyright © 2016 Yalantis. All rights reserved.
//

import Foundation
import Parse

typealias FetchingFollowersCompletion = ((_ followers: [User]?, _ error: Error?) -> Void)?
typealias FetchingLikesCompletion = ((_ likers: [User]?, _ error: Error?) -> Void)?

class ActivityService {

    func fetchFollowers(_ type: FollowType, forUser user: User, completion: FetchingFollowersCompletion) {
        let isFollowers = (type == .Followers)
        let key = isFollowers ? Constants.ActivityKey.toUser : Constants.ActivityKey.fromUser

        let query = PFQuery(className: Activity.parseClassName())
        query.whereKey(key, equalTo: user)
        query.whereKey(Constants.ActivityKey.type, equalTo: ActivityType.Follow.rawValue)
        query.cachePolicy = .cacheThenNetwork
        query.findObjectsInBackground { followActivities, error in
            if let error = error {
                completion?(nil, error)
            } else if let activities = followActivities as? [Activity] {
                let followers = isFollowers ? activities.map { $0.fromUser } : activities.map { $0.toUser }
                let followerQuery = User.sortedQuery
                var followersIds = [String]()
                for follower in followers {
                    if let followerId = follower.objectId {
                        followersIds.append(followerId)
                    }
                }
                followerQuery.whereKey(Constants.UserKey.id, containedIn: followersIds)

                followerQuery.findObjectsInBackground { objects, error in
                    if let followers = objects as? [User] {
                        if isFollowers {
                            AttributesCache.sharedCache.setAttributesForUser(user, followers: followers)
                        } else {
                            AttributesCache.sharedCache.setAttributesForUser(user, following: followers)
                        }
                        completion?(followers, nil)
                    } else if let error = error {
                        completion?(nil, error)
                    }
                }
            }
        }
    }

    func fetchFollowersQuantity(_ user: User, completion: ((_ followersCount: Int, _ followingCount: Int) -> Void)?) {
        var followersCount = 0
        var followingCount = 0
        fetchFollowers(.Followers, forUser: user) { [weak self] activities, error -> Void in
            if let activities = activities {
                followersCount = activities.count
                self?.fetchFollowers(.Following, forUser: user) { activities, error -> Void in
                    if let activities = activities {
                        followingCount = activities.count
                        completion?(followersCount, followingCount)
                        AttributesCache.sharedCache.setAttributesForUser(
                            user,
                            followersCount: followersCount,
                            followingCount: followingCount
                        )
                    }
                }
            }
        }
    }

    func checkFollowingStatus(_ user: User, completion: @escaping (FollowStatus) -> Void) {
        let isFollowingQuery = PFQuery(className: Activity.parseClassName())
        isFollowingQuery.whereKey(Constants.ActivityKey.fromUser, equalTo: User.current()!)
        isFollowingQuery.whereKey(Constants.ActivityKey.type, equalTo: ActivityType.Follow.rawValue)
        isFollowingQuery.whereKey(Constants.ActivityKey.toUser, equalTo: user)
        isFollowingQuery.countObjectsInBackground { count, error in
            let status: FollowStatus = (error == nil && count > 0) ? .following : .notFollowing
            AttributesCache.sharedCache.setFollowStatus(status, user: user)
            completion(status)
        }
    }

    func followUserEventually(_ user: User, block completionBlock: ((_ succeeded: Bool, _ error: Error?) -> Void)?) {
        guard let currentUser = User.current() else {
            let userError = NSError.authenticationError(.parseCurrentUserNotExist)
            completionBlock?(false, userError)

            return
        }
        if user.objectId == currentUser.objectId {
            completionBlock?(false, nil)

            return
        }
        let followActivity = Activity()
        followActivity.type = ActivityType.Follow.rawValue
        followActivity.fromUser = currentUser
        followActivity.toUser = user
        followActivity.saveInBackground(block: completionBlock as! PFBooleanResultBlock?)
        AttributesCache.sharedCache.setFollowStatus(.following, user: user)
    }

    func unfollowUserEventually(_ user: User, block completionBlock: ((_ succeeded: Bool, _ error: Error?) -> Void)?) {
        guard let currentUser = User.current() else {
            let userError = NSError.authenticationError(.parseCurrentUserNotExist)
            completionBlock?(false, userError)

            return
        }
        let query = PFQuery(className: Activity.parseClassName())
        query.whereKey(Constants.ActivityKey.fromUser, equalTo: currentUser)
        query.whereKey(Constants.ActivityKey.toUser, equalTo: user)
        query.whereKey(Constants.ActivityKey.type, equalTo: ActivityType.Follow.rawValue)
        query.cachePolicy = .cacheThenNetwork
        query.findObjectsInBackground { followActivities, error in
            if let error = error {
                completionBlock?(false, error)
            } else if let followActivities = followActivities {
                for followActivity in followActivities {
                    followActivity.deleteInBackground(block: completionBlock)
                }
            }
        }
        AttributesCache.sharedCache.setFollowStatus(.notFollowing, user: user)
    }

    func likePostEventually(_ post: Post, block completionBlock: ((_ succeeded: Bool, _ error: Error?) -> Void)?) {
        guard let currentUser = User.current() else {
            let userError = NSError.authenticationError(.parseCurrentUserNotExist)
            completionBlock?(false, userError)

            return
        }
        let likeActivity = Activity()
        likeActivity.type = ActivityType.Like.rawValue
        likeActivity.fromUser = currentUser
        likeActivity.toPost = post
        likeActivity.saveInBackground(block: completionBlock)
        AttributesCache.sharedCache.setLikeStatusByCurrentUser(post, likeStatus: .liked)
    }

    func unlikePostEventually(_ post: Post, block completionBlock: ((_ succeeded: Bool, _ error: Error?) -> Void)?) {
        guard let currentUser = User.current() else {
            let userError = NSError.authenticationError(.parseCurrentUserNotExist)
            completionBlock?(false, userError)

            return
        }
        let query = PFQuery(className: Activity.parseClassName())
        query.whereKey(Constants.ActivityKey.fromUser, equalTo: currentUser)
        query.whereKey(Constants.ActivityKey.toPost, equalTo: post)
        query.whereKey(Constants.ActivityKey.type, equalTo: ActivityType.Like.rawValue)
        query.cachePolicy = .cacheThenNetwork
        query.findObjectsInBackground { likeActivities, error in
            if let error = error {
                completionBlock?(false, error)
            } else if let likeActivities = likeActivities {
                for likeActivity in likeActivities {
                    likeActivity.deleteInBackground(block: completionBlock)
                }
            }
        }
        AttributesCache.sharedCache.setLikeStatusByCurrentUser(post, likeStatus: .notLiked)
    }

    func fetchLikers(_ post: Post, completion: FetchingLikesCompletion) {
        let key = Constants.ActivityKey.toPost
        let query = PFQuery(className: Activity.parseClassName())
        query.cachePolicy = .cacheThenNetwork
        query.whereKey(key, equalTo: post)
        query.whereKey(Constants.ActivityKey.type, equalTo: ActivityType.Like.rawValue)

        query.findObjectsInBackground { likeActivities, error in
            if let error = error {
                completion?(nil, error)
            } else if let activities = likeActivities as? [Activity] {

                let likers = activities.map { $0.fromUser }
                AttributesCache.sharedCache.setAttributes(for: post, likers: likers)
                completion?(likers, nil)
            }
        }
    }

    func fetchLikesQuantity(_ post: Post, completion: ((Int) -> Void)?) {
        fetchLikers(post) { likers, error in
            if let likers = likers {
                let likersCount = likers.count
                completion?(likersCount)
                AttributesCache.sharedCache.setAttributes(for: post, likers: likers, likeStatusByCurrentUser: .liked)
            }
        }
    }

    func fetchLikeStatus(_ post: Post, completion: @escaping (LikeStatus) -> Void) {
        let islikedQuery = PFQuery(className: Activity.parseClassName())
        islikedQuery.cachePolicy = .cacheThenNetwork
        islikedQuery.whereKey(Constants.ActivityKey.fromUser, equalTo: User.current()!)
        islikedQuery.whereKey(Constants.ActivityKey.type, equalTo: ActivityType.Like.rawValue)
        islikedQuery.whereKey(Constants.ActivityKey.toPost, equalTo: post)
        islikedQuery.getFirstObjectInBackground { likeActivity, error in
            if likeActivity != nil {
                AttributesCache.sharedCache.setAttributes(for: post, likeStatusByCurrentUser: .liked)
                completion(.liked)
            } else {
                AttributesCache.sharedCache.setAttributes(for: post, likeStatusByCurrentUser: .notLiked)
                completion(.notLiked)
            }
        }
    }

}

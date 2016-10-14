//
//  EffectsService.swift
//  PixPic
//
//  Created by anna on 2/16/16.
//  Copyright © 2016 Yalantis. All rights reserved.
//

import Foundation

typealias LoadingStickersCompletion = (_ objects: [StickersModel]?, _ error: Error?) -> Void

class StickersLoaderService {

    fileprivate var cachePolicy: PFCachePolicy!

    //register Parse subclasses
    init() {
        StickersGroup.initialize()
        Sticker.initialize()
    }

    func loadStickers(_ completion: LoadingStickersCompletion? = nil) {
        figureOutCachePolicy { [weak self] in
            guard let this = self else {
                return
            }

            let query = StickersVersion.sortedQuery
            query.cachePolicy = this.cachePolicy

            query.getFirstObjectInBackground { object, error in
                if let error = error {
                    log.debug(error.localizedDescription)
                    completion?(nil, error)

                    return
                }

                guard let stickersVersion = object as? StickersVersion  else {
                    completion?(nil, nil)

                    return
                }

                this.loadStickersGroups(stickersVersion) { objects, error in
                    completion?(objects, error)
                }
            }
        }
    }

    fileprivate func loadStickersGroups(_ stickersVersion: StickersVersion, completion: @escaping LoadingStickersCompletion) {
        let groupsRelationQuery = stickersVersion.groupsRelation.query()
        groupsRelationQuery.cachePolicy = cachePolicy
        groupsRelationQuery.findObjectsInBackground { [weak self] objects, error in
            if let error = error {
                log.debug(error.localizedDescription)
                completion(nil, error)

                return
            }

            guard let objects = objects as? [StickersGroup] else {
                completion(nil, nil)

                return
            }

            self?.loadAllStickers(objects) { objects, error in
                completion(objects, error)
            }
        }
    }

    fileprivate func loadAllStickers(_ stickersGroups: [StickersGroup], completion: @escaping LoadingStickersCompletion) {
        var stickersModels = [StickersModel]()

        let dispatchGroup = DispatchGroup()

        for group in stickersGroups {
            log.debug("\(group.label)")
            dispatchGroup.enter()

            let comletionBlock = {
                let stickersRelationQuery = group.stickersRelation.query().addAscendingOrder("createdAt")
                stickersRelationQuery.cachePolicy = self.cachePolicy
                stickersRelationQuery.findObjectsInBackground { objects, error in
                    if let error = error {
                        log.debug(error.localizedDescription)
                        completion(nil, error)

                        return
                    }
                    guard let stickers = objects as? [Sticker] else {
                        completion(nil, nil)

                        return
                    }

                    let model = StickersModel(stickersGroup: group, stickers: stickers)
                    stickersModels.append(model)

                    dispatchGroup.leave()

                    for sticker in stickers {
                        sticker.image.getDataInBackground()
                    }
                }
            }

            group.image.getDataInBackground { _, _ in
                comletionBlock()
            }

        }
        dispatchGroup.notify(queue: DispatchQueue.main) {
            completion(stickersModels, nil)
        }

    }

    fileprivate func figureOutCachePolicy(with handler: @escaping () -> Void) {
        //load stickers from cache
        cachePolicy = PFCachePolicy.cacheElseNetwork
        handler()

        //figure out update necessity and handle it if needed
        let remoteQuery = StickersVersion.sortedQuery
        remoteQuery.cachePolicy = .networkOnly

        let localQuery = StickersVersion.sortedQuery
        localQuery.cachePolicy = .cacheOnly

        guard ReachabilityHelper.isReachable() else {
            handler()

            return
        }

        localQuery.getFirstObjectInBackground { localObject, error in
            if let error = error {
                log.debug(error.localizedDescription)
                self.cachePolicy = .networkElseCache
                handler()

                return
            }

            guard let localVersion = localObject as? StickersVersion else {
                return
            }

            remoteQuery.getFirstObjectInBackground { remoteObject, error in
                if let error = error {
                    log.debug(error.localizedDescription)
                    handler()

                    return
                }

                guard let remoteVersion = remoteObject as? StickersVersion else {
                    return
                }

                if remoteVersion.version > localVersion.version {
                    log.debug("\(remoteVersion.version) > \(localVersion.version)")
                    self.cachePolicy = .networkElseCache
                    handler()
                }
            }
        }
    }

}

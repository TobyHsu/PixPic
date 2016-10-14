//
//  RemoteNotificationManager.swift
//  PixPic
//
//  Created by Jack Lapin on 14.03.16.
//  Copyright © 2016 Yalantis. All rights reserved.
//

import Foundation

class RemoteNotificationHelper {

    static func setNotificationsAvailable(_ enabled: Bool) {
        let application = UIApplication.shared
        if enabled {
            let settings = UIUserNotificationSettings(
                types: [.alert, .badge, .sound],
                categories: nil
            )
            application.registerUserNotificationSettings(settings)
            application.registerForRemoteNotifications()
        } else {
            application.unregisterForRemoteNotifications()
        }
    }

}

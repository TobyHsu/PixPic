//
//  AppDelegate.swift
//  PixPic
//
//  Created by Jack Lapin on 14.01.16.
//  Copyright © 2016 Yalantis. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics
import Parse
import ParseFacebookUtilsV4
import Bolts
import XCGLogger
import Toast

let log = XCGLogger.default

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    fileprivate lazy var router = LaunchRouter()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
        setupParse()
        PFFacebookUtils.initializeFacebook(applicationLaunchOptions: launchOptions)

        Fabric.with([Crashlytics.self])

        if application.applicationState != .background {
            setupParseAnalyticsWith(launchOptions: launchOptions)
        }
        UIApplication.shared.statusBarStyle = .lightContent

        log.setup()
        setupToast()
        SettingsHelper.setupDefaultValues()
        setupRouter()

        return true
    }

    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        return FBSDKApplicationDelegate.sharedInstance().application(application,
                                                                     open: url,
                                                                     sourceApplication: sourceApplication,
                                                                     annotation: annotation)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let installation = PFInstallation.current()
        installation?.setDeviceTokenFrom(deviceToken)
        installation?.channels = ["global"]
        installation?.saveEventually()
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        if application.applicationState == .inactive {
            PFAnalytics.trackAppOpened(withRemoteNotificationPayload: userInfo)
        }
        PFPush.handle(userInfo)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        AlertManager.sharedInstance.handlePush(userInfo)
        if User.isAbsent {
            completionHandler(.noData)
        } else {
            completionHandler(.newData)
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        FBSDKAppEvents.activateApp()
        resetBadge()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        resetBadge()
    }

    fileprivate func resetBadge() {
        let currentInstallation = PFInstallation.current()
        currentInstallation?.badge = 0
        currentInstallation?.saveEventually()
    }

    fileprivate func setupParse() {
        User.registerSubclass()
        Parse.setApplicationId(Constants.ParseApplicationId.AppID, clientKey: Constants.ParseApplicationId.ClientKey)
    }

    fileprivate func setupParseAnalyticsWith(launchOptions options: [AnyHashable: Any]?) {
        if options?[UIApplicationLaunchOptionsKey.remoteNotification] != nil {
            PFAnalytics.trackAppOpened(launchOptions: options)
        }
    }

    fileprivate func setupRouter() {
        window = UIWindow(frame: UIScreen.main.bounds)
        window!.makeKeyAndVisible()
        router.execute(window!, userInfo:  nil)
    }

    fileprivate func setupToast() {
        let style = CSToastStyle(defaultStyle: ())
        style?.backgroundColor = UIColor.clear
        CSToastManager.setSharedStyle(style)
    }

}

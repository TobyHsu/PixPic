//
//  NSError+ErrorType.swift
//  PixPic
//
//  Created by Jack Lapin on 17.02.16.
//  Copyright © 2016 Yalantis. All rights reserved.
//

extension NSError {

    static func authenticationError(_ type: AuthenticationError) -> NSError {
        switch type {
        case .facebookError:
            let error = NSError(
                domain: Bundle.main.bundleIdentifier!,
                code: 701,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Facebook error", comment: "")]
            )

            return error

        case .parseError:
            let error = NSError(
                domain: Bundle.main.bundleIdentifier!,
                code: 702,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Parse error", comment: "")]
            )

            return error

        case .parseCurrentUserNotExist:
            let error = NSError(
                domain: Bundle.main.bundleIdentifier!,
                code: 703,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Parse current user not exist", comment: "")]
            )

            return error

        case .invalidAccessToken:
            let error = NSError(
                domain: Bundle.main.bundleIdentifier!,
                code: 704,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Access token error", comment: "")]
            )

            return error

        default:
            return NSError(
                domain: Bundle.main.bundleIdentifier!,
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Unsupported type", comment: "")]
            )
        }
    }

}

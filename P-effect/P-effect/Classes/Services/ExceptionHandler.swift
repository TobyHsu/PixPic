//
//  ExceptionHandler.swift
//  P-effect
//
//  Created by AndrewPetrov on 2/2/16.
//  Copyright © 2016 Yalantis. All rights reserved.
//

import Foundation

enum Exception: String, ErrorType {
    case NoConnection = "There is no internet connection"
    case CantApplyStickers = "Can't apply stickers to the photo"
    case CantCreateParseFile = "Can't create parse file"
    case InvalidSessionToken = "Can't get authorization data from Facebook"
}

class ExceptionHandler {
    
    static func handle(exception: Exception) {
        AlertManager.sharedInstance.showSimpleAlert(exception.rawValue)
    }
    
}
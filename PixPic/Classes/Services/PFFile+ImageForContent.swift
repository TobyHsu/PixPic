//
//  ImageLoaderService.swift
//  PixPic
//
//  Created by anna on 1/19/16.
//  Copyright © 2016 Yalantis. All rights reserved.
//

import UIKit

typealias LoadingImageCompletion = (_ image: UIImage?, _ error: Error?) -> Void

extension PFFile {

    func getImage(_ completion: @escaping LoadingImageCompletion) {
        getDataInBackground { data, error in
            if let data = data, let image = UIImage(data: data) {
                completion(image, error)
            }
        }
    }

}

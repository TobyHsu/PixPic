//
//  SwitchView.swift
//  PixPic
//
//  Created by AndrewPetrov on 3/10/16.
//  Copyright © 2016 Yalantis. All rights reserved.
//

import Foundation

class SwitchView: UIView {

    fileprivate var action: ((Bool) -> Void)!

    @IBOutlet fileprivate weak var textLabel: UILabel!
    @IBOutlet fileprivate weak var switchControl: UISwitch!

    @IBAction func switchAction(_ sender: UISwitch) {
        action(sender.isOn)
    }

    static func instanceFromNib(_ text: String, initialState: Bool = true, action: @escaping ((Bool) -> Void)) -> SwitchView {
        let view = UINib(nibName: String(describing: self), bundle: nil).instantiate(withOwner: nil, options: nil).first as! SwitchView
        view.textLabel.text = text
        view.action = action
        view.switchControl.setOn(initialState, animated: false)

        return view
    }

}

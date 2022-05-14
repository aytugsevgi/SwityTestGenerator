//
//  ViewController.swift
//  AccessibilityGenerator
//
//  Created by Aytuğ Sevgi on 5.07.2021.
//

import Cocoa

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override var representedObject: Any? {
        didSet {}
    }

    @IBAction func makeEnableButtonTapped(_ sender: NSButton) {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane"))
    }
}

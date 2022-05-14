//
//  Generatable.swift
//  AccessibilityGenerator
//
//  Created by Aytuğ Sevgi on 20.09.2021.
//

import Foundation

public protocol Runnable {
    func isSatisfied(identifier: String) -> Bool
    func execute(lines: NSMutableArray?)
}

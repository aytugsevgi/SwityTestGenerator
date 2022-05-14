//
//  StorageManager.swift
//  AccessibilityGenerator
//
//  Created by Aytuğ Sevgi on 16.10.2021.
//

import Foundation

final class StorageManager {
    static let shared = StorageManager()
    var lines: NSMutableArray?
    private init() {}
}

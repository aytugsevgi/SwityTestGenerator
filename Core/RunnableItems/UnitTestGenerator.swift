//
//  UnitTestGenerator.swift
//  AccessibilityGenerator
//
//  Created by Aytuğ Sevgi on 16.10.2021.
//

import Foundation

final class UnitTestGenerator: Runnable {
    public static var shared: UnitTestGenerator { UnitTestGenerator() }
    
    func isSatisfied(identifier: String) -> Bool {
        identifier == "generateUnitTest"
    }

    func execute(lines: NSMutableArray?) {
        if let storedLines = StorageManager.shared.lines,
           let castedLines = storedLines as? [String] {
            lines?.addObjects(from: castedLines)
        }
    }
}

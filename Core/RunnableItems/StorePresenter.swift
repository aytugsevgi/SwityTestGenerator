//
//  StorePresenter.swift
//  AccessibilityGenerator
//
//  Created by Aytuğ Sevgi on 16.10.2021.
//

import Foundation

final class StorePresenter: Runnable {
    public static var shared: UnitTestGenerator { UnitTestGenerator() }

    func isSatisfied(identifier: String) -> Bool {
        identifier == "readPresenter"
    }

    func execute(lines: NSMutableArray?) {
        StorageManager.shared.lines = lines
    }
}


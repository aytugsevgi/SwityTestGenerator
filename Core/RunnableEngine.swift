//
//  GenerateEngine.swift
//  AccessibilityGenerator
//
//  Created by Aytuğ Sevgi on 20.09.2021.
//

import Foundation

public class RunnableEngine {
    static var shared: RunnableEngine { RunnableEngine() }
    private let items: [Runnable] = [MarkGenerator(),
                                     AccessibilityGenerator(),
                                     UITestablePageGenerator(),
                                     SortGenerate(),
                                     StorePresenter(),
                                     UnitTestGenerator(),
                                     MockAccessibilityGenerator()]

    public func generate(identifier: String, lines: NSMutableArray?) {
        items.first { $0.isSatisfied(identifier: identifier) }?.execute(lines: lines)
    }
}

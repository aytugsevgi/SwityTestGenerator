//
//  SourceEditorCommand.swift
//  SorterExtension
//
//  Created by aniltaskiran on 24.05.2020.
//  Copyright © 2020 Anıl. All rights reserved.
//

import Foundation

final class SortGenerate: Runnable {
    public static var shared: SortGenerate { SortGenerate() }

    func isSatisfied(identifier: String) -> Bool {
        identifier == "sort"
    }

    func execute(lines: NSMutableArray?) {
        // Implement your command here, invoking the completion handler when done. Pass it nil on success, and an NSError on failure.
        guard let lines = lines else { return }
        let bridgedLines = lines.compactMap { $0 as? String }

        let importFrameworks = bridgedLines.enumerated().compactMap({
            $0.element.isImportLine ? $0.element.removeImportPrefix.removeNewLine : nil
        }).sorted()

        let importIndex = bridgedLines.enumerated().compactMap({
            $0.element.isImportLine ? $0.offset : nil
        }).sorted()

        guard importIndex.count == importFrameworks.count && lines.count > importIndex.count else {
            return
        }
        importFrameworks.enumerated().forEach({ lines[importIndex[$0]] = "import \($1)" })
    }
}

struct Line: Comparable {
    static func < (lhs: Line, rhs: Line) -> Bool {
        lhs.element < rhs.element
    }
    let index: Int
    let element: String
}

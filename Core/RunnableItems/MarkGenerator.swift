//
//  MarkGenerator.swift
//  Mark Generator
//
//  Created by aniltaskiran on 24.05.2020.
//  Copyright © 2020 Anıl. All rights reserved.
//

import Foundation

public class MarkGenerator: Runnable {
    public var lines: NSMutableArray?
    public static var shared: MarkGenerator { MarkGenerator() }

    public func isSatisfied(identifier: String) -> Bool {
        identifier == "mark"
    }

    public func execute(lines: NSMutableArray?) {
        self.lines = lines
        guard let lines = lines else { return }
        let bridgedLines = lines.compactMap { $0 as? String }

        bridgedLines.enumerated().forEach { (line) in
            if line.element.isExtension, line.element.contains(":") {
                let index = line.element.contains("private") ? 3 : 2
                let protocolName = line.element.split(separator: " ")[index]
                lines[line.offset - 1] = "// MARK: - \(protocolName)"
            }
        }
    }
}

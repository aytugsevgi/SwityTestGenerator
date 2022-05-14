//
//  String+Extension.swift
//  AccessibilityGenerator
//
//  Created by Aytuğ Sevgi on 20.09.2021.
//

import Foundation

extension String {
    var isBlank: Bool {
        return trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isImportLine: Bool {
        return contains("import")
    }

    var isEnum: Bool {
        contains("enum ")
    }

    var removeImportPrefix: String {
        replacingOccurrences(of: "import", with: "")
    }

    var removeNewLine: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isExtension: Bool {
        contains("extension ")
    }

    mutating func lowercaseFirst() {
        let beginChar = self.removeFirst()
        self = "\(beginChar.lowercased())\(self)"
    }
    mutating func uppercaseFirst() {
        let beginChar = self.removeFirst()
        self = "\(beginChar.uppercased())\(self)"
    }
}



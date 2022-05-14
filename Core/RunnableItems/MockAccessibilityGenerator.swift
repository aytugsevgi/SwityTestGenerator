//
//  MockAccessibilityGenerator.swift
//  AccessibilityGenerator
//
//  Created by Aytuğ Sevgi on 15.11.2021.
//

import Foundation

public final class MockAccessibilityGenerator: Runnable {
    public func isSatisfied(identifier: String) -> Bool {
        identifier == "mockAccessibility"
    }

    public func execute(lines: NSMutableArray?) {
        self.lines = lines
        conformAccessiblityIdenfiableToView()
    }

    public var lines: NSMutableArray?
    private var className: String = .init()

    private lazy var variables: [String] = {
        guard let lines = lines,
              var arrayLines = Array(lines) as? Array<String> else { return .init() }
        let outlets = arrayLines.filter { $0.contains(" = false") && $0.contains("var invoked") }.compactMap { line -> (String)? in
            guard line.components(separatedBy: " ").count > 3,
                  let variable = line.components(separatedBy: " ").suffix(3).first else { return nil }
            return variable
        }
        return outlets
    }()

    public static var shared : MockAccessibilityGenerator { MockAccessibilityGenerator() }

    private func updateLines(from newLines: [String]) {
        guard let lines = lines else { return }
        lines.removeAllObjects()
        lines.addObjects(from: newLines)
    }

    private func addAccessibilityIdetifiable(to conformableLine: String) -> String {
        var conformableLineWords = conformableLine.split(separator: " ")
        let isHasAnyConform = conformableLineWords.count > 3

        if !isHasAnyConform {
            conformableLineWords[1].append(":")
        } else {
            conformableLineWords[conformableLineWords.count - 2].append(",")
        }
        conformableLineWords.insert("MockAssertable", at: conformableLineWords.count - 1 )
        return conformableLineWords.joined(separator: " ")
    }

    private func createUIElements(outletNames: [String], elementsName: String) -> String {
        var elementExtension = "\nenum \(elementsName): String, AccessibilityMockIdentifiable {\n"
        for name in variables {
            elementExtension.append("\tcase \(name)\n")
        }
        elementExtension.append("}")
        return elementExtension
    }

    public func conformAccessiblityIdenfiableToView() {
        guard let lines = lines,
              var arrayLines = Array(lines) as? Array<String> else { return }
        if let firstImportLine = arrayLines.first(where: { $0.contains("import") }),
           let index = arrayLines.firstIndex(of: firstImportLine),
           !arrayLines.contains(where: {$0.contains("import UnitTestUtilsKit")}) {
            arrayLines.insert("import UnitTestUtilsKit", at: abs(index.distance(to: 0)))
        }
        guard let classLine = arrayLines.first(where: { $0.contains("class") && $0.contains(":") }) else { return }
        let classLineWords = classLine.split(separator: " ")
        guard let classIndex = classLineWords.firstIndex(of: "class") else { return }
        className = String(classLineWords[classIndex + 1])
        className.removeAll { $0 == ":"}
        if !classLine.contains("MockAssertable") {
            let conformedLine = addAccessibilityIdetifiable(to: classLine)
            guard let interfaceIndex = arrayLines.firstIndex(of: classLine) else { return }
            arrayLines.remove(at: abs(interfaceIndex.distance(to: 0)))
            arrayLines.insert(conformedLine, at: abs(interfaceIndex.distance(to: 0)))
        }
        arrayLines.append(createUIElements(outletNames: variables, elementsName: "\(className)Elements"))
        updateLines(from: arrayLines)
    }
}

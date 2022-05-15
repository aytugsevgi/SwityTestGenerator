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
        let outlets = arrayLines.filter { $0.contains("func ")}.compactMap { line -> (String)? in
            guard line.components(separatedBy: " ").count > 2 else { return nil }
            var separatedWords = line.components(separatedBy: " ").filter({ !$0.isEmpty })
            separatedWords.removeLast()
            separatedWords.removeFirst()
            var variable = separatedWords.joined(separator: " ")
            let firstChar = variable.removeFirst().uppercased()
            variable = "invoked\(firstChar)\(variable)"
            if variable.hasSuffix("()") {
                variable.removeLast(2)
            } else {
                variable.removeLast()
                variable.append(")")
            }
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
        var elementExtension = "\nenum \(elementsName): MockEquatable {\n"
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
        guard let interfaceIndex = arrayLines.firstIndex(of: classLine) else { return }
        
        // conform MockAssertable if not exist
        if !classLine.contains("MockAssertable") {
            let conformedLine = addAccessibilityIdetifiable(to: classLine)
            arrayLines.remove(at: abs(interfaceIndex.distance(to: 0)))
            arrayLines.insert(conformedLine, at: abs(interfaceIndex.distance(to: 0)))
        }
        
        if arrayLines.first(where: { $0.contains("typealias MockIdentifier =") }) == nil {
            arrayLines.insert("\ttypealias MockIdentifier = \(className)Elements", at: interfaceIndex + 1)
        }
        if arrayLines.first(where: { $0.contains("var invokedList:") }) == nil {
            arrayLines.insert("\tvar invokedList: \(className)Elements = []", at: interfaceIndex + 2)
        }
        
        // add cases to array for each stub
        arrayLines.filter { $0.contains("func ")}.forEach { line in
            guard line.components(separatedBy: " ").count > 2,
                  let index = arrayLines.firstIndex(of: line) else { return }
            var separatedWords = line.components(separatedBy: " ").filter({ !$0.isEmpty })
            separatedWords.removeLast()
            separatedWords.removeFirst()
            var variable = separatedWords.joined(separator: " ")
            let firstChar = variable.removeFirst().uppercased()
            variable = "invoked\(firstChar)\(variable)"
            if variable.hasSuffix("()") {
                variable.removeLast(2)
            } else {
                variable.removeLast()
                variable.append(")")
                var insideOfBrackets = variable.components(separatedBy: "(").last ?? ""
                insideOfBrackets.removeLast()
                let parameters = insideOfBrackets.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces)}
                var parameterNames = parameters.map { $0.components(separatedBy: ":").first ?? "" }
                parameterNames.removeAll { $0.isEmpty }
                var funcNameWithoutParameters = line.components(separatedBy: " ").filter({ !$0.isEmpty }).prefix(2).last ?? ""
                funcNameWithoutParameters = funcNameWithoutParameters.components(separatedBy: "(").first ?? ""
                parameterNames = parameterNames.map { name in
                    if name.hasPrefix("_ ") {
                        var actualName = name
                        actualName.removeFirst(2)
                        return actualName
                    }
                    return name + ": " + name
                }
                variable = funcNameWithoutParameters + "(" + parameterNames.joined(separator: ", ") + ")"
            }
            var newLine = line
            newLine.removeLast(2)
            newLine += "\n\t\tinvokedList.append(.\(variable))\n\t}"
            arrayLines.remove(at: abs(index.distance(to: 0)))
            arrayLines.insert(newLine, at: abs(index.distance(to: 0)))
        }
        
        arrayLines.append(createUIElements(outletNames: variables, elementsName: "\(className)Elements"))
        updateLines(from: arrayLines)
    }
}

//
//  MockAccessibilityGenerator.swift
//  AccessibilityGenerator
//
//  Created by Aytuğ Sevgi on 15.11.2021.
//

import Foundation
import SwiftSyntax
import SwiftSemantics

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

    public static var shared : MockAccessibilityGenerator { MockAccessibilityGenerator() }

    private func updateLines(from newLines: [String]) {
        guard let lines = lines else { return }
        lines.removeAllObjects()
        lines.addObjects(from: newLines)
    }

    private func addMockAssertable(to conformableLine: String) -> String {
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

    public func conformAccessiblityIdenfiableToView() {
        guard let lines = lines,
              var arrayLines = Array(lines) as? Array<String> else { return }
        let collector = DeclarationCollector()
        do {
            let tree = try SyntaxParser.parse(source: arrayLines.joined(separator: "\n"))
            collector.walk(tree)
        } catch {
            print("SyntaxParser error")
            return
        }
        if let firstImportLine = arrayLines.first(where: { $0.contains("import") }),
           let index = arrayLines.firstIndex(of: firstImportLine),
           !collector.imports.contains(where: { $0.pathComponents.contains("UnitTestUtilsKit")}) {
            arrayLines.insert("import UnitTestUtilsKit", at: abs(index.distance(to: 0)))
        }
        guard let mockClass = collector.classes.first else { return }
        className = mockClass.name
        
        guard let classLine = arrayLines.first(where: { $0.contains("class") && $0.contains(className) }),
              let interfaceIndex = arrayLines.firstIndex(of: classLine) else { return }
        if !mockClass.inheritance.contains("MockAssertable") {
            // conform MockAssertable if not exist
            let conformedLine = addMockAssertable(to: classLine)
            arrayLines.remove(at: abs(interfaceIndex.distance(to: 0)))
            arrayLines.insert(conformedLine, at: abs(interfaceIndex.distance(to: 0)))
        }
        
        if !collector.typealiases.contains(where: { $0.name == "MockIdentifier" }) {
            arrayLines.insert("\ttypealias MockIdentifier = \(className)Elements", at: interfaceIndex + 1)
            arrayLines.insert("\tvar invokedList: [\(className)Elements] = []", at: interfaceIndex + 2)
        }
        var enumCases = [String]()
        collector.variables.forEach { variable in
            
            if !variable.name.hasPrefix("stubbed") {
                print(variable.name)
                let invokedGetter = "invoked" + variable.name.uppercasedFirst + "Getter"
                enumCases.append(invokedGetter)
                guard let index = arrayLines.firstIndex(where: { $0.contains(variable.description) }) else { return }
                
                let overrideIfNeeded = variable.modifiers.contains(where: { $0.name == "override" }) ? "override " : ""
                if variable.accessors.contains(where: { $0.kind == .set }) {
                    let invokedSetter = "invoked" + variable.name.uppercasedFirst + "Setter(value: \(variable.typeAnnotation ?? ""))"
                    enumCases.append(invokedSetter)
                    guard let index = arrayLines.firstIndex(where: { $0.contains(variable.description) }) else { return }
                    (1...6).forEach{ _ in arrayLines.remove(at: index) }
                    arrayLines.insert(
                                    """
                                        \(overrideIfNeeded)\(variable.description) {
                                            set {
                                                stubbed\(variable.name.uppercasedFirst) = newValue
                                                invokedList.append(.invoked\(variable.name.uppercasedFirst)Setter(value: newValue))
                                            }
                                            get {
                                                invokedList.append(.\(invokedGetter))
                                                return stubbed\(variable.name.uppercasedFirst)
                                            }
                                        }
                                    """,
                                    at: index)
                } else {
                    (1...3).forEach{ _ in arrayLines.remove(at: index) }
                    arrayLines.insert(
                                    """
                                        \(overrideIfNeeded)\(variable.description) {
                                            invokedList.append(.\(invokedGetter))
                                            return stubbed\(variable.name.uppercasedFirst)
                                        }
                                    """,
                                    at: index)
                }
            }
        }
        
        collector.functions.forEach { function in
            var enumCase = "invoked" + function.identifier.uppercasedFirst
            var index = 0
            while enumCases.contains(where: { $0.contains(enumCase + "(") ||  $0 == enumCase }) {
                guard index < function.signature.input.count else { break }
                enumCase += (function.signature.input[index].secondName ?? function.signature.input[index].firstName ?? "nonParam").uppercasedFirst
                index += 1
            }
            var nameWithoutParameters = enumCase
            enumCase += "("
            function.signature.input.forEach { input in
                var inputType = input.type ?? "unknown"
                if inputType.hasPrefix("@escaping") {
                    inputType.removeFirst(10)
                }
                let parameter = ((input.firstName ?? input.secondName) ?? "unknown")
                if parameter == "_" {
                    enumCase += parameter + " " + (input.secondName ?? "unknown") + ": " + inputType + ", "
                } else {
                    enumCase += parameter + ": " + inputType + ", "
                }
            }
            if enumCase.hasSuffix(", ") {
                enumCase.removeLast(2)
                enumCase += ")"
            } else {
                enumCase.removeLast()
            }
            enumCases.append(enumCase)
            guard let index = arrayLines.firstIndex(where: { $0.contains(function.description) }) else { return }
            if function.signature.output != nil {
                (1...3).forEach { _ in arrayLines.remove(at: index) }
            } else {
                arrayLines.remove(at: index)
            }
            var appendableCase = nameWithoutParameters + "("
            function.signature.input.forEach { input in
                let parameter = ((input.firstName ?? input.secondName) ?? "unknown")
                let secondParameter = ((input.secondName ?? input.firstName) ?? "unknown")
                if parameter == "_" {
                    appendableCase += secondParameter + ", "
                } else {
                    appendableCase += parameter + ": " + secondParameter + ", "
                }
            }
            if appendableCase.hasSuffix(", ") {
                appendableCase.removeLast(2)
                appendableCase += ")"
            } else {
                appendableCase.removeLast()
            }
            arrayLines.insert(
                            """
                                \(function.description) {
                                    invokedList.append(.\(appendableCase))
                                \(function.signature.output != nil ? "\treturn stubbed\(function.identifier.uppercasedFirst)Result\n\t}" : "}")
                            """,
                            at: index)
        }
        
        arrayLines.append(
                        """
                        \nenum \(className)Elements: MockEquatable {
                        \(enumCases.map { "\tcase \($0)"}.joined(separator: "\n"))
                        }
                        """)
        updateLines(from: arrayLines)
    }
}

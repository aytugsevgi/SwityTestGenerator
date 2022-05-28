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
        var tempOutlets = [String]()
        let outlets = arrayLines.filter { $0.contains("func ") || ($0.contains("var ") && !$0.contains("var stubbed") && !$0.contains("var invokedList"))}.compactMap { line -> (String)? in
            guard line.components(separatedBy: " ").count > 2,
                  let index = arrayLines.firstIndex(of: line) else { return nil }
            var separatedWords = line.components(separatedBy: " ").filter({ !$0.isEmpty })
            separatedWords.removeLast()
            separatedWords.removeFirst()
            var variable = separatedWords.joined(separator: " ")
            let firstChar = variable.removeFirst().uppercased()
            variable = "invoked\(firstChar)\(variable)"
            if line.contains("func ") {
                guard var withoutParam = variable.components(separatedBy: "(").first else { return "" }
                if let range = variable.range(of: "(") {
                    var insideOfBrackets = String(variable[range.upperBound...])
                    insideOfBrackets.removeLast()
                    let parameters = insideOfBrackets.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces)}
                    var parameterNames = parameters.map { $0.components(separatedBy: ":").first ?? "" }
                    parameterNames.removeAll { $0.isEmpty }
                    
                    var i = 0
                    
                    while tempOutlets.contains(where: {$0.contains(withoutParam + "(")} ) {
                        guard i + 1 <= parameterNames.count else { return ""}
                        if parameterNames.isEmpty {
                            withoutParam.append("NonParam()")
                            variable = withoutParam
                            break
                        } else {
                            var param = parameterNames[i]
                            param = param.trimmingCharacters(in: .whitespaces)
                            if param.contains(" ") {
                                param = param.components(separatedBy: .whitespaces).last ?? ""
                                param = param.trimmingCharacters(in: .whitespaces)
                            }
                            param.removeFirst()
                            param = (parameterNames[i].first?.uppercased() ?? "") + param
                            withoutParam.append(param)
                        }
                        variable = "\(withoutParam)(\(insideOfBrackets))"
                        i += 1
                    }
                }
            }
            if variable.hasSuffix("()") {
                variable.removeLast(2)
            } else if line.contains("func ")  {
                variable.removeLast()
                variable.append(")")
            } else if line.contains("var ") {
                variable = variable.components(separatedBy: ":").first ?? ""
                let type = variable.components(separatedBy: ":").last ?? ""
                // if var has not setter
                if arrayLines.count > index + 2, arrayLines[index + 1].contains("return stubbed") {
                    variable.append("Getter")
                } else if arrayLines.count > index + 2, arrayLines[index + 1].contains("set {}") {
                    variable.append("Getter\n\tcase \(variable)Setter(value: \(separatedWords.last ?? ""))")
                }
            }
            tempOutlets.append(variable)
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
        for var name in variables {
            if let range = name.range(of: "(") {
                var insideOfBrackets = String(name[range.upperBound...])
                insideOfBrackets.removeLast()
                
                var funcNameWithoutParameters = String(name[..<range.upperBound])
                funcNameWithoutParameters.removeLast()
                let parameters = insideOfBrackets.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces)}
                let newParameters: [String] = parameters.map {
                    let name = ($0.components(separatedBy: ":").first ?? "").trimmingCharacters(in: .whitespaces)
                    var type = ($0.components(separatedBy: ":").last ?? "").trimmingCharacters(in: .whitespaces)
  
                    if name.hasPrefix("_ ") {
                        var actualName = name
                        actualName.removeFirst(2)
                        return actualName + ": " + type
                    } else if name.contains(" ") {
                        let first = name.components(separatedBy: .whitespaces).first ?? "unknown"
                        var last = name.components(separatedBy: .whitespaces).last ?? "unknown"
                        let uppercased = last.first?.uppercased() ?? ""
                        last.removeFirst()
                        funcNameWithoutParameters += uppercased + last
                        return first + ": " + type
                    }
                    if type.hasPrefix("@escaping ") {
                        type.removeFirst(10)
                    }
                    return name + ": " + type
                }
                name = funcNameWithoutParameters + "(" + newParameters.joined(separator: ", ") + ")"
            }
            
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
            arrayLines.insert("\tvar invokedList: [\(className)Elements] = []", at: interfaceIndex + 2)
        }
        
        // add cases to array for each stub
        arrayLines.filter { $0.contains("func ") || ($0.contains("var ") && !$0.contains("var stubbed") && !$0.contains("var invokedList"))}.forEach { line in
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
            } else if let range = variable.range(of: "(") {
                variable.removeLast()
                variable.append(")")
                
                var insideOfBrackets = String(variable[range.upperBound...])
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
                    } else if name.contains(" ") {
                        let first = name.components(separatedBy: .whitespaces).first ?? "unknown"
                        let last = name.components(separatedBy: .whitespaces).last ?? "unknown"
                        
                        return first + ": " + last
                    }
                    return name + ": " + name
                }
                
                var funcNameWithoutFirstChar = funcNameWithoutParameters
                funcNameWithoutFirstChar.removeFirst()
                let firstChar = funcNameWithoutParameters.first?.uppercased() ?? ""
                var uppercasedFuncNameWithoutParameters = "invoked" + firstChar + funcNameWithoutFirstChar
                
                var content = uppercasedFuncNameWithoutParameters
                var i = 0
                while arrayLines.contains(where: { $0.contains(content + "(") }) {
                    guard i + 1 <= parameterNames.count else { return }
                    if parameterNames.isEmpty {
                        uppercasedFuncNameWithoutParameters.append("NonParam()")
                        variable = uppercasedFuncNameWithoutParameters
                        break
                    } else {
                        var param = parameterNames[i].components(separatedBy: .whitespaces).first ?? ""
                        param.removeFirst()
                        param = (parameterNames[i].first?.uppercased() ?? "") + param
                        uppercasedFuncNameWithoutParameters.append(param)
                    }
                    uppercasedFuncNameWithoutParameters.removeLast()
                    content = uppercasedFuncNameWithoutParameters
                    i += 1
                }
                
                variable = content + "(" + parameterNames.joined(separator: ", ") + ")"
            }
        
            if let _ = arrayLines.firstIndex(where: { $0.contains("invokedList.append(.\(variable))")}) {
                return
            }
            var newLine = line
            if line.contains("func ") {
                newLine.removeLast(2)
                newLine += "\n\t\tinvokedList.append(.\(variable))\n\t}"
                arrayLines.remove(at: abs(index.distance(to: 0)))
                arrayLines.insert(newLine, at: abs(index.distance(to: 0)))
            } else if line.contains("var ") {
                let actualVariable = variable.trimmingCharacters(in: .whitespacesAndNewlines)
            
                guard var variable = actualVariable.components(separatedBy: ":").first,
                      var type =  actualVariable.components(separatedBy: ":").last else { return }
                type.removeLast()
                var withUppercasedVariable = variable
                withUppercasedVariable.removeFirst()
                let firstChar = variable.first?.uppercased() ?? ""
                var withoutInvokedPrefix = withUppercasedVariable
                withoutInvokedPrefix.removeFirst(7)
                
                var withUppercasedVariableStubbed = variable
                withUppercasedVariableStubbed.removeFirst(7)

                
                let withUppercasedVariableInvoked = firstChar + withUppercasedVariable
                withUppercasedVariableStubbed = "stubbed" + withUppercasedVariableStubbed
                // if var has not setter
                if arrayLines.count > index + 2, arrayLines[index + 1].contains("return stubbed") {
                    newLine += "\t\tinvokedList.append(.\(variable)Getter)\n\t\treturn \(withUppercasedVariableStubbed)\n\t}"
                    (1...3).forEach{ _ in arrayLines.remove(at: index) }
                    arrayLines.insert(newLine, at: abs(index.distance(to: 0)))
                } else if arrayLines.count > index + 2, arrayLines[index + 1].contains("set {}") {
                    newLine.removeLast()
                    newLine += "\n\t\tset {\n\t\t\tinvokedList.append(.\(variable)Setter(value: newValue))\n\t\t}\n\t\tget {\n\t\t\tinvokedList.append(.\(variable)Getter)\n\t\t\treturn \(withUppercasedVariableStubbed)\n\t\t}\n\t}"
                    (1...7).forEach{ _ in arrayLines.remove(at: index) }
                    arrayLines.insert(newLine, at: abs(index.distance(to: 0) + 1))
                }
//
//                arrayLines.insert(newLine, at: abs(index.distance(to: 0)))
            }
            
        }
        if let index = arrayLines.firstIndex(where: { $0.contains("enum \(className)Elements: MockEquatable")}) {
            arrayLines = Array(arrayLines[0..<abs(index.distance(to: 0))])
        }
        arrayLines.append(createUIElements(outletNames: variables, elementsName: "\(className)Elements"))
        updateLines(from: arrayLines)
    }
}

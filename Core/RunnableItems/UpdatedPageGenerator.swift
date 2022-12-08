//
//  UpdatedPageGenerator.swift
//  Swity
//
//  Created by Atakan Karslı on 05/12/2022.
//

import Foundation

public final class UpdatedPageGenerator: Runnable {
    public func isSatisfied(identifier: String) -> Bool {
        identifier == "updated"
    }

    private enum ViewType {
        case view
        case viewController
        case cell
    }

    public func execute(lines: NSMutableArray?) {
        self.lines = lines
        generateUIElementClass()
    }

    public var lines: NSMutableArray?
    private var className: String = .init().replacingOccurrences(of: "Elements", with: "")
    private var viewType: ViewType {
        if className.suffix(5).contains("Cell") {
            return .cell
        } else if className.suffix(15).contains("ViewController") {
            return .viewController
        }
        return .view
    }

    private lazy var outletNames: [String.SubSequence] = {
        outlets.compactMap { $0.name }
    }()

    private lazy var outletTypes: [String.SubSequence] = {
        outlets.compactMap { $0.type }
    }()

    private lazy var outlets: [(name: String.SubSequence, type: String.SubSequence)] = {
        guard let lines = lines,
              var arrayLines = Array(lines) as? Array<String> else { return .init() }
        let outlets = arrayLines.filter { $0.contains(".rawValue") }.compactMap { line -> (String.SubSequence, String.SubSequence)? in
            guard let outlet = line.split(separator: "[").first(where: { $0.hasSuffix("]") })?.dropFirst().split(separator: ".").last,
                  let type = line.split(separator: ".").first(where: { $0.hasSuffix("[") })?.dropLast()
            else { return nil }
            return (outlet, type)
        }
        return outlets
    }()

    public static var shared : UpdatedPageGenerator { UpdatedPageGenerator() }

    private func updateLines(from newLines: [String]) {
        guard let lines = lines else { return }
        lines.removeAllObjects()
        lines.addObjects(from: newLines)
    }

    private func addAccessibilityIdetifiable(to conformableLine: String) -> String {
        var conformableLineWords = conformableLine.split(separator: " ")
        var needComma = false
        let isHasAnyConform = conformableLineWords.count > 3
        if isHasAnyConform && conformableLineWords.contains("AnyObject") {
            conformableLineWords.removeAll { $0 == "AnyObject" }

        } else if isHasAnyConform && conformableLineWords.contains("AnyObject,") {
            conformableLineWords.removeAll { $0 == "AnyObject," }
            needComma = true
        }

        else if !isHasAnyConform {
            conformableLineWords[1].append(":")
        } else {
            conformableLineWords[conformableLineWords.count - 2].append(",")
        }
        if needComma {
            conformableLineWords[conformableLineWords.count - 2].append(",")
        }
        conformableLineWords.insert("AccessibilityIdentifiable", at: conformableLineWords.count - 1 )
        return conformableLineWords.joined(separator: " ")
    }

    private func createUIElements(outletNames: [String.SubSequence?], elementsName: String, isCell: Bool, cellName: String) -> String {
        var elementExtension = "public extension UIElements {\n"
        elementExtension.append("\tenum \(elementsName): String, UIElement {\n")
        elementExtension.append("\t\t// MARK: - \(className)\n")
        for (name, type) in outlets {
            elementExtension.append("\t\tcase \(name)\n")
            if type == "UISearchBar" {
                elementExtension.append("\t\tcase searchTextField\n")
            }
        }
        if isCell {
            elementExtension.append("\t\tcase \(cellName)\n")
        }
        elementExtension.append("\t}\n}")
        return elementExtension
    }

    @discardableResult
    private func generateUIElementPage() -> Self? {
        guard let lines = lines,
              var arrayLines = Array(lines) as? Array<String>,
              !outlets.isEmpty else { return nil }
        arrayLines.append("\nimport XCTest\n")
        arrayLines.append("import AccessibilityKit\n")
        arrayLines.append("import UITestBaseKit\n\n")
        let classWithoutSuffix = className.replacingOccurrences(of: "ViewController", with: "")
        arrayLines.append("public final class \(classWithoutSuffix)Page: UIElementPage<UIElements.\(className)Elements> {\n")
        arrayLines.append("\t// MARK: - \(className)")
        outlets.forEach { (name, type) in
            arrayLines.append("\tlazy var \(name) = \(type)(.\(name))\n")
        }
        arrayLines.append("\n\tpublic required init() {\n")
        arrayLines.append("\t\tsuper.init()\n")
        arrayLines.append("\t\tcheck()\n")
        arrayLines.append("\t}\n\n")

        arrayLines.append("\t@discardableResult\n")
        arrayLines.append("\tpublic func check() -> Self {\n")
        for (index, name) in outletNames.enumerated() {
            if index == .zero {
                arrayLines.append("\t\twaitForPage(elements: [[\(name): .exist\(outletNames.count == 1 ? "]])\n" : ", ")")
            } else if index == outletNames.count - 1 {
                arrayLines.append("\t\t                        \(name): .exist]])\n")
            } else {
                arrayLines.append("\t\t                        \(name): .exist, ")
            }
        }
        arrayLines.append("\t\treturn self\n\t}\n")
        outlets.forEach { (name, type) in
            if type == "buttons" {
                arrayLines.append("\n")
                var name = String(name)
                name.uppercaseFirst()
                arrayLines.append("\t@discardableResult\n")
                arrayLines.append("\tpublic func tap\(name)() -> Self {\n")
                name.lowercaseFirst()
                arrayLines.append("\t\texpect(element: \(name), status: .exist).tap()\n")
                arrayLines.append("\t\treturn self\n\t}\n")
            }
        }
        arrayLines.append("}")
        updateLines(from: arrayLines)
        return self
    }

    @discardableResult
    private func generateUIElementCell() -> Self? {
        guard let lines = lines,
              var arrayLines = Array(lines) as? Array<String>,
              !outlets.isEmpty else { return nil }
        arrayLines.append("\nimport XCTest\n")
        arrayLines.append("import AccessibilityKit\n")
        arrayLines.append("import UITestBaseKit\n\n")
        arrayLines.append("public protocol \(className)Elements where Self: Page {\n")

        let hasClassPrefix = !className.prefix(3).contains { $0.isLowercase }
        var mutableClassName = className
        if hasClassPrefix {
            mutableClassName.forEach { _ in
                let isUppercasedFirstTwoChars = !mutableClassName.prefix(2).contains { $0.isLowercase }
                guard isUppercasedFirstTwoChars else { return }
                mutableClassName.removeFirst()
            }
        }
        mutableClassName.lowercaseFirst()
        arrayLines.append("\tfunc \(mutableClassName)(at index: Int) -> XCUIElement\n")
        outlets.forEach { (name, type) in
            var mutableElementName = String(name)
            mutableElementName.uppercaseFirst()
            arrayLines.append("\tfunc \(mutableClassName)\(mutableElementName)(at index: Int) -> XCUIElement\n")
        }
        mutableClassName.lowercaseFirst()
        arrayLines.append("\tfunc \(mutableClassName)Elements(at index: Int, status: UIStatus) -> [XCUIElement : UIStatus]\n")
        mutableClassName.uppercaseFirst()
        arrayLines.append("\tfunc check\(mutableClassName)(at index: Int, status: UIStatus) -> Self\n")
        arrayLines.append("}\n\n")

        arrayLines.append("public extension \(className)Elements {\n")
        mutableClassName.lowercaseFirst()
        arrayLines.append("\tfunc \(mutableClassName)(at index: Int) -> XCUIElement {\n")
        arrayLines.append("\t\tapp.cells[String(format: UIElements.\(className)Elements.\(mutableClassName).rawValue + \"_%d\", index)].firstMatch\n\t}\n\n")
        outlets.forEach { (name, type) in
            var mutableElementName = String(name)
            mutableElementName.uppercaseFirst()
            arrayLines.append("\tfunc \(mutableClassName)\(mutableElementName)(at index: Int = 0) -> XCUIElement {\n")
            arrayLines.append("\t\t\(mutableClassName)(at: index).\(type)[UIElements.\(className)Elements.\(name).rawValue]\n\t}\n\n")
        }
        arrayLines.append("\t@discardableResult\n")
        mutableClassName.lowercaseFirst()
        arrayLines.append("\tfunc \(mutableClassName)Elements(at index: Int = 0, status: UIStatus = .exist) -> [XCUIElement : UIStatus] {\n")
        for (index, name) in outletNames.enumerated() {
            var mutableElementName = String(name)
            mutableElementName.uppercaseFirst()
            if index == .zero {
                let suffix = outletNames.count > 1 ? ", " : "]\n\t}\n\n"
                arrayLines.append("\t\t[\(mutableClassName)\(mutableElementName)(at: index): status\(suffix)")
            } else if index == outletNames.count - 1 {
                arrayLines.append("\t\t \(mutableClassName)\(mutableElementName)(at: index): status]\n\t}\n\n")
            } else {
                arrayLines.append("\t\t \(mutableClassName)\(mutableElementName)(at: index): status,")
            }
        }
        arrayLines.append("\t@discardableResult\n")
        mutableClassName.uppercaseFirst()
        arrayLines.append("\tfunc check\(mutableClassName)(at index: Int = 0, status: UIStatus = .exist) -> Self {\n")
        mutableClassName.lowercaseFirst()
        arrayLines.append("\t\twaitForElements(elements: \(mutableClassName)Elements(at: index, status: status))\n")
        arrayLines.append("\t\treturn self\n\t}\n\n")

        mutableClassName.uppercaseFirst()
        arrayLines.append("\t@discardableResult\n")
        arrayLines.append("\tfunc tap\(mutableClassName)(at index: Int) -> Self {\n")

        mutableClassName.lowercaseFirst()
        arrayLines.append("\t\texpect(element: \(mutableClassName)(at: index), status: .exist).tap()\n")
        arrayLines.append("\t\treturn self\n\t}\n")

        outlets.forEach { (name, type) in
            let elementType = UIElementType.init(rawValue: String(type)) ?? .otherElement
            if elementType == .button {
                arrayLines.append("\n")
                var name = String(name)
                name.uppercaseFirst()
                arrayLines.append("\t@discardableResult\n")
                arrayLines.append("\tfunc tap\(name)(at index: Int) -> Self {\n")
                arrayLines.append("\t\texpect(element: \(mutableClassName)\(name)(at: index), status: .exist).tap()\n")
                arrayLines.append("\t\treturn self\n\t}\n")
            }
        }
        arrayLines.append("}")
        updateLines(from: arrayLines)
        return self
    }

    @discardableResult
    private func generateUIElementView() -> Self? {
        guard let lines = lines,
              var arrayLines = Array(lines) as? Array<String>,
              !outlets.isEmpty else { return nil }
        arrayLines.append("\nimport XCTest\n")
        arrayLines.append("import AccessibilityKit\n")
        arrayLines.append("import UITestBaseKit\n\n")
        arrayLines.append("public protocol \(className)Elements where Self: Page {\n")

        let hasClassPrefix = !className.prefix(3).contains { $0.isLowercase }
        var mutableClassName = className
        if hasClassPrefix {
            mutableClassName.forEach { _ in
                let isUppercasedFirstTwoChars = !mutableClassName.prefix(2).contains { $0.isLowercase }
                guard isUppercasedFirstTwoChars else { return }
                mutableClassName.removeFirst()
            }
        }
        //arrayLines.append("\tfunc \(mutableClassName)(_ baseElement: XCUIElement, at index: Int) -> XCUIElement\n")
        outlets.forEach { (name, type) in
            var mutableElementName = String(name)
            mutableElementName.uppercaseFirst()
            mutableClassName.lowercaseFirst()
            arrayLines.append("\tvar \(mutableClassName)\(mutableElementName): XCUIElement { get }\n")
        }
        mutableClassName.lowercaseFirst()
        arrayLines.append("\n\tfunc \(mutableClassName)Elements(status: UIStatus) -> [XCUIElement : UIStatus]\n")
        mutableClassName.uppercaseFirst()
        arrayLines.append("\tfunc check\(mutableClassName)(status: UIStatus) -> Self\n")
        arrayLines.append("}\n\n")

        arrayLines.append("public extension \(className)Elements {\n")
        outlets.forEach { (name, type) in
            var mutableElementName = String(name)
            mutableElementName.uppercaseFirst()
            mutableClassName.lowercaseFirst()
            arrayLines.append("\tvar \(mutableClassName)\(mutableElementName): XCUIElement { ")
            arrayLines.append("\t\tapp.\(type)[UIElements.\(className)Elements.\(name).rawValue]\n\t}\n")
        }
        arrayLines.append("\n\t@discardableResult\n")
        mutableClassName.lowercaseFirst()
        arrayLines.append("\tfunc \(mutableClassName)Elements(status: UIStatus = .exist) -> [XCUIElement : UIStatus] {\n")
        for (index, name) in outletNames.enumerated() {
            var mutableElementName = String(name)
            mutableElementName.uppercaseFirst()
            if index == .zero {
                let suffix = outletNames.count > 1 ? ", " : "]\n\t}\n\n"
                arrayLines.append("\t\t[\(mutableClassName)\(mutableElementName): status\(suffix)")
            } else if index == outletNames.count - 1 {
                arrayLines.append("\t\t \(mutableClassName)\(mutableElementName): status]\n\t}\n\n")
            } else {
                arrayLines.append("\t\t \(mutableClassName)\(mutableElementName): status,")
            }
        }
        arrayLines.append("\t@discardableResult\n")
        mutableClassName.uppercaseFirst()
        arrayLines.append("\tfunc check\(mutableClassName)(status: UIStatus = .exist) -> Self {\n")
        mutableClassName.lowercaseFirst()
        arrayLines.append("\t\twaitForElements(elements: \(mutableClassName)Elements(status: status))\n")
        arrayLines.append("\t\treturn self\n\t}\n")
        mutableClassName.uppercaseFirst()
        outlets.forEach { (name, type) in
            if type == "buttons" {
                arrayLines.append("\n")
                var name = String(name)
                name.uppercaseFirst()
                arrayLines.append("\t@discardableResult\n")
                arrayLines.append("\tpublic func tap\(mutableClassName)\(name)() -> Self {\n")
                arrayLines.append("\t\texpect(element: \(mutableClassName)\(name), status: .exist).tap()\n")
                arrayLines.append("\t\treturn self\n\t}\n")
            }
        }
        arrayLines.append("}")
        updateLines(from: arrayLines)
        return self
    }

    @discardableResult
    private func generateUIElementClass() -> Self? {
        if viewType == .cell {
            return generateUIElementCell()
        } else if viewType == .viewController {
            return generateUIElementPage()
        }
        return generateUIElementView()
    }

    private enum UIElementType: String {
        case button = "UIButton"
        case image = "UIImageView"
        case textField = "UITextField"
        case textView = "UITextView"
        case staticText = "UILabel"
        case collection = "UICollectionView"
        case table = "UITableView"
        case scrollView = "UIScrollView"
        case switches = "UISwitch"
        case otherElement
    }
}

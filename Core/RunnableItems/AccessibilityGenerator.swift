//
//  AccessibilityGeneratorManager.swift
//  AccessibilityGenerator
//
//  Created by Aytuğ Sevgi on 16.09.2021.
//

import Foundation

public final class AccessibilityGenerator: Runnable {
    public func isSatisfied(identifier: String) -> Bool {
        identifier == "fordev"
    }

    public func execute(lines: NSMutableArray?) {
        self.lines = lines
        conformAccessiblityIdenfiableToView()?.conformUITestablePageToView()?.generateUIElementClass()
    }

    public var lines: NSMutableArray?
    private var className: String = .init()
    private var elementType: String?
    private var isCellView: Bool {
        className.suffix(5).contains("Cell")
    }

    private var isAlreadySet = false

    private lazy var outletNames: [String.SubSequence] = {
        outlets.compactMap { $0.name }
    }()

    private lazy var outletTypes: [String.SubSequence] = {
        outlets.compactMap { $0.type }
    }()

    private lazy var outlets: [(name: String.SubSequence, type: String.SubSequence)] = {
        guard let lines = lines,
              var arrayLines = Array(lines) as? Array<String> else { return .init() }
        let outlets = arrayLines.filter { $0.contains("@IBOutlet") }.compactMap { line -> (String.SubSequence, String.SubSequence)? in
            guard let outlet = line.split(separator: " ").first(where: { $0.last == ":" })?.dropLast(),
                  let type = line.split(separator: " ").last?.dropLast(2),
                  type != "NSLayoutConstraint" else { return nil }
            return (outlet, type)
        }
        return outlets
    }()

    public static var shared : UITestablePageGenerator { UITestablePageGenerator() }

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
        var elementExtension = "\npublic extension UIElements {\n"
        elementExtension.append("\tenum \(elementsName): String, UIElement {\n")
        elementExtension.append("\t\t// MARK: - \(className)\n")
        for (name, type) in outlets {
            elementExtension.append("\t\tcase \(name)\n")
            if type == "UISearchBar" {
                elementExtension.append("\t\tcase searchTextField\n")
            }
        }
        if isCell, !isAlreadySet {
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
        arrayLines.append("import AccessibilityKit\n\n")
        let classWithoutSuffix = className.replacingOccurrences(of: "ViewController", with: "")
        arrayLines.append("final class \(classWithoutSuffix)Page: UIElementPage<UIElements.\(elementType ?? .init())> {\n")
        arrayLines.append("\t// MARK: - \(className)")
        outlets.forEach { (name, type) in
            let elementType = UIElementType.init(rawValue: String(type)) ?? .otherElement
            arrayLines.append("\tlazy var \(name) = \(elementType)(.\(name))\n")
        }
        arrayLines.append("\n\trequired init() {\n")
        arrayLines.append("\t\tsuper.init()\n")
        arrayLines.append("\t\tcheck()\n")
        arrayLines.append("\t}\n\n")

        arrayLines.append("\t@discardableResult\n")
        arrayLines.append("\tfunc check() -> Self {\n")
        for (index, name) in outletNames.enumerated() {
            if index == .zero {
                arrayLines.append("\t\twaitForElements(elements: [\(name): .exist\(outletNames.count == 1 ? "])\n" : ", ")")
            } else if index == outletNames.count - 1 {
                arrayLines.append("\t\t                           \(name): .exist])\n")
            } else {
                arrayLines.append("\t\t                           \(name): .exist, ")
            }
        }
        arrayLines.append("\t\treturn self\n\t}\n}")
        updateLines(from: arrayLines)
        return self
    }

    @discardableResult
    private func generateUIElementCell() -> Self? {
        guard let lines = lines,
              var arrayLines = Array(lines) as? Array<String>,
              !outlets.isEmpty else { return nil }
        arrayLines.append("\nimport XCTest\n")
        arrayLines.append("import AccessibilityKit\n\n")
        arrayLines.append("protocol \(className)Elements where Self: Page {\n")

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
        if !isAlreadySet {
            arrayLines.append("\tfunc \(mutableClassName)(at index: Int) -> XCUIElement\n")
        }
        outlets.forEach { (name, type) in
            var mutableElementName = String(name)
            mutableElementName.uppercaseFirst()
            arrayLines.append("\tfunc \(mutableClassName)\(mutableElementName)(at index: Int) -> XCUIElement\n")
        }
        mutableClassName.uppercaseFirst()
        arrayLines.append("\tfunc check\(mutableClassName)(at index: Int) -> Self\n")
        arrayLines.append("}\n\n")

        arrayLines.append("extension \(className)Elements {\n")
        mutableClassName.lowercaseFirst()
        if !isAlreadySet {
            arrayLines.append("\tfunc \(mutableClassName)(at index: Int) -> XCUIElement {\n")
            arrayLines.append("\t\tapp.cells[String(format: UIElements.\(className)Elements.\(mutableClassName).rawValue + \"_%d\", index)].firstMatch\n\t}\n\n")
            // for nested cell
            arrayLines.append("\tfunc \(mutableClassName)(_ baseElement: XCUIElement, at index: Int) -> XCUIElement {\n")
            arrayLines.append("\t\tbaseElement.cells[String(format: UIElements.\(className)Elements.\(mutableClassName).rawValue + \"_%d\", index)].firstMatch\n\t}\n\n")
        }
        outlets.forEach { (name, type) in
            var mutableElementName = String(name)
            mutableElementName.uppercaseFirst()
            arrayLines.append("\tfunc \(mutableClassName)\(mutableElementName)(at index: Int = 0) -> XCUIElement {\n")
            let elementType = UIElementType.init(rawValue: String(type)) ?? .otherElement
            arrayLines.append("\t\t\(mutableClassName)(at: index).\(elementType == .collection ? "collectionView" : "\(elementType)")\(elementType == .switches ? "" : "s")[UIElements.\(className)Elements.\(name).rawValue]\n\t}\n\n")
        }
        arrayLines.append("\t@discardableResult\n")
        mutableClassName.uppercaseFirst()
        arrayLines.append("\tfunc check\(mutableClassName)(at index: Int = 0) -> Self {\n")
        mutableClassName.lowercaseFirst()
        for (index, name) in outletNames.enumerated() {
            var mutableElementName = String(name)
            mutableElementName.uppercaseFirst()
            if index == .zero {
                let suffix = outletNames.count > 1 ? ", " : "])\n"
                arrayLines.append("\t\twaitForElements(elements: [\(mutableClassName)\(mutableElementName)(at: index): .exist\(suffix)")
            } else if index == outletNames.count - 1 {
                arrayLines.append("\t\t                           \(mutableClassName)\(mutableElementName)(at: index): .exist])\n")
            } else {
                arrayLines.append("\t\t                           \(mutableClassName)\(mutableElementName)(at: index): .exist,")
            }
        }
        arrayLines.append("\t\treturn self\n\t}\n}")
        updateLines(from: arrayLines)
        return self
    }

    @discardableResult
    private func conformAccessiblityIdenfiableToView() -> Self? {
        guard let lines = lines,
              var arrayLines = Array(lines) as? Array<String> else { return nil }
        if let firstImportLine = arrayLines.first(where: { $0.contains("import") }),
           let index = arrayLines.firstIndex(of: firstImportLine),
           !arrayLines.contains(where: {$0.contains("import AccessibilityKit")}) {
            arrayLines.insert("import AccessibilityKit", at: abs(index.distance(to: 0)))
        }
        guard let classLine = arrayLines.first(where: { $0.contains("class") && $0.contains(":") }) else { return nil }
        let classLineWords = classLine.split(separator: " ")
        guard let classIndex = classLineWords.firstIndex(of: "class") else { return nil }
        className = String(classLineWords[classIndex + 1])

        className.removeAll { $0 == ":"}
        let interfaceName = className.replacingOccurrences(of: "Controller", with: "")
        //MARK: - Protocol conform AccessibilityIdentifiable
        if let interfaceLine = arrayLines.first(where: { $0.contains("protocol \(interfaceName)") }) {
            if !interfaceLine.contains("AccessibilityIdentifiable") {
                let conformedLine = addAccessibilityIdetifiable(to: interfaceLine)
                guard let interfaceIndex = arrayLines.firstIndex(of: interfaceLine) else { return nil }
                arrayLines.remove(at: abs(interfaceIndex.distance(to: 0)))
                arrayLines.insert(conformedLine, at: abs(interfaceIndex.distance(to: 0)))
            }
        } else if !classLine.contains("AccessibilityIdentifiable") {
            let conformedLine = addAccessibilityIdetifiable(to: classLine)
            guard let interfaceIndex = arrayLines.firstIndex(of: classLine) else { return nil }
            arrayLines.remove(at: abs(interfaceIndex.distance(to: 0)))
            arrayLines.insert(conformedLine, at: abs(interfaceIndex.distance(to: 0)))
        }
        updateLines(from: arrayLines)
        return self
    }

    @discardableResult
    private func conformUITestablePageToView() -> Self? {
        guard let lines = lines,
              var arrayLines = Array(lines) as? Array<String>,
              !outlets.isEmpty else { return nil }
        let index = arrayLines.firstIndex(where: { $0.contains("func setAccessibilityIdentifiers()") })
        isAlreadySet = index != nil
        if !isAlreadySet {
            elementType = "\(className)Elements"
            arrayLines.append("\n// MARK: - UITestable\nextension \(className): UITestablePage {\n")
            arrayLines.append("\ttypealias UIElementType = UIElements.\(elementType ?? .init())\n\n")
            arrayLines.append("\tfunc setAccessibilityIdentifiers() {\n")
        } else {
            let line = arrayLines.first(where: { $0.contains("typealias UIElementType = UIElements.")})
            elementType = line?.components(separatedBy: "UIElements.").last
            elementType?.removeAll(where: { $0 == "\n" })
        }
        // TODO
        for (name, outletType) in outlets {
            if let index = index, arrayLines.firstIndex(where: { $0.contains("makeViewTestable(\(name),") }) == nil {
                arrayLines.insert("\t\tmakeViewTestable(\(name), using: .\(name))\n", at: index + 1)
                if outletType == "UISearchBar" {
                    arrayLines.insert("\t\tmakeViewTestable(\(name).textfield, using: .searchTextField)\n", at: index + 1)
                }
            } else if let _ = index {
                outlets.removeAll(where: { $0.name == name })
            } else {
                arrayLines.append("\t\tmakeViewTestable(\(name), using: .\(name))\n")
                if outletType == "UISearchBar" {
                    arrayLines.append("\t\tmakeViewTestable(\(name).textfield, using: .searchTextField)\n")
                }
            }
        }
        if index == nil {
            arrayLines.append("\t}\n")
        }
        var cellName = className
        if isCellView {
            var firstChar = ""
            for char in cellName {
                if char.isLowercase {
                    break
                }
                firstChar = String(cellName.removeFirst())
            }
            cellName = firstChar.lowercased() + cellName
            if !isAlreadySet {
                arrayLines.append("\n\tfunc setAccessibilityIdentifiers(at index: Int) {\n")
                arrayLines.append("\t\tmakeViewTestable(self, using: .\(cellName), index: index)\n")
                arrayLines.append("\t}\n")
            }
        }
        if !isAlreadySet{
            arrayLines.append("}\n")
        }
        if !outletNames.isEmpty {
            arrayLines.append(createUIElements(outletNames: outletNames, elementsName: elementType ?? "\(className)Elements", isCell: isCellView, cellName: cellName))
        }
        updateLines(from: arrayLines)
        return self
    }

    @discardableResult
    private func generateUIElementClass() -> Self? {
        isCellView ? generateUIElementCell() : generateUIElementPage()
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

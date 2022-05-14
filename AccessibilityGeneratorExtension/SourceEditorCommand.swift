//
//  SourceEditorCommand.swift
//  AccessibilityGeneratorExtension
//
//  Created by Aytuğ Sevgi on 5.07.2021.
//

import Foundation
import XcodeKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        let manager = AccessibilityGenerator.shared
        manager.lines = invocation.buffer.lines
        RunnableEngine.shared.generate(identifier: invocation.commandIdentifier, lines: invocation.buffer.lines)
        completionHandler(nil)
    }
}

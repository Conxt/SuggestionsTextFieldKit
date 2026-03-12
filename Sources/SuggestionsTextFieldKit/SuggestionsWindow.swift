//
//  SuggestionsWindow.swift
//
//
//  Created by Claudio Cambra on 2/4/24.
//

import AppKit
import Foundation

// Thanks to CustomMenus example from Apple

class SuggestionsWindow: NSWindow {
    var parentElement: Any?

    convenience init(contentRect: NSRect, defer flag: Bool) {
        self.init(contentRect: contentRect, styleMask: .borderless, backing: .buffered, defer: flag)
    }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: flag
        )

        hasShadow = false
        backgroundColor = NSColor.clear
        isOpaque = false
    }

    /*
    This window is acting as a popup menu of sorts.  Since this isn't semantically a window,
    we ignore it for accessibility purposes.  Similarly, the parent of this window is its
    logical parent in the parent window.  In this code sample, the text field, but essentially any
    UI element that is the logical 'parent' of the window.
    */

    override func accessibilityIsIgnored() -> Bool { true }

    override func accessibilityParent() -> Any? {
        (parentElement != nil) ? NSAccessibility.unignoredAncestor(of: parentElement!): nil
    }
}

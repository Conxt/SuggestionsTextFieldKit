//
//  SuggestionsWindowContentView.swift
//  
//
//  Created by Claudio Cambra on 2/4/24.
//

import AppKit
import Foundation

class SuggestionsWindowContentView: NSView {
    var cornerRadius: CGFloat = 6.0

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true

        let visualEffectView = NSVisualEffectView()
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .menu
        visualEffectView.state = .active

        addSubview(visualEffectView)
        addConstraints([
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius).fill()
    }

    override var isFlipped: Bool {
        return true
    }

    // MARK: - Accessibility

    /*
        This view contains the list of selections.  It should be exposed to accessibility, and
        should report itself with the role 'AXList'.  Because this is an NSView subclass, most
        of the basic accessibility behavior (accessibility parent, children, size, position,
        window, and more) is inherited from NSView.  Note that even the role description attribute
        will update accordingly and its behavior does not need to be overridden.  However, since
        the role AXList has a number of additional required attributes, we need to declare them
        and implement them.
     */

    // Make sure we are reported by accessibility.  NSView's default return value is YES.

    override func accessibilityIsIgnored() -> Bool { false }

    override func accessibilityOrientation() -> NSAccessibilityOrientation { .vertical }

    override func isAccessibilityEnabled() -> Bool { true }

    override func accessibilityVisibleChildren() -> [Any]? { accessibilityChildren() }

    override func accessibilityChildren() -> [Any]? {
        var result = [Any]()
        for child in self.subviews {
            guard let child = child as? SuggestionView else { continue }
            result.append(child)
        }
        return result
    }

    override func accessibilitySelectedChildren() -> [Any]? {
        guard let accessibilityChildren = accessibilityChildren() else { return [] }
        var selectedChildren = [AnyHashable]()
        for element: Any in accessibilityChildren {
            guard let control = element as? SuggestionView, control.highlighted else { continue }
            selectedChildren.append(control)
        }
        return selectedChildren
    }
}

//
//  SuggestionsWindowController.swift
//
//
//  Created by Claudio Cambra on 2/4/24.
//

import AppKit
import Foundation
import OSLog

// Thanks to John Brayton and his custom menus implementation

public class SuggestionsWindowController: NSWindowController {
    public var parentTextField: NSTextField? = nil
    public var dataSource: SuggestionsDataSource? = nil {
        didSet {
            if let observer = dataSourceObserver {
                NotificationCenter.default.removeObserver(observer)
                dataSourceObserver = nil
            }
            guard let dataSource = dataSource else { return }
            dataSourceObserver = NotificationCenter.default.addObserver(
                forName: SuggestionsChangedNotificationName,
                object: dataSource,
                queue: OperationQueue.current,
                using: { [weak self] _ in self?.layoutSuggestions() }
            )
            if window?.isVisible == true {
                layoutSuggestions()
            }
        }
    }
    private var dataSourceObserver: Any?

    // What to do when choice is made
    public var selectionHandler: (@Sendable (Suggestion?) -> ())?
    public var selectionColor: NSColor = .controlAccentColor
    public var selectedSuggestion: Suggestion? {
        for viewController in viewControllers where selectedView == viewController.view {
            return viewController.representedObject as? Suggestion
        }
        return nil
    }
    public var confirmationHandler: (@Sendable (Suggestion?) -> ())?

    public var maxWindowHeight: CGFloat = 160

    private let kTrackerKey = "whichImageView"

    private(set) var viewControllers: [NSViewController] = []
    private var trackingAreas: [NSTrackingArea] = []
    private var localMouseDownEventMonitor: Any?
    private var lostFocusObserver: Any?
    private var rowsView: NSView?

    private var selectedView: SuggestionView? {
        didSet {
            selectedView?.selectionColor = selectionColor
            oldValue?.highlighted = false
            selectedView?.highlighted = true
            if let cell = self.parentTextField?.cell {
                NSAccessibility.post(element: cell, notification: .selectedChildrenChanged)
            }
        }
    }

    public init() {
        super.init(window:
            SuggestionsWindow(contentRect: .init(origin: .zero, size: .zero), defer: true)
        )
        self.window?.isReleasedWhenClosed = false

        let contentView = SuggestionsWindowContentView()
        self.window?.contentView = contentView

        let scrollView = LTRScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        let rowsView = FlippedView()
        scrollView.documentView = rowsView
        self.rowsView = rowsView
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Mouse handling

    // The mouse is now over one of our child image views. Update selection and send action.
    public override func mouseEntered(with event: NSEvent) {
        let view: NSView?
        if let userData = event.trackingArea?.userInfo as? [String: NSView] {
            view = userData[kTrackerKey]!
        } else {
            view = nil
        }
        userSetSelectedView(view)
    }

    // The mouse has left one of our child image views.
    // Set the selection to no selection and send action.
    public override func mouseExited(with event: NSEvent) {
        userSetSelectedView(nil)
    }

    // The user released the mouse button. Force the parent text field to send its return action.
    // Notice that there is no mouseDown: implementation. That is because the user may hold the
    // mouse down and drag into another view.
    public override func mouseUp(with theEvent: NSEvent) {
        confirmationHandler?(selectedSuggestion)
        cancelSuggestions()
    }

    public override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        guard let contentView = self.window?.contentView as? SuggestionsWindowContentView else {
            userSetSelectedView(nil)
            return
        }

        let viewPoint = contentView.convert(event.locationInWindow, from: contentView)
        guard viewPoint.x >= contentView.bounds.origin.x,
              viewPoint.x <= contentView.bounds.origin.x + contentView.bounds.size.width
        else {
            userSetSelectedView(nil)
            return
        }

        let subviews = contentView.subviews
        let y = contentView.frame.size.height - viewPoint.y
        for subview in subviews {
            let frame = subview.frame
            guard let subview =  subview as? SuggestionView,
                  frame.origin.y <= y,
                  frame.origin.y + frame.size.height >= y
            else { continue }
            userSetSelectedView(subview)
            return
        }
        userSetSelectedView(nil)
    }

    // MARK: - Keyboard Tracking

    /*
    In addition to tracking the mouse, we want to allow changing our selection via the keyboard.
    However, the suggestion window never gets key focus as the key focus remains on te text field.
    Therefore we need to route move up and move down action commands from the text field and
    this controller. See CustomMenuAppDelegate.m -control:textView:doCommandBySelector: to see how
    that is done.
    */

    // Move the selection up and send action.

    public override func moveUp(_ sender: Any?) {
        var previousView: NSView? = nil
        var viewWasSelected = false

        for viewController in viewControllers {
            let view = viewController.view
            if view == selectedView {
                viewWasSelected = true
                break
            }
            previousView = view
        }
        if viewWasSelected { userSetSelectedView(previousView) }
    }

    // Move the selection down and send action.
    public override func moveDown(_ sender: Any?) {
        var previousView: NSView? = nil
        for viewController in viewControllers.reversed() {
            let view = viewController.view
            if view == selectedView { break }
            previousView = view
        }
        if previousView != nil {
            userSetSelectedView(previousView)
        }
    }

    private func userSetSelectedView(_ view: NSView?) {
        selectedView = view as? SuggestionView
//        selectedView?.selectionColor = selectionColor
        if let selectedView, let rowsView {
            let rect = rowsView.convert(selectedView.bounds, from: selectedView)
            rowsView.scrollToVisible(rect)
        }
        if let handler = selectionHandler { handler(selectedSuggestion) }
    }

    // MARK: - Handling of window relative to textfield

    public func enableSuggestions() {
        repositionWindow()

        guard let suggestionsWindow = self.window as? SuggestionsWindow,
              let parentWindow = parentTextField?.window
        else { return }

        guard suggestionsWindow.parent == nil else {
            layoutSuggestions()
            return
        }

        // The height of the window will be adjusted in -layoutSuggestions.
        // add the suggestion window as a child window so that it plays nice with Expose
        parentWindow.addChildWindow(suggestionsWindow, ordered: .above)

        // The window must know its accessibility parent.
        // The control must know the window and its accessibility children.
        // Note that views are often ignored, so we want the unignored descendant - usually a cell.
        // Finally, post that we have created the unignored decendant of the suggestions window
        let unignoredAccessDescendant = NSAccessibility.unignoredDescendant(
            of: parentTextField as Any
        )
        suggestionsWindow.parentElement = unignoredAccessDescendant
        // TODO:
        // (unignoredAccessDescendant as? SearchFieldCell)?.suggestionsWindow = suggestionsWindow
        if let unignoredAccessDescendant {
            NSAccessibility.post(element: unignoredAccessDescendant, notification: .created)
        }

        // Setup auto cancellation if the user clicks outside the suggestion window and parent text
        // field.
        // NOTE: this is a local event monitor and will only catch clicks in windows that belong to
        // this application. We use another technique below to catch clicks in other application
        // windows.
        localMouseDownEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [
                NSEvent.EventTypeMask.leftMouseDown,
                NSEvent.EventTypeMask.rightMouseDown,
                NSEvent.EventTypeMask.otherMouseDown
            ],
            handler: { (_ event: NSEvent) -> NSEvent? in
                guard event.window != suggestionsWindow else { return event }
                guard event.window == parentWindow else {
                    // Not in the suggestion window, and not in the parent window. This must be
                    // another window or palette for this application.
                    self.cancelSuggestions()
                    return event
                }

                // Clicks in the parent window should either be in the parent text field or
                // dismiss the suggestions window. We want clicks to occur in the parent text
                // field so that the user can move the caret or select the search text.

                // Use hit testing to determine if the click is in the parent text field.
                // NOTE: when editing an NSTextField, there is a field editor that covers the
                // text field that is performing the actual editing. Therefore, we need to check
                // for the field editor when doing hit testing.
                let contentView = parentWindow.contentView
                let locationTest = contentView?.convert(event.locationInWindow, from: nil)
                let hitView = contentView?.hitTest(locationTest ?? NSPoint.zero)
                let fieldEditor = self.parentTextField?.currentEditor()
                if hitView != self.parentTextField,
                   (fieldEditor != nil && hitView != fieldEditor)
                {
                    // Since the click is not in the parent text field, return nil, so the
                    // parent window does not try to process it, + cancel the suggestion window.
                    self.cancelSuggestions()
                }
                return event
            }
        )

        // As per the documentation, do not retain event monitors.
        // We also need to auto cancel when the window loses key status. This may be done via a
        // mouse click in another window, or via the keyboard (cmd-~ or cmd-tab), or a notification.
        // Observing NSWindowDidResignKeyNotification catches all of these cases and the mouse down
        // event monitor catches the other cases.
        lostFocusObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: parentWindow,
            queue: nil,
            using: { (_ arg1: Notification) -> Void in
                // lost key status, cancel the suggestion window
                self.cancelSuggestions()
            }
        )

        layoutSuggestions()
    }

    public func repositionWindow() {
        guard let parentTextField = parentTextField,
              let parentSuperview = parentTextField.superview,
              let parentWindow = parentTextField.window,
              let suggestionsWindow = self.window as? SuggestionsWindow
        else { return }

        let parentFrame: NSRect = parentTextField.frame

        // y: align top of suggestions window with the bottom of the text field
        let originInWindow = parentSuperview.convert(parentFrame.origin, to: nil)
        let yOnScreen = parentWindow.convertToScreen(
            NSRect(origin: originInWindow, size: .zero)
        ).origin.y

        // x: position at the last '/' character in the text field, falling back to the left edge
        var xOnScreen = parentWindow.convertToScreen(
            NSRect(origin: originInWindow, size: .zero)
        ).origin.x
        let text = parentTextField.stringValue
        if let lastSlashRange = text.range(of: "/", options: .backwards),
           let fieldEditor = parentTextField.currentEditor() as? NSTextView,
           let layoutManager = fieldEditor.layoutManager,
           let textContainer = fieldEditor.textContainer
        {
            let charIndex = text.distance(from: text.startIndex, to: lastSlashRange.upperBound)
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: NSRange(location: 0, length: charIndex),
                actualCharacterRange: nil
            )
            let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let pointInFieldEditor = NSPoint(
                x: boundingRect.maxX + fieldEditor.textContainerOrigin.x - 35.0,
                y: 0
            )
            let pointInWindow = fieldEditor.convert(pointInFieldEditor, to: nil)
            xOnScreen = parentWindow.convertToScreen(NSRect(origin: pointInWindow, size: .zero)).origin.x
        }

        suggestionsWindow.setFrame(suggestionsWindow.frame, display: false)
        suggestionsWindow.setFrameTopLeftPoint(NSPoint(x: xOnScreen, y: yOnScreen))
    }

    // Order out the suggestion window, disconnect the accessibility logical relationship and 
    // dismantle any observers for auto cancel.
    // NOTE: It is safe to call this method even if the suggestions window is not currently visible.
    public func cancelSuggestions() {
        if let parentTextField = self.parentTextField,
           let suggestionsWindow = self.window as? SuggestionsWindow,
           suggestionsWindow.isVisible
        {
            if let unignoredAccessibilityDescendant = NSAccessibility.unignoredDescendant(
                of: parentTextField
            ) {
                NSAccessibility.post(
                    element: unignoredAccessibilityDescendant, notification: .uiElementDestroyed
                )
            }

            trackingAreas.forEach { rowsView?.removeTrackingArea($0) }
            trackingAreas.removeAll()
            viewControllers.forEach { $0.view.removeFromSuperview() }
            viewControllers.removeAll()
            selectedView = nil

            suggestionsWindow.parent?.removeChildWindow(suggestionsWindow)
            suggestionsWindow.orderOut(nil)
            // Disconnect the accessibility parent/child relationship
            //(suggestionWindow.parentElement as? SearchFieldCell)?.suggestionsWindow = nil // TODO
            suggestionsWindow.parentElement = nil
        }
        // Dismantle any observers for auto cancel.
        if let lostFocusObserver = lostFocusObserver {
            NotificationCenter.default.removeObserver(lostFocusObserver)
            self.lostFocusObserver = nil
        }
        if let localMouseDownEventMonitor = localMouseDownEventMonitor {
            NSEvent.removeMonitor(localMouseDownEventMonitor)
            self.localMouseDownEventMonitor = nil
        }
    }

    // Properly creates a tracking area for an image view.
    private func trackingArea(for view: NSView?) -> Any? {
        // Make tracking data (to be stored in NSTrackingArea's userInfo) so we can later determine
        // the imageView without hit testing
        var trackerData: [AnyHashable: Any]? = nil
        if let view = view { trackerData = [kTrackerKey: view] }
        let trackingRect = rowsView?.convert(view?.bounds ?? CGRect.zero, from: view) ?? .zero
        let trackingOptions: NSTrackingArea.Options = [
            .enabledDuringMouseDrag, .mouseEnteredAndExited, .activeInActiveApp
        ]
        return NSTrackingArea(
            rect: trackingRect,
            options: trackingOptions,
            owner: self,
            userInfo: trackerData
        )
    }

    private func layoutSuggestions() {
        guard let suggestionsWindow = self.window as? SuggestionsWindow,
              let rowsView = rowsView
        else { return }

        selectedView = nil
        viewControllers.forEach { $0.view.removeFromSuperview() }
        viewControllers.removeAll()
        trackingAreas.forEach { rowsView.removeTrackingArea($0) }
        trackingAreas.removeAll()

        guard let suggestions = dataSource?.suggestions else { return }

        if suggestions.isEmpty {
            suggestionsWindow.contentView?.isHidden = true
            return
        }

        suggestionsWindow.contentView?.isHidden = false

        let newViewControllers: [SuggestionViewController] = suggestions.compactMap { entry in
            let vc = SuggestionViewController()
            vc.representedObject = entry
            return vc
        }

        let maxLabelWidth = newViewControllers
            .compactMap { $0.suggestionView?.label.intrinsicContentSize.width }
            .max() ?? 0
        let rowWidth = maxLabelWidth + 60

        let itemHeight: CGFloat = 20.0
        let topBottomMargin: CGFloat = 6.0
        var yOffset = topBottomMargin

        for viewController in newViewControllers {
            guard let view = viewController.suggestionView else { continue }
//            view.selectionColor = selectionColor
            rowsView.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: rowsView.leadingAnchor),
                view.widthAnchor.constraint(equalToConstant: rowWidth),
                view.topAnchor.constraint(equalTo: rowsView.topAnchor, constant: yOffset),
                view.heightAnchor.constraint(equalToConstant: itemHeight),
            ])
            viewControllers.append(viewController)
            yOffset += itemHeight
        }

        let totalContentHeight = yOffset + topBottomMargin
        rowsView.frame = NSRect(x: 0, y: 0, width: rowWidth, height: totalContentHeight)
        rowsView.layoutSubtreeIfNeeded()

        for viewController in viewControllers.compactMap({ $0 as? SuggestionViewController }) {
            guard let view = viewController.suggestionView else { continue }
            if let trackingArea = trackingArea(for: view) as? NSTrackingArea {
                rowsView.addTrackingArea(trackingArea)
                trackingAreas.append(trackingArea)
            }
        }

        let windowHeight = min(totalContentHeight, maxWindowHeight)
        var winFrame = window!.frame
        winFrame.origin.y = winFrame.maxY - windowHeight
        winFrame.size.height = windowHeight
        winFrame.size.width = rowWidth
        window?.setFrame(winFrame, display: true)
    }
}

private class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

private class LTRScrollView: NSScrollView {
    override func tile() {
        super.tile()
        guard let vs = verticalScroller, vs.frame.origin.x < bounds.midX else { return }
        let scrollerWidth = vs.frame.width
        vs.frame.origin.x = bounds.width - scrollerWidth
        if vs.scrollerStyle == .legacy {
            contentView.frame = NSRect(
                x: 0,
                y: contentView.frame.origin.y,
                width: bounds.width - scrollerWidth,
                height: contentView.frame.height
            )
        }
        contentView.setBoundsOrigin(NSPoint(x: 0, y: contentView.bounds.origin.y))
    }
}

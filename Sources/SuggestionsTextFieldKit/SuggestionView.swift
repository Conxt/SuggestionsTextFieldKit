//
//  SuggestionView.swift
//
//
//  Created by Claudio Cambra on 2/4/24.
//

import AppKit
import Foundation

class SuggestionView: NSView {
    let highlightSideMargin: CGFloat = 6.0
    let sideMargin: CGFloat = 7.0
    let imageSize: CGFloat = 16.0
    let spaceBetweenLabelAndImage: CGFloat = 6.0

    var imageView: NSImageView!
    var backgroundView: NSView!
    var label: NSTextField!
    var selectionColor: NSColor = .controlAccentColor

    var highlighted: Bool = false {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if highlighted {
                effectiveAppearance.performAsCurrentDrawingAppearance {
                    self.backgroundView.layer?.backgroundColor = selectionColor.cgColor
                }
            } else {
                backgroundView.layer?.backgroundColor = NSColor.clear.cgColor
            }
            CATransaction.commit()
            label.cell?.backgroundStyle = highlighted ? .emphasized : .normal
            imageView.cell?.backgroundStyle = highlighted ? .emphasized : .normal
        }
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        backgroundView = NSView()
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 4.0
        backgroundView.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(backgroundView)
        addConstraints([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: highlightSideMargin),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -highlightSideMargin),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentTintColor = NSColor.labelColor
        addSubview(imageView)
        addConstraints([
            imageView.leftAnchor.constraint(equalTo: leftAnchor, constant: highlightSideMargin + sideMargin),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: imageSize),
            imageView.heightAnchor.constraint(equalToConstant: imageSize),
        ])

        label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        label.font = NSFont.systemFont(ofSize: 12)
        label.alignment = .left
        addSubview(label)
        addConstraints([
            label.leftAnchor.constraint(equalTo: imageView.rightAnchor, constant: spaceBetweenLabelAndImage),
            label.rightAnchor.constraint(equalTo: rightAnchor, constant: -(highlightSideMargin + sideMargin)),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func accessibilityChildren() -> [Any]? { [] }
    override func accessibilityLabel() -> String? { label.stringValue }
}

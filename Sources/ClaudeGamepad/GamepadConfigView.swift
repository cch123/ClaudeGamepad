import AppKit

/// Professional game-style button mapping view.
/// Clean grouped form layout with a decorative controller silhouette header.
final class GamepadConfigView: NSView {
    struct ButtonSlot {
        let key: String
        let popup: NSPopUpButton
    }

    private(set) var slots: [ButtonSlot] = []
    override var isFlipped: Bool { true }

    init(mapping: ButtonMapping) {
        super.init(frame: NSRect(x: 0, y: 0, width: 840, height: 620))
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        var y: CGFloat = 16

        // ── Header with SF Symbol ──
        let headerBg = NSView(frame: NSRect(x: 14, y: y, width: 812, height: 56))
        headerBg.wantsLayer = true
        headerBg.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        headerBg.layer?.cornerRadius = 8
        addSubview(headerBg)

        if let img = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 28, weight: .light)
            let tinted = img.withSymbolConfiguration(config)
            let iv = NSImageView(image: tinted ?? img)
            iv.contentTintColor = .tertiaryLabelColor
            iv.frame = NSRect(x: 28, y: y + 12, width: 34, height: 32)
            addSubview(iv)
        }

        let title = NSTextField(labelWithString: "Button Mapping")
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        title.textColor = .labelColor
        title.frame = NSRect(x: 72, y: y + 18, width: 300, height: 20)
        addSubview(title)

        let subtitle = NSTextField(labelWithString: "Configure what each controller button does")
        subtitle.font = NSFont.systemFont(ofSize: 11)
        subtitle.textColor = .tertiaryLabelColor
        subtitle.frame = NSRect(x: 72, y: y + 36, width: 400, height: 14)
        addSubview(subtitle)

        y += 68

        // ── Two-column layout ──
        let colWidth: CGFloat = 395
        let gap: CGFloat = 16
        let leftX: CGFloat = 14
        let rightX: CGFloat = leftX + colWidth + gap

        // Left column
        var leftY = y
        leftY = addGroup(title: "Triggers & Bumpers", items: [
            ("LT / L2", "lt", mapping.buttonActions),
            ("RT / R2", "rt", mapping.buttonActions),
            ("LB / L1", "lb", mapping.buttonActions),
            ("RB / R1", "rb", mapping.buttonActions),
        ], x: leftX, y: leftY, width: colWidth, mapping: mapping)

        leftY += 12
        leftY = addGroup(title: "D-pad", items: [
            ("↑  Up",    "dpadUp",    mapping.buttonActions),
            ("↓  Down",  "dpadDown",  mapping.buttonActions),
            ("←  Left",  "dpadLeft",  mapping.buttonActions),
            ("→  Right", "dpadRight", mapping.buttonActions),
        ], x: leftX, y: leftY, width: colWidth, mapping: mapping)

        // Right column
        var rightY = y
        rightY = addGroup(title: "Face Buttons", items: [
            ("A / ✕  Cross",    "a", mapping.buttonActions),
            ("B / ○  Circle",   "b", mapping.buttonActions),
            ("X / □  Square",   "x", mapping.buttonActions),
            ("Y / △  Triangle", "y", mapping.buttonActions),
        ], x: rightX, y: rightY, width: colWidth, mapping: mapping)

        rightY += 12
        rightY = addGroup(title: "System", items: [
            ("Start / Menu",    "start",    mapping.buttonActions),
            ("Select / View",   "select",   mapping.buttonActions),
            ("L-Stick (Press)", "stickL",   mapping.buttonActions),
            ("R-Stick (Press)", "stickR",   mapping.buttonActions),
        ], x: rightX, y: rightY, width: colWidth, mapping: mapping)

        // Adjust frame height
        let maxY = max(leftY, rightY) + 16
        frame = NSRect(x: 0, y: 0, width: 840, height: maxY)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build Group

    private func addGroup(
        title: String,
        items: [(String, String, ButtonMapping.ButtonActions)],
        x: CGFloat, y: CGFloat, width: CGFloat,
        mapping: ButtonMapping
    ) -> CGFloat {
        let rowH: CGFloat = 32
        let headerH: CGFloat = 28
        let padding: CGFloat = 10
        let cardH = headerH + CGFloat(items.count) * rowH + padding * 2
        let popupW: CGFloat = 190

        // Card background
        let card = GroupCardView(frame: NSRect(x: x, y: y, width: width, height: cardH))
        addSubview(card)

        // Section title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.frame = NSRect(x: x + 14, y: y + padding, width: width - 28, height: 16)
        addSubview(titleLabel)

        // Separator under title
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: x + 12, y: y + headerH + padding - 4, width: width - 24, height: 1)
        addSubview(sep)

        // Rows
        for (i, item) in items.enumerated() {
            let ry = y + headerH + padding + CGFloat(i) * rowH

            // Button name label
            let label = NSTextField(labelWithString: item.0)
            label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            label.textColor = .labelColor
            label.frame = NSRect(x: x + 14, y: ry + 6, width: width - popupW - 30, height: 18)
            addSubview(label)

            // Color indicator for face buttons
            let colorDot = faceButtonColor(item.1)
            if let color = colorDot {
                let dotView = ColorDotView(color: color, frame: NSRect(x: x + 14, y: ry + 10, width: 8, height: 8))
                addSubview(dotView)
                label.frame = NSRect(x: x + 28, y: ry + 6, width: width - popupW - 44, height: 18)
            }

            // Popup
            let popup = NSPopUpButton(frame: NSRect(x: x + width - popupW - 12, y: ry + 3, width: popupW, height: 24), pullsDown: false)
            popup.font = NSFont.systemFont(ofSize: 11)
            popup.controlSize = .small
            for action in ButtonAction.allCases {
                popup.addItem(withTitle: action.rawValue)
            }
            let configKey = mapKey(item.1)
            popup.selectItem(withTitle: actionForKey(configKey, mapping: mapping).rawValue)
            addSubview(popup)

            slots.append(ButtonSlot(key: item.1, popup: popup))
        }

        return y + cardH
    }

    // MARK: - Helpers

    private func mapKey(_ key: String) -> String {
        if key == "stickL" || key == "stickR" { return "stickClick" }
        if key == "lt" || key == "rt" { return "none" }
        return key
    }

    private func actionForKey(_ key: String, mapping: ButtonMapping) -> ButtonAction {
        switch key {
        case "a": return mapping.buttonActions.a
        case "b": return mapping.buttonActions.b
        case "x": return mapping.buttonActions.x
        case "y": return mapping.buttonActions.y
        case "lb": return mapping.buttonActions.lb
        case "rb": return mapping.buttonActions.rb
        case "start": return mapping.buttonActions.start
        case "select": return mapping.buttonActions.select
        case "stickClick": return mapping.buttonActions.stickClick
        case "dpadUp": return mapping.buttonActions.dpadUp
        case "dpadDown": return mapping.buttonActions.dpadDown
        case "dpadLeft": return mapping.buttonActions.dpadLeft
        case "dpadRight": return mapping.buttonActions.dpadRight
        default: return .none
        }
    }

    private func faceButtonColor(_ key: String) -> NSColor? {
        switch key {
        case "a": return NSColor(red: 0.3, green: 0.78, blue: 0.35, alpha: 1)
        case "b": return NSColor(red: 0.9, green: 0.28, blue: 0.28, alpha: 1)
        case "x": return NSColor(red: 0.3, green: 0.52, blue: 0.95, alpha: 1)
        case "y": return NSColor(red: 0.95, green: 0.78, blue: 0.2, alpha: 1)
        default: return nil
        }
    }

    func actionForSlot(_ key: String) -> ButtonAction {
        // stickL and stickR both map to stickClick
        let searchKey = key
        guard let slot = slots.first(where: { $0.key == searchKey }),
              let title = slot.popup.titleOfSelectedItem,
              let action = ButtonAction.allCases.first(where: { $0.rawValue == title }) else {
            return .none
        }
        return action
    }
}

// MARK: - Group Card

private class GroupCardView: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        NSColor.controlBackgroundColor.setFill()
        path.fill()
        NSColor.separatorColor.withAlphaComponent(0.3).setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
}

// MARK: - Color Dot

private class ColorDotView: NSView {
    let color: NSColor
    override var isFlipped: Bool { true }
    init(color: NSColor, frame: NSRect) {
        self.color = color
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(ovalIn: bounds)
        color.withAlphaComponent(0.8).setFill()
        path.fill()
    }
}

// (removed old controller drawing)

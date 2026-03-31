import AppKit

/// Game-style visual gamepad config view with leader lines to dropdowns.
final class GamepadConfigView: NSView {
    struct ButtonSlot {
        let key: String
        let label: String
        let buttonPoint: NSPoint
        let popupSide: Side
        let popup: NSPopUpButton
        let labelView: NSTextField
    }

    enum Side { case left, right }

    private(set) var slots: [ButtonSlot] = []
    override var isFlipped: Bool { true }

    private let cx: CGFloat = 420
    private let cy: CGFloat = 270

    // Theme colors
    private let bgColor = NSColor(white: 0.10, alpha: 1.0)
    private let cardColor = NSColor(white: 0.15, alpha: 1.0)
    private let cardBorder = NSColor(white: 0.25, alpha: 1.0)
    private let accentBlue = NSColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0)
    private let lineColor = NSColor(white: 0.35, alpha: 1.0)
    private let dotColor = NSColor(white: 0.6, alpha: 1.0)
    private let bodyFill = NSColor(white: 0.18, alpha: 1.0)
    private let bodyStroke = NSColor(white: 0.35, alpha: 1.0)
    private let subtleText = NSColor(white: 0.50, alpha: 1.0)

    init(mapping: ButtonMapping) {
        super.init(frame: NSRect(x: 0, y: 0, width: 860, height: 580))
        wantsLayer = true
        layer?.backgroundColor = bgColor.cgColor
        layer?.cornerRadius = 12

        // Button positions on gamepad
        let ltPt  = NSPoint(x: cx - 145, y: cy - 145)
        let lbPt  = NSPoint(x: cx - 130, y: cy - 105)
        let lsPt  = NSPoint(x: cx - 85,  y: cy - 10)
        let selPt = NSPoint(x: cx - 35,  y: cy - 35)
        let dUpPt = NSPoint(x: cx - 85,  y: cy + 33)
        let dDnPt = NSPoint(x: cx - 85,  y: cy + 77)
        let dLtPt = NSPoint(x: cx - 108, y: cy + 55)
        let dRtPt = NSPoint(x: cx - 62,  y: cy + 55)

        let rtPt  = NSPoint(x: cx + 145, y: cy - 145)
        let rbPt  = NSPoint(x: cx + 130, y: cy - 105)
        let yPt   = NSPoint(x: cx + 85,  y: cy - 45)
        let xPt   = NSPoint(x: cx + 55,  y: cy - 15)
        let bPt   = NSPoint(x: cx + 115, y: cy - 15)
        let aPt   = NSPoint(x: cx + 85,  y: cy + 15)
        let stPt  = NSPoint(x: cx + 35,  y: cy - 35)
        let rsPt  = NSPoint(x: cx + 50,  y: cy + 55)

        let defs: [(String, String, NSPoint, Side)] = [
            ("lt",       "LT",         ltPt,  .left),
            ("lb",       "LB",         lbPt,  .left),
            ("stickL",   "L-Stick",    lsPt,  .left),
            ("select",   "Select",     selPt, .left),
            ("dpadUp",   "D-pad ↑",    dUpPt, .left),
            ("dpadDown", "D-pad ↓",    dDnPt, .left),
            ("dpadLeft", "D-pad ←",    dLtPt, .left),
            ("dpadRight","D-pad →",    dRtPt, .left),

            ("rt",       "RT",         rtPt,  .right),
            ("rb",       "RB",         rbPt,  .right),
            ("y",        "Y",          yPt,   .right),
            ("x",        "X",          xPt,   .right),
            ("b",        "B",          bPt,   .right),
            ("a",        "A",          aPt,   .right),
            ("start",    "Start",      stPt,  .right),
            ("stickR",   "R-Stick",    rsPt,  .right),
        ]

        let leftDefs = defs.filter { $0.3 == .left }
        let rightDefs = defs.filter { $0.3 == .right }

        let popupW: CGFloat = 155
        let rowH: CGFloat = 34
        let startY: CGFloat = 42

        func buildSlots(_ items: [(String, String, NSPoint, Side)], popupX: CGFloat, labelX: CGFloat, labelAlign: NSTextAlignment) -> [ButtonSlot] {
            var result: [ButtonSlot] = []
            for (i, def) in items.enumerated() {
                let py = startY + CGFloat(i) * rowH

                // Card background for each row
                let card = CardView(frame: NSRect(x: popupX - 4, y: py - 2, width: popupW + 58, height: 28))
                addSubview(card)

                // Label
                let lbl = NSTextField(labelWithString: def.1)
                lbl.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold)
                lbl.textColor = subtleText
                lbl.alignment = labelAlign
                lbl.frame = NSRect(x: labelX, y: py + 3, width: 52, height: 16)
                addSubview(lbl)

                // Popup
                let popup = NSPopUpButton(frame: NSRect(x: popupX, y: py, width: popupW, height: 22), pullsDown: false)
                popup.font = NSFont.systemFont(ofSize: 10)
                popup.controlSize = .small
                popup.isBordered = false
                for action in ButtonAction.allCases {
                    popup.addItem(withTitle: action.rawValue)
                }
                let configKey = mapKey(def.0)
                popup.selectItem(withTitle: actionForKey(configKey, mapping: mapping).rawValue)
                addSubview(popup)

                result.append(ButtonSlot(key: def.0, label: def.1, buttonPoint: def.2, popupSide: def.3, popup: popup, labelView: lbl))
            }
            return result
        }

        // Left: label on left of popup
        slots = buildSlots(leftDefs, popupX: 62, labelX: 6, labelAlign: .right)
        // Right: label on right of popup
            + buildSlots(rightDefs, popupX: 650, labelX: 810, labelAlign: .left)

        // Right side labels should be on the right edge
        for slot in slots where slot.popupSide == .right {
            slot.labelView.frame = NSRect(x: 810, y: slot.labelView.frame.origin.y, width: 48, height: 16)
            slot.labelView.alignment = .left
        }
    }

    required init?(coder: NSCoder) { fatalError() }

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

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Background
        bgColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12).fill()

        drawController(ctx)
        drawLeaderLines(ctx)
    }

    private func drawController(_ ctx: CGContext) {
        // === Main body ===
        let body = NSBezierPath()
        body.move(to: p(cx - 155, cy - 90))
        body.curve(to: p(cx - 80, cy - 110), controlPoint1: p(cx - 155, cy - 110), controlPoint2: p(cx - 120, cy - 110))
        body.curve(to: p(cx, cy - 100), controlPoint1: p(cx - 50, cy - 110), controlPoint2: p(cx - 20, cy - 100))
        body.curve(to: p(cx + 80, cy - 110), controlPoint1: p(cx + 20, cy - 100), controlPoint2: p(cx + 50, cy - 110))
        body.curve(to: p(cx + 155, cy - 90), controlPoint1: p(cx + 120, cy - 110), controlPoint2: p(cx + 155, cy - 110))
        body.curve(to: p(cx + 155, cy + 10), controlPoint1: p(cx + 165, cy - 60), controlPoint2: p(cx + 165, cy - 20))
        body.curve(to: p(cx + 120, cy + 120), controlPoint1: p(cx + 155, cy + 50), controlPoint2: p(cx + 145, cy + 95))
        body.curve(to: p(cx + 80, cy + 145), controlPoint1: p(cx + 105, cy + 140), controlPoint2: p(cx + 95, cy + 150))
        body.curve(to: p(cx + 55, cy + 120), controlPoint1: p(cx + 65, cy + 145), controlPoint2: p(cx + 55, cy + 135))
        body.curve(to: p(cx + 45, cy + 40), controlPoint1: p(cx + 50, cy + 90), controlPoint2: p(cx + 45, cy + 65))
        body.curve(to: p(cx, cy + 30), controlPoint1: p(cx + 40, cy + 20), controlPoint2: p(cx + 20, cy + 25))
        body.curve(to: p(cx - 45, cy + 40), controlPoint1: p(cx - 20, cy + 25), controlPoint2: p(cx - 40, cy + 20))
        body.curve(to: p(cx - 55, cy + 120), controlPoint1: p(cx - 50, cy + 65), controlPoint2: p(cx - 50, cy + 90))
        body.curve(to: p(cx - 80, cy + 145), controlPoint1: p(cx - 55, cy + 135), controlPoint2: p(cx - 65, cy + 145))
        body.curve(to: p(cx - 120, cy + 120), controlPoint1: p(cx - 95, cy + 150), controlPoint2: p(cx - 105, cy + 140))
        body.curve(to: p(cx - 155, cy + 10), controlPoint1: p(cx - 145, cy + 95), controlPoint2: p(cx - 155, cy + 50))
        body.curve(to: p(cx - 155, cy - 90), controlPoint1: p(cx - 165, cy - 20), controlPoint2: p(cx - 165, cy - 60))
        body.close()

        // Body fill with subtle inner shadow feel
        bodyFill.setFill()
        body.fill()

        // Inner highlight
        let innerBody = NSBezierPath()
        innerBody.appendOval(in: NSRect(x: cx - 60, y: cy - 80, width: 120, height: 100))
        NSColor(white: 0.22, alpha: 0.3).setFill()
        innerBody.fill()

        bodyStroke.setStroke()
        body.lineWidth = 1.5
        body.lineJoinStyle = .round
        body.stroke()

        // === Triggers ===
        drawTrigger(ctx, center: p(cx - 130, cy - 125), label: "LT")
        drawTrigger(ctx, center: p(cx + 130, cy - 125), label: "RT")

        // === Bumpers ===
        drawBumper(ctx, rect: NSRect(x: cx - 148, y: cy - 98, width: 75, height: 12))
        drawBumper(ctx, rect: NSRect(x: cx + 73, y: cy - 98, width: 75, height: 12))

        // === Left stick ===
        drawStick(ctx, center: p(cx - 85, cy - 10))

        // === D-pad ===
        drawDpad(ctx, center: p(cx - 85, cy + 55))

        // === Right stick ===
        drawStick(ctx, center: p(cx + 50, cy + 55))

        // === Face buttons ===
        drawFaceButton(ctx, center: p(cx + 85, cy - 45), label: "Y", color: NSColor(red: 0.9, green: 0.75, blue: 0.2, alpha: 1))
        drawFaceButton(ctx, center: p(cx + 55, cy - 15), label: "X", color: NSColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1))
        drawFaceButton(ctx, center: p(cx + 115, cy - 15), label: "B", color: NSColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 1))
        drawFaceButton(ctx, center: p(cx + 85, cy + 15), label: "A", color: NSColor(red: 0.3, green: 0.75, blue: 0.35, alpha: 1))

        // === Center buttons ===
        drawSmallPill(ctx, center: p(cx - 35, cy - 35))
        drawSmallPill(ctx, center: p(cx + 35, cy - 35))

        // === Xbox button ===
        let xR: CGFloat = 10
        let xRect = NSRect(x: cx - xR, y: cy - 60 - xR, width: xR * 2, height: xR * 2)
        NSColor(white: 0.25, alpha: 1).setFill()
        NSBezierPath(ovalIn: xRect).fill()
        NSColor(white: 0.35, alpha: 1).setStroke()
        let xCircle = NSBezierPath(ovalIn: xRect)
        xCircle.lineWidth = 1.0
        xCircle.stroke()
    }

    // MARK: - Components

    private func drawTrigger(_ ctx: CGContext, center: NSPoint, label: String) {
        let w: CGFloat = 48, h: CGFloat = 20
        let rect = NSRect(x: center.x - w/2, y: center.y - h/2, width: w, height: h)
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        NSColor(white: 0.22, alpha: 1).setFill()
        path.fill()
        NSColor(white: 0.32, alpha: 1).setStroke()
        path.lineWidth = 1.0
        path.stroke()
        drawText(label, at: center, fontSize: 9, weight: .bold, color: NSColor(white: 0.55, alpha: 1))
    }

    private func drawBumper(_ ctx: CGContext, rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        NSColor(white: 0.20, alpha: 1).setFill()
        path.fill()
        NSColor(white: 0.30, alpha: 1).setStroke()
        path.lineWidth = 0.8
        path.stroke()
    }

    private func drawStick(_ ctx: CGContext, center: NSPoint) {
        // Outer ring
        let outerR: CGFloat = 20
        let outerRect = NSRect(x: center.x - outerR, y: center.y - outerR, width: outerR * 2, height: outerR * 2)
        NSColor(white: 0.14, alpha: 1).setFill()
        NSBezierPath(ovalIn: outerRect).fill()
        NSColor(white: 0.28, alpha: 1).setStroke()
        let outer = NSBezierPath(ovalIn: outerRect)
        outer.lineWidth = 1.2
        outer.stroke()

        // Inner stick top
        let innerR: CGFloat = 13
        let innerRect = NSRect(x: center.x - innerR, y: center.y - innerR, width: innerR * 2, height: innerR * 2)
        NSColor(white: 0.20, alpha: 1).setFill()
        NSBezierPath(ovalIn: innerRect).fill()
        NSColor(white: 0.30, alpha: 1).setStroke()
        let inner = NSBezierPath(ovalIn: innerRect)
        inner.lineWidth = 0.8
        inner.stroke()

        // Grip cross
        let g: CGFloat = 5
        ctx.setStrokeColor(NSColor(white: 0.28, alpha: 1).cgColor)
        ctx.setLineWidth(0.6)
        ctx.move(to: CGPoint(x: center.x - g, y: center.y))
        ctx.addLine(to: CGPoint(x: center.x + g, y: center.y))
        ctx.move(to: CGPoint(x: center.x, y: center.y - g))
        ctx.addLine(to: CGPoint(x: center.x, y: center.y + g))
        ctx.strokePath()
    }

    private func drawDpad(_ ctx: CGContext, center: NSPoint) {
        let arm: CGFloat = 20
        let w: CGFloat = 13

        let path = NSBezierPath()
        path.move(to: p(center.x - w/2, center.y - arm))
        path.line(to: p(center.x + w/2, center.y - arm))
        path.line(to: p(center.x + w/2, center.y - w/2))
        path.line(to: p(center.x + arm, center.y - w/2))
        path.line(to: p(center.x + arm, center.y + w/2))
        path.line(to: p(center.x + w/2, center.y + w/2))
        path.line(to: p(center.x + w/2, center.y + arm))
        path.line(to: p(center.x - w/2, center.y + arm))
        path.line(to: p(center.x - w/2, center.y + w/2))
        path.line(to: p(center.x - arm, center.y + w/2))
        path.line(to: p(center.x - arm, center.y - w/2))
        path.line(to: p(center.x - w/2, center.y - w/2))
        path.close()

        NSColor(white: 0.22, alpha: 1).setFill()
        path.fill()
        NSColor(white: 0.32, alpha: 1).setStroke()
        path.lineWidth = 0.8
        path.stroke()

        // Arrows
        let ac = NSColor(white: 0.40, alpha: 1)
        drawText("▲", at: p(center.x, center.y - 11), fontSize: 6, weight: .regular, color: ac)
        drawText("▼", at: p(center.x, center.y + 11), fontSize: 6, weight: .regular, color: ac)
        drawText("◀", at: p(center.x - 11, center.y + 1), fontSize: 6, weight: .regular, color: ac)
        drawText("▶", at: p(center.x + 11, center.y + 1), fontSize: 6, weight: .regular, color: ac)
    }

    private func drawFaceButton(_ ctx: CGContext, center: NSPoint, label: String, color: NSColor) {
        let r: CGFloat = 12
        let rect = NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)

        // Glow
        let glowRect = rect.insetBy(dx: -3, dy: -3)
        color.withAlphaComponent(0.08).setFill()
        NSBezierPath(ovalIn: glowRect).fill()

        // Button
        color.withAlphaComponent(0.12).setFill()
        NSBezierPath(ovalIn: rect).fill()
        color.withAlphaComponent(0.5).setStroke()
        let circle = NSBezierPath(ovalIn: rect)
        circle.lineWidth = 1.5
        circle.stroke()
        drawText(label, at: center, fontSize: 10, weight: .bold, color: color.withAlphaComponent(0.7))
    }

    private func drawSmallPill(_ ctx: CGContext, center: NSPoint) {
        let w: CGFloat = 8, h: CGFloat = 6
        let rect = NSRect(x: center.x - w/2, y: center.y - h/2, width: w, height: h)
        NSColor(white: 0.25, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
    }

    // MARK: - Leader Lines

    private func drawLeaderLines(_ ctx: CGContext) {
        for slot in slots {
            let btnPt = slot.buttonPoint
            let popupFrame = slot.popup.frame

            let endPt: NSPoint
            if slot.popupSide == .left {
                endPt = NSPoint(x: popupFrame.maxX + 6, y: popupFrame.midY)
            } else {
                endPt = NSPoint(x: popupFrame.minX - 6, y: popupFrame.midY)
            }

            // Horizontal from button, then vertical, then horizontal to popup
            let path = NSBezierPath()
            path.move(to: btnPt)

            let elbowX: CGFloat
            if slot.popupSide == .left {
                elbowX = min(btnPt.x, endPt.x + 20) - 15
            } else {
                elbowX = max(btnPt.x, endPt.x - 20) + 15
            }

            path.line(to: NSPoint(x: elbowX, y: btnPt.y))
            path.line(to: NSPoint(x: elbowX, y: endPt.y))
            path.line(to: endPt)

            lineColor.setStroke()
            path.lineWidth = 0.8
            path.stroke()

            // Dot on button
            let dotR: CGFloat = 2.5
            let dotRect = NSRect(x: btnPt.x - dotR, y: btnPt.y - dotR, width: dotR * 2, height: dotR * 2)
            dotColor.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
        }
    }

    // MARK: - Helpers

    private func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: y) }

    private func drawText(_ text: String, at center: NSPoint, fontSize: CGFloat, weight: NSFont.Weight, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: color,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), withAttributes: attrs)
    }

    func actionForSlot(_ key: String) -> ButtonAction {
        guard let slot = slots.first(where: { $0.key == key }),
              let title = slot.popup.titleOfSelectedItem,
              let action = ButtonAction.allCases.first(where: { $0.rawValue == title }) else {
            return .none
        }
        return action
    }
}

// MARK: - Card Background View

private class CardView: NSView {
    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        NSColor(white: 0.16, alpha: 1).setFill()
        path.fill()
        NSColor(white: 0.24, alpha: 1).setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
}

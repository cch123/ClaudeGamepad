import AppKit

private let mappingPanelColor = NSColor(red: 0.09, green: 0.11, blue: 0.15, alpha: 0.92)
private let mappingDividerColor = NSColor(red: 1, green: 1, blue: 1, alpha: 0.06)
private let mappingSecondaryText = NSColor.white.withAlphaComponent(0.55)

final class GamepadConfigView: NSView {
    struct ButtonSlot {
        let key: String
        let actionKey: String?
        let title: String
        let group: String
        let trailingText: String?
    }

    private struct GroupDescriptor {
        let title: String
        let subtitle: String
        let slotKeys: [String]
        let footer: String?
    }

    private let slots: [ButtonSlot]
    private let groups: [GroupDescriptor]

    private static func makeSlots(_ l: ControllerLabels) -> [ButtonSlot] {
        [
            ButtonSlot(key: "lt", actionKey: nil, title: l.lt, group: "shoulders", trailingText: "Preset Prompts"),
            ButtonSlot(key: "rt", actionKey: nil, title: l.rt, group: "shoulders", trailingText: "Preset Prompts"),
            ButtonSlot(key: "lb", actionKey: "lb", title: l.lb, group: "shoulders", trailingText: nil),
            ButtonSlot(key: "rb", actionKey: "rb", title: l.rb, group: "shoulders", trailingText: nil),
            ButtonSlot(key: "a", actionKey: "a", title: l.a, group: "face", trailingText: nil),
            ButtonSlot(key: "b", actionKey: "b", title: l.b, group: "face", trailingText: nil),
            ButtonSlot(key: "x", actionKey: "x", title: l.x, group: "face", trailingText: nil),
            ButtonSlot(key: "y", actionKey: "y", title: l.y, group: "face", trailingText: nil),
            ButtonSlot(key: "dpadUp", actionKey: "dpadUp", title: "D-pad Up", group: "nav", trailingText: nil),
            ButtonSlot(key: "dpadDown", actionKey: "dpadDown", title: "D-pad Down", group: "nav", trailingText: nil),
            ButtonSlot(key: "dpadLeft", actionKey: "dpadLeft", title: "D-pad Left", group: "nav", trailingText: nil),
            ButtonSlot(key: "dpadRight", actionKey: "dpadRight", title: "D-pad Right", group: "nav", trailingText: nil),
            ButtonSlot(key: "start", actionKey: "start", title: l.start, group: "system", trailingText: nil),
            ButtonSlot(key: "select", actionKey: "select", title: l.select, group: "system", trailingText: nil),
            ButtonSlot(key: "stickL", actionKey: "stickClick", title: l.stickClick, group: "system", trailingText: nil),
        ]
    }

    private static func makeGroups(_ l: ControllerLabels) -> [GroupDescriptor] {
        [
            GroupDescriptor(
                title: "Shoulders",
                subtitle: "\(l.lt) / \(l.rt) modifiers, plus \(l.lb) / \(l.rb) actions",
                slotKeys: ["lt", "rt", "lb", "rb"],
                footer: "\(l.lt) / \(l.rt) stay managed in Preset Prompts."
            ),
            GroupDescriptor(
                title: "Face Buttons",
                subtitle: "Primary action buttons",
                slotKeys: ["a", "b", "x", "y"],
                footer: nil
            ),
            GroupDescriptor(
                title: "Navigation",
                subtitle: "Directional controls",
                slotKeys: ["dpadUp", "dpadDown", "dpadLeft", "dpadRight"],
                footer: nil
            ),
            GroupDescriptor(
                title: "System & Sticks",
                subtitle: "Menu buttons and stick press action",
                slotKeys: ["start", "select", "stickL"],
                footer: "L3 and R3 share the same runtime action."
            ),
        ]
    }

    private var slotActions: [String: ButtonAction] = [:]
    private var popupByActionKey: [String: NSPopUpButton] = [:]
    private var rowByActionKey: [String: MappingActionRowView] = [:]
    private var groupCards: [MappingGroupCardView] = []

    /// Per-button key combos — read by SettingsWindow when saving.
    private(set) var guideKeyCombosMap: [String: [KeyCombo]]

    override var isFlipped: Bool { true }

    init(frame: NSRect, mapping: ButtonMapping) {
        let l = mapping.labels
        self.slots = Self.makeSlots(l)
        self.groups = Self.makeGroups(l)
        self.guideKeyCombosMap = mapping.guideKeyCombosMap
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .clear

        slotActions = [
            "a": mapping.buttonActions.a,
            "b": mapping.buttonActions.b,
            "x": mapping.buttonActions.x,
            "y": mapping.buttonActions.y,
            "lb": mapping.buttonActions.lb,
            "rb": mapping.buttonActions.rb,
            "start": mapping.buttonActions.start,
            "select": mapping.buttonActions.select,
            "stickClick": mapping.buttonActions.stickClick,
            "dpadUp": mapping.buttonActions.dpadUp,
            "dpadDown": mapping.buttonActions.dpadDown,
            "dpadLeft": mapping.buttonActions.dpadLeft,
            "dpadRight": mapping.buttonActions.dpadRight,
        ]

        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        layoutCards()
    }

    private func buildUI() {
        popupByActionKey.removeAll()
        rowByActionKey.removeAll()
        groupCards.removeAll()

        for descriptor in groups {
            let rows = descriptor.slotKeys.compactMap { slot(for: $0) }.map(buildRow)
            let card = MappingGroupCardView(
                title: descriptor.title,
                subtitle: descriptor.subtitle,
                footer: descriptor.footer,
                rows: rows
            )
            addSubview(card)
            groupCards.append(card)
        }
    }

    private func layoutCards() {
        guard groupCards.count == 4 else { return }

        let gap: CGFloat = 12
        let columnWidth = (bounds.width - gap) / 2
        let rowHeightTop = max(groupCards[0].preferredHeight, groupCards[1].preferredHeight)
        let rowHeightBottom = max(groupCards[2].preferredHeight, groupCards[3].preferredHeight)

        groupCards[0].frame = NSRect(x: 0, y: 0, width: columnWidth, height: rowHeightTop)
        groupCards[1].frame = NSRect(x: columnWidth + gap, y: 0, width: columnWidth, height: rowHeightTop)
        groupCards[2].frame = NSRect(x: 0, y: rowHeightTop + gap, width: columnWidth, height: rowHeightBottom)
        groupCards[3].frame = NSRect(x: columnWidth + gap, y: rowHeightTop + gap, width: columnWidth, height: rowHeightBottom)
    }

    private func buildRow(for slot: ButtonSlot) -> MappingActionRowView {
        if let actionKey = slot.actionKey {
            let popup = NSPopUpButton(frame: .zero, pullsDown: false)
            popup.font = NSFont.systemFont(ofSize: 12)
            for action in ButtonAction.allCases {
                popup.addItem(withTitle: action.rawValue)
            }
            popup.selectItem(withTitle: slotActions[actionKey]?.rawValue ?? ButtonAction.none.rawValue)
            popup.target = self
            popup.action = #selector(actionPopupChanged(_:))
            popup.identifier = NSUserInterfaceItemIdentifier(rawValue: actionKey)
            popupByActionKey[actionKey] = popup

            let combosForKey = guideKeyCombosMap[actionKey] ?? [.empty]
            let row = MappingActionRowView(
                title: slot.title,
                popup: popup,
                guideKeyCombos: combosForKey,
                onGuideComboChanged: { [weak self] combos in
                    self?.guideKeyCombosMap[actionKey] = combos
                }
            )
            // Show combo popups if current action is Guide Key Combo
            if slotActions[actionKey] == .guideCombo {
                row.setGuideComboVisible(true)
            }
            rowByActionKey[actionKey] = row
            return row
        }

        return MappingActionRowView(title: slot.title, detail: slot.trailingText ?? "")
    }

    @objc private func actionPopupChanged(_ sender: NSPopUpButton) {
        guard let actionKey = sender.identifier?.rawValue,
              let title = sender.titleOfSelectedItem,
              let action = ButtonAction.allCases.first(where: { $0.rawValue == title }) else { return }
        slotActions[actionKey] = action

        // Show/hide guide combo popups based on selection
        rowByActionKey[actionKey]?.setGuideComboVisible(action == .guideCombo)
    }

    private func slot(for key: String) -> ButtonSlot? {
        slots.first(where: { $0.key == key })
    }

    func actionForSlot(_ key: String) -> ButtonAction {
        switch key {
        case "stickL", "stickR":
            return slotActions["stickClick"] ?? .none
        default:
            guard let slot = slot(for: key), let actionKey = slot.actionKey else { return .none }
            return slotActions[actionKey] ?? .none
        }
    }
}

private final class MappingGroupCardView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let footerLabel = NSTextField(labelWithString: "")
    fileprivate let rows: [MappingActionRowView]
    private let hasFooter: Bool

    var preferredHeight: CGFloat {
        let footerHeight: CGFloat = hasFooter ? 26 : 12
        let rowsHeight = rows.reduce(CGFloat(0)) { $0 + $1.preferredHeight }
        let gaps = CGFloat(max(rows.count - 1, 0)) * 6
        return 50 + rowsHeight + gaps + footerHeight
    }

    override var isFlipped: Bool { true }

    init(title: String, subtitle: String, footer: String?, rows: [MappingActionRowView]) {
        self.rows = rows
        self.hasFooter = footer != nil
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = mappingPanelColor.cgColor
        layer?.cornerRadius = 18
        layer?.borderWidth = 1
        layer?.borderColor = mappingDividerColor.cgColor

        titleLabel.stringValue = title
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        addSubview(titleLabel)

        subtitleLabel.stringValue = subtitle
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = mappingSecondaryText
        addSubview(subtitleLabel)

        footerLabel.stringValue = footer ?? ""
        footerLabel.font = NSFont.systemFont(ofSize: 11)
        footerLabel.textColor = mappingSecondaryText
        footerLabel.isHidden = footer == nil
        addSubview(footerLabel)

        rows.forEach(addSubview)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()

        titleLabel.frame = NSRect(x: 16, y: 14, width: bounds.width - 32, height: 18)
        subtitleLabel.frame = NSRect(x: 16, y: 32, width: bounds.width - 32, height: 14)

        var y: CGFloat = 50
        for row in rows {
            let h = row.preferredHeight
            row.frame = NSRect(x: 12, y: y, width: bounds.width - 24, height: h)
            y += h + 6
        }

        if !footerLabel.isHidden {
            footerLabel.frame = NSRect(x: 16, y: bounds.height - 24, width: bounds.width - 32, height: 14)
        }
    }
}

/// One modifier+key pair in the combo row.
private final class ComboKeyPairView: NSView {
    let modifierPopup: NSPopUpButton
    let keyPopup: NSPopUpButton
    var onChanged: (() -> Void)?

    override var isFlipped: Bool { true }

    init(combo: KeyCombo) {
        let modNames = ["None", "⌘ Cmd", "⌃ Ctrl", "⌥ Opt", "⇧ Shift",
                         "⌘⇧", "⌃⇧", "⌘⌥", "⌃⌥"]
        let modPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        modPopup.font = NSFont.systemFont(ofSize: 11)
        for name in modNames { modPopup.addItem(withTitle: name) }
        modPopup.selectItem(withTitle: Self.modifierName(for: combo))
        self.modifierPopup = modPopup

        let kPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        kPopup.font = NSFont.systemFont(ofSize: 11)
        kPopup.addItem(withTitle: "—")
        for key in KeyCombo.allKeys { kPopup.addItem(withTitle: key) }
        kPopup.selectItem(withTitle: combo.isEmpty ? "—" : combo.key.uppercased())
        self.keyPopup = kPopup

        super.init(frame: .zero)
        addSubview(modPopup)
        addSubview(kPopup)
        modPopup.target = self
        modPopup.action = #selector(valueChanged)
        kPopup.target = self
        kPopup.action = #selector(valueChanged)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func valueChanged() { onChanged?() }

    var keyCombo: KeyCombo {
        let modTitle = modifierPopup.titleOfSelectedItem ?? "None"
        let keyTitle = keyPopup.titleOfSelectedItem ?? "—"
        guard keyTitle != "—" else { return .empty }
        var combo = KeyCombo(key: keyTitle)
        switch modTitle {
        case "⌘ Cmd":   combo.command = true
        case "⌃ Ctrl":  combo.control = true
        case "⌥ Opt":   combo.option = true
        case "⇧ Shift": combo.shift = true
        case "⌘⇧":      combo.command = true; combo.shift = true
        case "⌃⇧":      combo.control = true; combo.shift = true
        case "⌘⌥":      combo.command = true; combo.option = true
        case "⌃⌥":      combo.control = true; combo.option = true
        default: break
        }
        return combo
    }

    static func modifierName(for combo: KeyCombo) -> String {
        if combo.isEmpty { return "None" }
        switch (combo.command, combo.control, combo.option, combo.shift) {
        case (true, false, false, false): return "⌘ Cmd"
        case (false, true, false, false): return "⌃ Ctrl"
        case (false, false, true, false): return "⌥ Opt"
        case (false, false, false, true): return "⇧ Shift"
        case (true, false, false, true):  return "⌘⇧"
        case (false, true, false, true):  return "⌃⇧"
        case (true, false, true, false):  return "⌘⌥"
        case (false, true, true, false):  return "⌃⌥"
        default: return "None"
        }
    }

    override func layout() {
        super.layout()
        let modW = bounds.width * 0.6
        let keyW = bounds.width - modW - 2
        modifierPopup.frame = NSRect(x: 0, y: 0, width: modW, height: bounds.height)
        keyPopup.frame = NSRect(x: modW + 2, y: 0, width: keyW, height: bounds.height)
    }
}

private final class MappingActionRowView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let popup: NSPopUpButton?

    // Guide key combo sub-controls (shown when action = Guide Key Combo)
    private var comboPairViews: [ComboKeyPairView] = []
    private var comboVisible = false
    private var onGuideComboChanged: (([KeyCombo]) -> Void)?

    override var isFlipped: Bool { true }

    /// Row with an action popup + optional guide combo sub-popups.
    init(title: String, popup: NSPopUpButton, guideKeyCombos: [KeyCombo],
         onGuideComboChanged: @escaping ([KeyCombo]) -> Void) {
        self.popup = popup
        self.onGuideComboChanged = onGuideComboChanged
        super.init(frame: .zero)
        commonInit(title: title)
        addSubview(popup)

        // Build initial combo pair views
        let combos = guideKeyCombos.isEmpty ? [KeyCombo.empty] : guideKeyCombos
        for combo in combos {
            appendComboPairView(for: combo)
        }

    }

    /// Row with static detail text (no action popup).
    init(title: String, detail: String) {
        self.popup = nil
        super.init(frame: .zero)
        commonInit(title: title)
        detailLabel.stringValue = detail
        addSubview(detailLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func appendComboPairView(for combo: KeyCombo) {
        let pairView = ComboKeyPairView(combo: combo)
        pairView.isHidden = !comboVisible
        pairView.onChanged = { [weak self] in self?.comboChanged() }
        addSubview(pairView)
        comboPairViews.append(pairView)
    }

    func setGuideComboVisible(_ visible: Bool) {
        comboVisible = visible
        comboPairViews.forEach { $0.isHidden = !visible }
        needsLayout = true
    }

    private func comboChanged() {
        let combos = comboPairViews.map { $0.keyCombo }
        onGuideComboChanged?(combos)
    }

    /// Total height needed for this row.
    var preferredHeight: CGFloat {
        if comboVisible && comboPairViews.count > 1 {
            return 32 + CGFloat(comboPairViews.count - 1) * 28
        }
        return 32
    }

    private func commonInit(title: String) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.03).cgColor
        layer?.cornerRadius = 11

        titleLabel.stringValue = title
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        addSubview(titleLabel)

        detailLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        detailLabel.textColor = NSColor.white.withAlphaComponent(0.42)
        detailLabel.alignment = .right
        detailLabel.lineBreakMode = .byTruncatingMiddle
    }

    override func layout() {
        super.layout()

        titleLabel.frame = NSRect(x: 14, y: 7, width: 100, height: 18)
        if let popup {
            if comboVisible {
                // Layout: [Action ▾] [Mod ▾ Key ▾]
                let actionW: CGFloat = 80
                let actionX: CGFloat = 104
                let gap: CGFloat = 3
                let rightEdge = bounds.width - 10
                let comboW = rightEdge - actionX - actionW - gap

                popup.frame = NSRect(x: actionX, y: 3, width: actionW, height: 26)

                let comboX = actionX + actionW + gap
                for (i, pairView) in comboPairViews.enumerated() {
                    pairView.frame = NSRect(x: comboX, y: 3 + CGFloat(i) * 28, width: comboW, height: 26)
                }
            } else {
                popup.frame = NSRect(x: bounds.width - 186, y: 3, width: 172, height: 26)
            }
        } else {
            detailLabel.frame = NSRect(x: bounds.width - 150, y: 8, width: 136, height: 16)
        }
    }
}

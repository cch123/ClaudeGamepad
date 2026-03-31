import AppKit

private let mappingPanelColor = NSColor(red: 0.09, green: 0.11, blue: 0.15, alpha: 0.92)
private let mappingRowColor = NSColor(red: 1, green: 1, blue: 1, alpha: 0.035)
private let mappingSelectionColor = NSColor(red: 0.42, green: 0.48, blue: 0.58, alpha: 0.26)
private let mappingDividerColor = NSColor(red: 1, green: 1, blue: 1, alpha: 0.06)

final class GamepadConfigView: NSView {
    struct ButtonSlot {
        let key: String
        let actionKey: String?
        let title: String
        let subtitle: String
        let group: String
        let tint: NSColor?
        let lockedMessage: String?

        var isEditable: Bool { actionKey != nil }
    }

    private let slots: [ButtonSlot] = [
        ButtonSlot(key: "lt", actionKey: nil, title: "LT / L2", subtitle: "Quick prompt modifier", group: "Triggers", tint: nil, lockedMessage: "LT is reserved for quick prompts. Edit LT combinations in Preset Prompts."),
        ButtonSlot(key: "rt", actionKey: nil, title: "RT / R2", subtitle: "Quick prompt modifier", group: "Triggers", tint: nil, lockedMessage: "RT is reserved for quick prompts. Edit RT combinations in Preset Prompts."),
        ButtonSlot(key: "lb", actionKey: "lb", title: "LB / L1", subtitle: "Left bumper", group: "Shoulders", tint: nil, lockedMessage: nil),
        ButtonSlot(key: "rb", actionKey: "rb", title: "RB / R1", subtitle: "Right bumper", group: "Shoulders", tint: nil, lockedMessage: nil),
        ButtonSlot(key: "a", actionKey: "a", title: "A / Cross", subtitle: "Bottom face button", group: "Face Buttons", tint: NSColor(red: 0.30, green: 0.78, blue: 0.35, alpha: 1), lockedMessage: nil),
        ButtonSlot(key: "b", actionKey: "b", title: "B / Circle", subtitle: "Right face button", group: "Face Buttons", tint: NSColor(red: 0.90, green: 0.28, blue: 0.28, alpha: 1), lockedMessage: nil),
        ButtonSlot(key: "x", actionKey: "x", title: "X / Square", subtitle: "Left face button", group: "Face Buttons", tint: NSColor(red: 0.30, green: 0.52, blue: 0.95, alpha: 1), lockedMessage: nil),
        ButtonSlot(key: "y", actionKey: "y", title: "Y / Triangle", subtitle: "Top face button", group: "Face Buttons", tint: NSColor(red: 0.95, green: 0.78, blue: 0.20, alpha: 1), lockedMessage: nil),
        ButtonSlot(key: "dpadUp", actionKey: "dpadUp", title: "D-pad Up", subtitle: "Directional input", group: "Navigation", tint: nil, lockedMessage: nil),
        ButtonSlot(key: "dpadDown", actionKey: "dpadDown", title: "D-pad Down", subtitle: "Directional input", group: "Navigation", tint: nil, lockedMessage: nil),
        ButtonSlot(key: "dpadLeft", actionKey: "dpadLeft", title: "D-pad Left", subtitle: "Directional input", group: "Navigation", tint: nil, lockedMessage: nil),
        ButtonSlot(key: "dpadRight", actionKey: "dpadRight", title: "D-pad Right", subtitle: "Directional input", group: "Navigation", tint: nil, lockedMessage: nil),
        ButtonSlot(key: "start", actionKey: "start", title: "Start / Menu", subtitle: "Primary system button", group: "System", tint: nil, lockedMessage: nil),
        ButtonSlot(key: "select", actionKey: "select", title: "Select / View", subtitle: "Secondary system button", group: "System", tint: nil, lockedMessage: nil),
        ButtonSlot(key: "stickL", actionKey: "stickClick", title: "L-Stick Press", subtitle: "Shared with the right stick press", group: "Sticks", tint: nil, lockedMessage: nil),
        ButtonSlot(key: "stickR", actionKey: "stickClick", title: "R-Stick Press", subtitle: "Shared with the left stick press", group: "Sticks", tint: nil, lockedMessage: nil),
    ]

    private var slotActions: [String: ButtonAction] = [:]
    private var rowViews: [String: MappingListRowView] = [:]
    private var selectedSlotKey = "a"

    private var detailGroupLabel: NSTextField!
    private var detailTitleLabel: NSTextField!
    private var detailSubtitleLabel: NSTextField!
    private var detailActionLabel: NSTextField!
    private var detailInfoLabel: NSTextField!
    private var detailNotesLabel: NSTextField!
    private var actionPopup: NSPopUpButton!

    override var isFlipped: Bool { true }

    init(frame: NSRect, mapping: ButtonMapping) {
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
        selectSlot(selectedSlotKey)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        let panel = MappingPanelView(frame: bounds)
        panel.autoresizingMask = [.width, .height]
        addSubview(panel)

        let panelHeight = panel.bounds.height
        let listWidth: CGFloat = 352
        let panelInset: CGFloat = 24

        let listTitle = NSTextField(labelWithString: "Buttons")
        listTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        listTitle.frame = NSRect(x: panelInset, y: 20, width: 120, height: 18)
        panel.addSubview(listTitle)

        let listSubtitle = NSTextField(labelWithString: "Review every editable control in one place.")
        listSubtitle.font = NSFont.systemFont(ofSize: 11)
        listSubtitle.textColor = NSColor.white.withAlphaComponent(0.58)
        listSubtitle.frame = NSRect(x: panelInset, y: 40, width: 250, height: 14)
        panel.addSubview(listSubtitle)

        let countLabel = NSTextField(labelWithString: "\(editableCount()) editable buttons")
        countLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        countLabel.textColor = NSColor.white.withAlphaComponent(0.58)
        countLabel.alignment = .right
        countLabel.frame = NSRect(x: panel.bounds.width - 170, y: 22, width: 148, height: 14)
        countLabel.autoresizingMask = [.minXMargin]
        panel.addSubview(countLabel)

        let dividerX = listWidth + panelInset + 14
        let divider = NSBox(frame: NSRect(x: dividerX, y: 22, width: 1, height: panelHeight - 44))
        divider.boxType = .separator
        divider.autoresizingMask = [.minXMargin, .height]
        panel.addSubview(divider)

        let listScroll = NSScrollView(frame: NSRect(x: 16, y: 74, width: listWidth, height: panelHeight - 92))
        listScroll.autoresizingMask = [.width, .height]
        listScroll.drawsBackground = false
        listScroll.hasVerticalScroller = true
        panel.addSubview(listScroll)

        let listDocument = FlippedView(frame: NSRect(x: 0, y: 0, width: listWidth - 12, height: 840))
        listScroll.documentView = listDocument

        buildList(in: listDocument)

        let detailX = dividerX + 26
        let detailWidth = panel.bounds.width - detailX - 28

        detailGroupLabel = NSTextField(labelWithString: "")
        detailGroupLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        detailGroupLabel.textColor = NSColor.white.withAlphaComponent(0.45)
        detailGroupLabel.frame = NSRect(x: detailX, y: 22, width: detailWidth, height: 14)
        detailGroupLabel.autoresizingMask = [.width]
        panel.addSubview(detailGroupLabel)

        detailTitleLabel = NSTextField(labelWithString: "")
        detailTitleLabel.font = NSFont.systemFont(ofSize: 26, weight: .semibold)
        detailTitleLabel.frame = NSRect(x: detailX, y: 42, width: detailWidth, height: 30)
        detailTitleLabel.autoresizingMask = [.width]
        panel.addSubview(detailTitleLabel)

        detailSubtitleLabel = NSTextField(wrappingLabelWithString: "")
        detailSubtitleLabel.font = NSFont.systemFont(ofSize: 13)
        detailSubtitleLabel.textColor = NSColor.white.withAlphaComponent(0.62)
        detailSubtitleLabel.frame = NSRect(x: detailX, y: 74, width: detailWidth, height: 20)
        detailSubtitleLabel.autoresizingMask = [.width]
        panel.addSubview(detailSubtitleLabel)

        let sectionDivider = NSBox(frame: NSRect(x: detailX, y: 104, width: detailWidth, height: 1))
        sectionDivider.boxType = .separator
        sectionDivider.autoresizingMask = [.width]
        panel.addSubview(sectionDivider)

        let assignedLabel = NSTextField(labelWithString: "Assigned Action")
        assignedLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        assignedLabel.textColor = NSColor.white.withAlphaComponent(0.45)
        assignedLabel.frame = NSRect(x: detailX, y: 122, width: 140, height: 14)
        panel.addSubview(assignedLabel)

        detailActionLabel = NSTextField(labelWithString: "")
        detailActionLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        detailActionLabel.frame = NSRect(x: detailX, y: 142, width: detailWidth, height: 22)
        detailActionLabel.autoresizingMask = [.width]
        panel.addSubview(detailActionLabel)

        actionPopup = NSPopUpButton(frame: NSRect(x: detailX, y: 178, width: min(300, detailWidth), height: 28), pullsDown: false)
        actionPopup.font = NSFont.systemFont(ofSize: 12)
        for action in ButtonAction.allCases {
            actionPopup.addItem(withTitle: action.rawValue)
        }
        actionPopup.target = self
        actionPopup.action = #selector(actionPopupChanged)
        panel.addSubview(actionPopup)

        detailInfoLabel = NSTextField(wrappingLabelWithString: "")
        detailInfoLabel.font = NSFont.systemFont(ofSize: 13)
        detailInfoLabel.textColor = NSColor.white.withAlphaComponent(0.82)
        detailInfoLabel.frame = NSRect(x: detailX, y: 218, width: detailWidth, height: 56)
        detailInfoLabel.autoresizingMask = [.width]
        panel.addSubview(detailInfoLabel)

        let notesDivider = NSBox(frame: NSRect(x: detailX, y: 290, width: detailWidth, height: 1))
        notesDivider.boxType = .separator
        notesDivider.autoresizingMask = [.width]
        panel.addSubview(notesDivider)

        let notesCaption = NSTextField(labelWithString: "Notes")
        notesCaption.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        notesCaption.textColor = NSColor.white.withAlphaComponent(0.45)
        notesCaption.frame = NSRect(x: detailX, y: 308, width: 90, height: 14)
        panel.addSubview(notesCaption)

        detailNotesLabel = NSTextField(wrappingLabelWithString: "")
        detailNotesLabel.font = NSFont.systemFont(ofSize: 12)
        detailNotesLabel.textColor = NSColor.white.withAlphaComponent(0.60)
        detailNotesLabel.frame = NSRect(x: detailX, y: 330, width: detailWidth, height: max(42, panelHeight - 350))
        detailNotesLabel.autoresizingMask = [.width]
        panel.addSubview(detailNotesLabel)
    }

    private func buildList(in listDocument: FlippedView) {
        let grouped = Dictionary(grouping: slots, by: \.group)
        let orderedGroups = ["Triggers", "Shoulders", "Face Buttons", "Navigation", "System", "Sticks"]

        var y: CGFloat = 0
        for group in orderedGroups {
            guard let groupSlots = grouped[group] else { continue }

            let groupLabel = NSTextField(labelWithString: group.uppercased())
            groupLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
            groupLabel.textColor = NSColor.white.withAlphaComponent(0.38)
            groupLabel.frame = NSRect(x: 10, y: y + 4, width: 160, height: 14)
            listDocument.addSubview(groupLabel)
            y += 24

            for slot in groupSlots {
                let row = MappingListRowView(frame: NSRect(x: 0, y: y, width: listDocument.bounds.width, height: 50))
                row.autoresizingMask = [.width]
                row.onSelect = { [weak self] in self?.selectSlot(slot.key) }
                row.configure(
                    title: slot.title,
                    subtitle: slot.subtitle,
                    actionTitle: displayActionTitle(for: slot),
                    tint: slot.tint,
                    isEditable: slot.isEditable
                )
                listDocument.addSubview(row)
                rowViews[slot.key] = row
                y += 54
            }

            y += 10
        }

        listDocument.frame.size.height = y + 8
    }

    @objc private func actionPopupChanged() {
        guard let slot = slot(for: selectedSlotKey),
              let actionKey = slot.actionKey,
              let title = actionPopup.titleOfSelectedItem,
              let action = ButtonAction.allCases.first(where: { $0.rawValue == title }) else { return }

        slotActions[actionKey] = action
        refreshRows(for: actionKey)
        updateDetail(for: slot)
    }

    private func slot(for key: String) -> ButtonSlot? {
        slots.first(where: { $0.key == key })
    }

    private func selectSlot(_ key: String) {
        selectedSlotKey = key
        for (rowKey, row) in rowViews {
            row.isSelected = rowKey == key
        }
        guard let slot = slot(for: key) else { return }
        updateDetail(for: slot)
    }

    private func refreshRows(for actionKey: String? = nil) {
        for slot in slots {
            guard actionKey == nil || slot.actionKey == actionKey else { continue }
            rowViews[slot.key]?.configure(
                title: slot.title,
                subtitle: slot.subtitle,
                actionTitle: displayActionTitle(for: slot),
                tint: slot.tint,
                isEditable: slot.isEditable
            )
        }
    }

    private func updateDetail(for slot: ButtonSlot) {
        detailGroupLabel.stringValue = slot.group.uppercased()
        detailTitleLabel.stringValue = slot.title
        detailSubtitleLabel.stringValue = slot.subtitle
        detailActionLabel.stringValue = displayActionTitle(for: slot)
        detailActionLabel.textColor = slot.isEditable ? .white : NSColor.white.withAlphaComponent(0.72)
        detailInfoLabel.stringValue = slot.lockedMessage ?? actionDescription(for: currentAction(for: slot))

        if slot.isEditable {
            actionPopup.isEnabled = true
            actionPopup.selectItem(withTitle: currentAction(for: slot).rawValue)
            if slot.actionKey == "stickClick" {
                detailNotesLabel.stringValue = "L3 and R3 share one mapping because the runtime treats both stick presses as the same action."
            } else {
                detailNotesLabel.stringValue = "Changes here are saved back into the controller mapping. The row list on the left updates immediately."
            }
        } else {
            actionPopup.isEnabled = false
            detailNotesLabel.stringValue = "This control stays visible so the full controller model remains understandable, but its behavior comes from quick prompts instead of button actions."
        }
    }

    private func currentAction(for slot: ButtonSlot) -> ButtonAction {
        guard let actionKey = slot.actionKey else { return .none }
        return slotActions[actionKey] ?? .none
    }

    private func displayActionTitle(for slot: ButtonSlot) -> String {
        slot.isEditable ? currentAction(for: slot).rawValue : "Preset Prompt Modifier"
    }

    private func editableCount() -> Int {
        slots.filter(\.isEditable).count
    }

    func actionForSlot(_ key: String) -> ButtonAction {
        guard let slot = slot(for: key) else { return .none }
        return currentAction(for: slot)
    }

    private func actionDescription(for action: ButtonAction) -> String {
        switch action {
        case .enter:
            return "Sends Enter to the terminal, usually confirming the current selection or submitting the current input."
        case .ctrlC:
            return "Sends Control-C to interrupt the active task or cancel the current shell command."
        case .accept:
            return "Types y followed by Enter, matching the common accept flow in Claude Code."
        case .reject:
            return "Types n followed by Enter, matching the common reject flow in Claude Code."
        case .tab:
            return "Sends Tab for shell completion or focus movement."
        case .escape:
            return "Sends Escape to back out of the current UI state."
        case .voiceInput:
            return "Starts voice capture and inserts the recognized text after you confirm it."
        case .presetMenu:
            return "Opens the preset prompt browser so you can step through saved prompts with the D-pad."
        case .clear:
            return "Types /clear into the terminal input."
        case .arrowUp:
            return "Sends the Up Arrow key."
        case .arrowDown:
            return "Sends the Down Arrow key."
        case .arrowLeft:
            return "Sends the Left Arrow key."
        case .arrowRight:
            return "Sends the Right Arrow key."
        case .quit:
            return "Closes the app after a short delay."
        case .none:
            return "No action is sent for this button."
        }
    }
}

private final class MappingPanelView: NSView {
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = mappingPanelColor.cgColor
        layer?.cornerRadius = 18
        layer?.borderWidth = 1
        layer?.borderColor = mappingDividerColor.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }
}

private final class MappingListRowView: NSView {
    private let dotView = NSView(frame: .zero)
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let actionLabel = NSTextField(labelWithString: "")

    var onSelect: (() -> Void)?
    var isSelected = false {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12

        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 3.5
        dotView.frame = NSRect(x: 14, y: 21, width: 7, height: 7)
        addSubview(dotView)

        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: 30, y: 10, width: 170, height: 16)
        titleLabel.autoresizingMask = [.maxXMargin]
        addSubview(titleLabel)

        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.48)
        subtitleLabel.frame = NSRect(x: 30, y: 27, width: 172, height: 14)
        subtitleLabel.autoresizingMask = [.maxXMargin]
        addSubview(subtitleLabel)

        actionLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        actionLabel.alignment = .right
        actionLabel.textColor = NSColor.white.withAlphaComponent(0.70)
        actionLabel.lineBreakMode = .byTruncatingMiddle
        actionLabel.frame = NSRect(x: frameRect.width - 168, y: 17, width: 154, height: 14)
        actionLabel.autoresizingMask = [.minXMargin]
        addSubview(actionLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, subtitle: String, actionTitle: String, tint: NSColor?, isEditable: Bool) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        actionLabel.stringValue = actionTitle
        dotView.layer?.backgroundColor = (tint ?? NSColor.white.withAlphaComponent(isEditable ? 0.14 : 0.08)).cgColor
        actionLabel.textColor = isEditable ? NSColor.white.withAlphaComponent(0.70) : NSColor.white.withAlphaComponent(0.40)
        alphaValue = isEditable ? 1.0 : 0.74
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12)
        (isSelected ? mappingSelectionColor : mappingRowColor).setFill()
        path.fill()
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?()
    }
}

import AppKit

private let surgeWindowColor = NSColor(red: 0.16, green: 0.19, blue: 0.25, alpha: 1)
private let surgeSidebarColor = NSColor(red: 0.12, green: 0.15, blue: 0.20, alpha: 0.96)
private let surgeCardColor = NSColor(red: 0.09, green: 0.11, blue: 0.15, alpha: 0.90)
private let surgeSelectionColor = NSColor(red: 0.42, green: 0.48, blue: 0.58, alpha: 0.28)
private let surgeDividerColor = NSColor(red: 1, green: 1, blue: 1, alpha: 0.06)

/// Settings window inspired by native macOS utilities: a persistent sidebar,
/// status-first cards, and a focused editor for the current item.
final class SettingsWindow: NSWindowController, NSTextViewDelegate {
    private enum SettingsSection: CaseIterable {
        case general
        case buttons
        case prompts
        case combos
        case speech

        var title: String {
            switch self {
            case .general: return "General"
            case .buttons: return "Button Mapping"
            case .prompts: return "Preset Prompts"
            case .combos: return "Command Combos"
            case .speech: return "Speech Recognition"
            }
        }

        var subtitle: String {
            switch self {
            case .general:
                return "Controller style and general preferences."
            case .buttons:
                return "Review the controller layout and keep high-frequency actions easy to scan."
            case .prompts:
                return "Edit trigger combos from one focused workspace instead of juggling dropdowns."
            case .combos:
                return "Configure command mode: combo style and input sequences."
            case .speech:
                return "See the whole voice pipeline at a glance: engine, model, install state, and LLM cleanup."
            }
        }

        var symbolName: String {
            switch self {
            case .general: return "gearshape"
            case .buttons: return "gamecontroller"
            case .prompts: return "text.bubble"
            case .combos: return "bolt.circle"
            case .speech: return "waveform.and.mic"
            }
        }
    }

    private struct PromptSlotDescriptor {
        let id: String
        let title: String
        let subtitle: String
        let promptKey: String
        let color: NSColor
        let currentValue: (ButtonMapping) -> String
    }

    private var promptSlots: [PromptSlotDescriptor] {
        let l = mapping.labels
        return [
            PromptSlotDescriptor(id: "lt.a", title: "\(l.lt) + \(l.a)", subtitle: "Left trigger quick action",
                                 promptKey: "a", color: l.colorA, currentValue: { $0.ltPrompts.a }),
            PromptSlotDescriptor(id: "lt.b", title: "\(l.lt) + \(l.b)", subtitle: "Left trigger quick action",
                                 promptKey: "b", color: l.colorB, currentValue: { $0.ltPrompts.b }),
            PromptSlotDescriptor(id: "lt.x", title: "\(l.lt) + \(l.x)", subtitle: "Left trigger quick action",
                                 promptKey: "x", color: l.colorX, currentValue: { $0.ltPrompts.x }),
            PromptSlotDescriptor(id: "lt.y", title: "\(l.lt) + \(l.y)", subtitle: "Left trigger quick action",
                                 promptKey: "y", color: l.colorY, currentValue: { $0.ltPrompts.y }),
            PromptSlotDescriptor(id: "rt.a", title: "\(l.rt) + \(l.a)", subtitle: "Right trigger quick action",
                                 promptKey: "a", color: l.colorA, currentValue: { $0.rtPrompts.a }),
            PromptSlotDescriptor(id: "rt.b", title: "\(l.rt) + \(l.b)", subtitle: "Right trigger quick action",
                                 promptKey: "b", color: l.colorB, currentValue: { $0.rtPrompts.b }),
            PromptSlotDescriptor(id: "rt.x", title: "\(l.rt) + \(l.x)", subtitle: "Right trigger quick action",
                                 promptKey: "x", color: l.colorX, currentValue: { $0.rtPrompts.x }),
            PromptSlotDescriptor(id: "rt.y", title: "\(l.rt) + \(l.y)", subtitle: "Right trigger quick action",
                                 promptKey: "y", color: l.colorY, currentValue: { $0.rtPrompts.y }),
        ]
    }

    private var mapping = ButtonMapping.load()
    private var speechSettings = SpeechSettings.load()

    private var rootView: FlippedView!
    private var contentContainer: FlippedView!
    private var sidebarButtons: [SettingsSection: SidebarSelectionButton] = [:]
    private var sectionViews: [SettingsSection: NSView] = [:]
    private var currentSection: SettingsSection = .buttons

    private var gamepadView: GamepadConfigView!

    private var promptValues: [String: String] = [:]
    private var promptRows: [String: PromptSlotRowView] = [:]
    private var selectedPromptID: String?
    private var promptSourcePopup: NSPopUpButton!
    private var promptEditorTitleLabel: NSTextField!
    private var promptEditorSubtitleLabel: NSTextField!
    private var promptCountLabel: NSTextField!
    private var promptPreviewLabel: NSTextField!
    private var promptEditorTextView: NSTextView!

    private var enginePopup: NSPopUpButton!
    private var whisperModelPopup: NSPopUpButton!
    private var whisperStatusLabel: NSTextField!
    private var whisperProgressBar: NSProgressIndicator!
    private var whisperDownloadButton: NSButton!
    private var whisperInstallButton: NSButton!
    private var llmCheckbox: NSButton!
    private var llmURLField: NSTextField!
    private var llmKeyField: NSSecureTextField!
    private var llmModelField: NSTextField!
    private var speechSummaryLabels: [String: NSTextField] = [:]
    private var whisperManagedControls: [NSControl] = []
    private var llmManagedControls: [NSControl] = []
    private var whisperCard: SurfaceCardView!
    private var llmCard: SurfaceCardView!

    private let sidebarWidth: CGFloat = 208
    private let bottomBarHeight: CGFloat = 60
    private let topInset: CGFloat = 34
    private let pageInset: CGFloat = 28
    private let pageGap: CGFloat = 16
    private let cardInset: CGFloat = 20
    private let rowHeight: CGFloat = 32
    private let labelWidth: CGFloat = 150

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Claude Gamepad Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.appearance = NSAppearance(named: .darkAqua)
        window.isMovableByWindowBackground = true
        window.center()
        window.minSize = NSSize(width: 980, height: 720)
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.subviews.forEach { $0.removeFromSuperview() }

        rootView = FlippedView(frame: contentView.bounds)
        rootView.autoresizingMask = [.width, .height]
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = surgeWindowColor.cgColor
        contentView.addSubview(rootView)

        buildSidebar(in: rootView)
        buildContentContainer(in: rootView)
        buildBottomBar(in: rootView)

        selectSection(.buttons)
    }

    private func buildSidebar(in parent: FlippedView) {
        let sidebar = FlippedView(frame: NSRect(x: 0, y: 0, width: sidebarWidth, height: parent.bounds.height))
        sidebar.autoresizingMask = [.height]
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = surgeSidebarColor.cgColor
        parent.addSubview(sidebar)

        let sectionLabel = NSTextField(labelWithString: "SETTINGS")
        sectionLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        sectionLabel.textColor = NSColor.white.withAlphaComponent(0.34)
        sectionLabel.frame = NSRect(x: 20, y: 64, width: 120, height: 14)
        sidebar.addSubview(sectionLabel)

        for (index, section) in SettingsSection.allCases.enumerated() {
            let button = SidebarSelectionButton(title: section.title, symbolName: section.symbolName)
            button.frame = NSRect(x: 10, y: 92 + CGFloat(index) * 48, width: sidebarWidth - 20, height: 42)
            button.target = self
            button.action = #selector(sidebarSelectionChanged(_:))
            button.tag = index
            sidebar.addSubview(button)
            sidebarButtons[section] = button
        }

        let separator = NSBox(frame: NSRect(x: sidebarWidth - 1, y: 0, width: 1, height: sidebar.bounds.height))
        separator.boxType = .separator
        separator.autoresizingMask = [.height, .minXMargin]
        sidebar.addSubview(separator)
    }

    private func buildContentContainer(in parent: FlippedView) {
        let x = sidebarWidth + 24
        let width = parent.bounds.width - x - topInset
        let height = parent.bounds.height - bottomBarHeight - topInset * 2
        contentContainer = FlippedView(frame: NSRect(x: x, y: topInset, width: width, height: height))
        contentContainer.autoresizingMask = [.width, .height]
        parent.addSubview(contentContainer)
    }

    private func buildBottomBar(in parent: FlippedView) {
        let barX = sidebarWidth + 24
        let bar = FlippedView(frame: NSRect(x: barX, y: parent.bounds.height - bottomBarHeight, width: parent.bounds.width - barX - topInset, height: bottomBarHeight - 12))
        bar.autoresizingMask = [.width, .minYMargin]
        parent.addSubview(bar)

        let separator = NSBox(frame: NSRect(x: 0, y: 0, width: bar.bounds.width, height: 1))
        separator.boxType = .separator
        separator.autoresizingMask = [.width]
        bar.addSubview(separator)

        let helper = NSTextField(labelWithString: "Changes apply after Save. Accessibility and Speech permissions are still managed by macOS.")
        helper.font = NSFont.systemFont(ofSize: 11)
        helper.textColor = .secondaryLabelColor
        helper.frame = NSRect(x: 0, y: 20, width: 560, height: 16)
        helper.autoresizingMask = [.maxXMargin]
        bar.addSubview(helper)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        saveButton.frame = NSRect(x: bar.bounds.width - 88, y: 12, width: 82, height: 30)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.autoresizingMask = [.minXMargin]
        bar.addSubview(saveButton)

        let resetButton = NSButton(title: "Reset Defaults", target: self, action: #selector(resetDefaults))
        resetButton.frame = NSRect(x: bar.bounds.width - 208, y: 12, width: 110, height: 30)
        resetButton.bezelStyle = .rounded
        resetButton.autoresizingMask = [.minXMargin]
        bar.addSubview(resetButton)
    }

    @objc private func sidebarSelectionChanged(_ sender: NSButton) {
        let section = SettingsSection.allCases[sender.tag]
        selectSection(section)
    }

    private func selectSection(_ section: SettingsSection) {
        currentSection = section
        for (candidate, button) in sidebarButtons {
            button.isSelectedStyle = candidate == section
        }

        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        let view = sectionViews[section] ?? buildSectionView(section)
        sectionViews[section] = view
        view.frame = contentContainer.bounds
        view.autoresizingMask = [.width, .height]
        contentContainer.addSubview(view)
    }

    private func badgeLabel(for section: SettingsSection) -> String {
        switch section {
        case .general:
            return mapping.controllerStyle == .xbox ? "Xbox" : "PS5"
        case .buttons:
            return "\(gamepadActionCount()) mapped actions"
        case .prompts:
            return "\(promptSlots.count) quick prompts"
        case .combos:
            return "\(mapping.combos.count) combos · \(mapping.comboStyle == .helldivers ? "Helldivers" : "Fighting")"
        case .speech:
            return selectedEngineType == .system ? "System speech" : "Whisper local"
        }
    }

    private func buildSectionView(_ section: SettingsSection) -> NSView {
        switch section {
        case .general:
            return buildGeneralTab()
        case .buttons:
            return buildButtonMappingTab()
        case .prompts:
            return buildPromptsTab()
        case .combos:
            return buildCombosTab()
        case .speech:
            return buildSpeechTab()
        }
    }

    // MARK: - General

    private var xboxStyleCard: ControllerStyleCard!
    private var ps5StyleCard: ControllerStyleCard!

    private func buildGeneralTab() -> NSView {
        let page = FlippedView(frame: contentContainer.bounds)
        page.autoresizingMask = [.width, .height]

        let bodyY = addPageHeader(
            to: page,
            title: SettingsSection.general.title,
            subtitle: SettingsSection.general.subtitle
        )

        // Section label
        let styleLabel = NSTextField(labelWithString: "Controller Style")
        styleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        styleLabel.textColor = .white
        styleLabel.frame = NSRect(x: pageInset, y: bodyY, width: 200, height: 20)
        page.addSubview(styleLabel)

        let styleHint = NSTextField(labelWithString: "Changes button labels and colors across all UI and overlays.")
        styleHint.font = NSFont.systemFont(ofSize: 11)
        styleHint.textColor = NSColor.white.withAlphaComponent(0.5)
        styleHint.frame = NSRect(x: pageInset, y: bodyY + 22, width: 500, height: 16)
        page.addSubview(styleHint)

        // Two side-by-side cards
        let cardsY = bodyY + 52
        let fullWidth = page.bounds.width - pageInset * 2
        let cardGap: CGFloat = 16
        let cardWidth = (fullWidth - cardGap) / 2
        let cardHeight: CGFloat = 220

        let xboxSVG = loadResourceImage(named: "xbox.svg")
        xboxStyleCard = ControllerStyleCard(
            frame: NSRect(x: pageInset, y: cardsY, width: cardWidth, height: cardHeight),
            title: "Xbox",
            subtitle: "A / B / X / Y  \u{00B7}  LB / RB / LT / RT",
            image: xboxSVG,
            selected: mapping.controllerStyle == .xbox
        )
        xboxStyleCard.autoresizingMask = [.width]
        xboxStyleCard.target = self
        xboxStyleCard.action = #selector(xboxStyleTapped)
        page.addSubview(xboxStyleCard)

        let ps5SVG = loadResourceImage(named: "ps5.svg")
        ps5StyleCard = ControllerStyleCard(
            frame: NSRect(x: pageInset + cardWidth + cardGap, y: cardsY, width: cardWidth, height: cardHeight),
            title: "PS5",
            subtitle: "\u{2715} / \u{25CB} / \u{25A1} / \u{25B3}  \u{00B7}  L1 / R1 / L2 / R2",
            image: ps5SVG,
            selected: mapping.controllerStyle == .ps5
        )
        ps5StyleCard.autoresizingMask = [.width, .minXMargin]
        ps5StyleCard.target = self
        ps5StyleCard.action = #selector(ps5StyleTapped)
        page.addSubview(ps5StyleCard)

        return page
    }

    private func loadResourceImage(named name: String) -> NSImage? {
        // Try with subdirectory first (SPM .copy layout)
        if let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Resources") {
            return NSImage(contentsOf: url)
        }
        // Fallback: forResource splits name and extension
        let parts = name.split(separator: ".", maxSplits: 1)
        if parts.count == 2,
           let url = Bundle.module.url(forResource: String(parts[0]), withExtension: String(parts[1]), subdirectory: "Resources") {
            return NSImage(contentsOf: url)
        }
        return nil
    }

    @objc private func xboxStyleTapped() {
        applyControllerStyle(.xbox)
    }

    @objc private func ps5StyleTapped() {
        applyControllerStyle(.ps5)
    }

    private func applyControllerStyle(_ style: ControllerStyle) {
        mapping.controllerStyle = style
        mapping.save()
        xboxStyleCard?.isSelectedStyle = (style == .xbox)
        ps5StyleCard?.isSelectedStyle = (style == .ps5)
        // Clear cached section views so they rebuild with new labels
        sectionViews.removeValue(forKey: .buttons)
        sectionViews.removeValue(forKey: .prompts)
        sectionViews.removeValue(forKey: .combos)
    }

    // MARK: - Button Mapping

    private func buildButtonMappingTab() -> NSView {
        let page = FlippedView(frame: contentContainer.bounds)
        page.autoresizingMask = [.width, .height]

        let bodyY = addPageHeader(
            to: page,
            title: SettingsSection.buttons.title,
            subtitle: SettingsSection.buttons.subtitle
        )

        let viewHeight = page.bounds.height - bodyY - 16
        gamepadView = GamepadConfigView(
            frame: NSRect(x: pageInset, y: bodyY, width: page.bounds.width - 2 * pageInset, height: viewHeight),
            mapping: mapping
        )
        gamepadView.autoresizingMask = [.width, .height]
        page.addSubview(gamepadView)

        return page
    }

    // MARK: - Preset Prompts

    private func buildPromptsTab() -> NSView {
        loadPromptValuesFromMapping()

        let page = FlippedView(frame: contentContainer.bounds)
        page.autoresizingMask = [.width, .height]

        let bodyY = addPageHeader(
            to: page,
            title: SettingsSection.prompts.title,
            subtitle: SettingsSection.prompts.subtitle
        )

        let listWidth: CGFloat = 282
        let splitHeight = page.bounds.height - bodyY - 12
        let splitCard = SurfaceCardView(frame: NSRect(x: pageInset, y: bodyY, width: page.bounds.width - 2 * pageInset, height: splitHeight))
        splitCard.autoresizingMask = [.width, .height]
        page.addSubview(splitCard)

        let divider = NSBox(frame: NSRect(x: listWidth + 24, y: 16, width: 1, height: splitCard.bounds.height - 32))
        divider.boxType = .separator
        divider.autoresizingMask = [.height]
        splitCard.addSubview(divider)

        let listTitle = NSTextField(labelWithString: "Quick Prompt Slots")
        listTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        listTitle.frame = NSRect(x: cardInset, y: 18, width: 140, height: 18)
        splitCard.addSubview(listTitle)

        let l = mapping.labels
        let listSubtitle = NSTextField(labelWithString: "\(l.lt) / \(l.rt) modifier combinations")
        listSubtitle.font = NSFont.systemFont(ofSize: 11)
        listSubtitle.textColor = NSColor.white.withAlphaComponent(0.58)
        listSubtitle.frame = NSRect(x: cardInset, y: 38, width: 180, height: 14)
        splitCard.addSubview(listSubtitle)

        let listScroll = NSScrollView(frame: NSRect(x: 12, y: 64, width: listWidth - 6, height: splitCard.bounds.height - 78))
        listScroll.autoresizingMask = [.width, .height]
        listScroll.drawsBackground = false
        listScroll.hasVerticalScroller = true
        splitCard.addSubview(listScroll)

        let rowsDocHeight = CGFloat(promptSlots.count) * 62 + 8
        let rowsDoc = FlippedView(frame: NSRect(x: 0, y: 0, width: listScroll.bounds.width, height: rowsDocHeight))
        listScroll.documentView = rowsDoc

        promptRows.removeAll()
        let rowStartY: CGFloat = 4
        let rowHeight: CGFloat = 50
        let rowGap: CGFloat = 8
        for (index, slot) in promptSlots.enumerated() {
            let row = PromptSlotRowView(frame: NSRect(x: 0, y: rowStartY + CGFloat(index) * (rowHeight + rowGap), width: rowsDoc.bounds.width, height: rowHeight))
            row.autoresizingMask = [.width]
            row.configure(title: slot.title, subtitle: compactPromptPreview(promptValues[slot.id] ?? ""), color: slot.color)
            row.onSelect = { [weak self] in self?.selectPromptSlot(slot.id) }
            rowsDoc.addSubview(row)
            promptRows[slot.id] = row
        }

        let editorX = listWidth + 44
        let editorWidth = splitCard.bounds.width - editorX - 18
        let previewSectionTop = splitCard.bounds.height - 92
        let previewBoxHeight: CGFloat = 52
        let editorTop: CGFloat = 188
        let editorHeight = max(116, previewSectionTop - editorTop - 16)

        promptEditorTitleLabel = NSTextField(labelWithString: "")
        promptEditorTitleLabel.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        promptEditorTitleLabel.frame = NSRect(x: editorX, y: 18, width: editorWidth - 84, height: 26)
        promptEditorTitleLabel.autoresizingMask = [.width]
        splitCard.addSubview(promptEditorTitleLabel)

        promptEditorSubtitleLabel = NSTextField(labelWithString: "")
        promptEditorSubtitleLabel.font = NSFont.systemFont(ofSize: 12)
        promptEditorSubtitleLabel.textColor = NSColor.white.withAlphaComponent(0.58)
        promptEditorSubtitleLabel.frame = NSRect(x: editorX, y: 46, width: editorWidth, height: 16)
        promptEditorSubtitleLabel.autoresizingMask = [.width]
        splitCard.addSubview(promptEditorSubtitleLabel)

        promptCountLabel = NSTextField(labelWithString: "")
        promptCountLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        promptCountLabel.textColor = NSColor.white.withAlphaComponent(0.55)
        promptCountLabel.alignment = .right
        promptCountLabel.frame = NSRect(x: splitCard.bounds.width - 82, y: 20, width: 54, height: 16)
        promptCountLabel.autoresizingMask = [.minXMargin]
        splitCard.addSubview(promptCountLabel)

        let sourceLabel = makeLabel("Preset Source")
        sourceLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        sourceLabel.frame = NSRect(x: editorX, y: 80, width: 120, height: 18)
        splitCard.addSubview(sourceLabel)

        promptSourcePopup = buildPromptSourcePopup(currentValue: promptValues[promptSlots[0].id] ?? "")
        promptSourcePopup.frame = NSRect(x: editorX, y: 104, width: min(360, editorWidth), height: 28)
        promptSourcePopup.autoresizingMask = [.maxXMargin]
        splitCard.addSubview(promptSourcePopup)

        let sourceHint = NSTextField(wrappingLabelWithString: "Choose a preset, or leave it on Custom and edit the final text directly.")
        sourceHint.font = NSFont.systemFont(ofSize: 11)
        sourceHint.textColor = NSColor.white.withAlphaComponent(0.55)
        sourceHint.frame = NSRect(x: editorX, y: 136, width: editorWidth, height: 18)
        sourceHint.autoresizingMask = [.width]
        splitCard.addSubview(sourceHint)

        let editorLabel = makeLabel("Prompt Body")
        editorLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        editorLabel.frame = NSRect(x: editorX, y: 164, width: 120, height: 18)
        splitCard.addSubview(editorLabel)

        let textScroll = NSScrollView(frame: NSRect(x: editorX, y: editorTop, width: editorWidth, height: editorHeight))
        textScroll.autoresizingMask = [.width, .height]
        textScroll.hasVerticalScroller = true
        textScroll.drawsBackground = true
        textScroll.backgroundColor = surgeWindowColor.withAlphaComponent(0.18)
        textScroll.borderType = .noBorder
        textScroll.wantsLayer = true
        textScroll.layer?.cornerRadius = 12
        textScroll.layer?.borderWidth = 1
        textScroll.layer?.borderColor = surgeDividerColor.cgColor

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: textScroll.contentSize.width, height: .greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        promptEditorTextView = NSTextView(frame: textScroll.bounds, textContainer: textContainer)
        promptEditorTextView.font = NSFont.systemFont(ofSize: 13)
        promptEditorTextView.isRichText = false
        promptEditorTextView.isAutomaticQuoteSubstitutionEnabled = false
        promptEditorTextView.isAutomaticDashSubstitutionEnabled = false
        promptEditorTextView.isAutomaticTextReplacementEnabled = false
        promptEditorTextView.backgroundColor = surgeWindowColor.withAlphaComponent(0.02)
        promptEditorTextView.textColor = .labelColor
        promptEditorTextView.insertionPointColor = .white
        promptEditorTextView.delegate = self
        textScroll.documentView = promptEditorTextView
        splitCard.addSubview(textScroll)

        let previewTitle = makeLabel("Preview")
        previewTitle.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        previewTitle.frame = NSRect(x: editorX, y: previewSectionTop, width: 120, height: 18)
        splitCard.addSubview(previewTitle)

        let previewBox = PreviewBoxView(frame: NSRect(x: editorX, y: previewSectionTop + 22, width: editorWidth, height: previewBoxHeight))
        previewBox.autoresizingMask = [.width, .minYMargin]
        splitCard.addSubview(previewBox)

        promptPreviewLabel = NSTextField(wrappingLabelWithString: "")
        promptPreviewLabel.font = NSFont.systemFont(ofSize: 12)
        promptPreviewLabel.textColor = NSColor.white.withAlphaComponent(0.70)
        promptPreviewLabel.frame = NSRect(x: editorX + 12, y: previewSectionTop + 34, width: editorWidth - 24, height: 28)
        promptPreviewLabel.autoresizingMask = [.width, .minYMargin]
        splitCard.addSubview(promptPreviewLabel)

        if let first = promptSlots.first {
            selectPromptSlot(first.id)
        }

        return page
    }

    private func loadPromptValuesFromMapping() {
        if !promptValues.isEmpty { return }
        for slot in promptSlots {
            promptValues[slot.id] = slot.currentValue(mapping)
        }
    }

    private func buildPromptSourcePopup(currentValue: String) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.font = NSFont.systemFont(ofSize: 12)
        popup.target = self
        popup.action = #selector(promptSourceChanged(_:))

        let customValueItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        customValueItem.tag = 998
        customValueItem.isHidden = true
        popup.menu?.addItem(customValueItem)

        let customItem = NSMenuItem(title: "Custom", action: nil, keyEquivalent: "")
        customItem.tag = 999
        popup.menu?.addItem(customItem)
        popup.menu?.addItem(.separator())

        for category in mapping.categories {
            let header = NSMenuItem(title: category.name, action: nil, keyEquivalent: "")
            header.isEnabled = false
            header.attributedTitle = NSAttributedString(
                string: "  \(category.name)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]
            )
            popup.menu?.addItem(header)

            for prompt in category.prompts {
                let item = NSMenuItem(title: prompt, action: nil, keyEquivalent: "")
                item.indentationLevel = 1
                popup.menu?.addItem(item)
            }
            popup.menu?.addItem(.separator())
        }

        applyPromptPopupSelection(for: currentValue, popup: popup)
        return popup
    }

    private func selectPromptSlot(_ id: String) {
        selectedPromptID = id
        for (rowID, row) in promptRows {
            row.isSelected = rowID == id
        }

        guard let slot = promptSlots.first(where: { $0.id == id }) else { return }
        let value = promptValues[id] ?? ""

        promptEditorTitleLabel.stringValue = slot.title
        promptEditorSubtitleLabel.stringValue = slot.subtitle
        promptEditorTextView.string = value
        promptPreviewLabel.stringValue = value.isEmpty ? "No prompt will be sent for this combo." : value
        promptCountLabel.stringValue = "\(value.count) chars"
        applyPromptPopupSelection(for: value, popup: promptSourcePopup)
        updatePromptRow(id)
    }

    private func updatePromptRow(_ id: String) {
        guard let row = promptRows[id] else { return }
        row.subtitle = compactPromptPreview(promptValues[id] ?? "")
    }

    @objc private func promptSourceChanged(_ sender: NSPopUpButton) {
        guard let id = selectedPromptID else { return }

        let selectedTag = sender.selectedItem?.tag ?? 0
        if selectedTag == 999 {
            let currentValue = promptValues[id] ?? promptEditorTextView.string
            applyPromptPopupSelection(for: currentValue, popup: sender)
            promptEditorTextView.window?.makeFirstResponder(promptEditorTextView)
            return
        }

        let newValue = sender.titleOfSelectedItem ?? ""
        promptValues[id] = newValue
        promptEditorTextView.string = newValue
        promptPreviewLabel.stringValue = newValue.isEmpty ? "No prompt will be sent for this combo." : newValue
        promptCountLabel.stringValue = "\(newValue.count) chars"
        updatePromptRow(id)
    }

    func textDidChange(_ notification: Notification) {
        guard notification.object as AnyObject? === promptEditorTextView,
              let id = selectedPromptID else { return }

        let value = promptEditorTextView.string
        promptValues[id] = value
        promptPreviewLabel.stringValue = value.isEmpty ? "No prompt will be sent for this combo." : value
        promptCountLabel.stringValue = "\(value.count) chars"
        applyPromptPopupSelection(for: value, popup: promptSourcePopup)
        updatePromptRow(id)
    }

    private func applyPromptPopupSelection(for value: String, popup: NSPopUpButton) {
        let allPrompts = Set(mapping.categories.flatMap(\.prompts))
        if let hiddenCustomItem = popup.menu?.items.first(where: { $0.tag == 998 }) {
            if allPrompts.contains(value), let item = popup.menu?.items.first(where: { $0.title == value }) {
                hiddenCustomItem.isHidden = true
                popup.select(item)
            } else {
                hiddenCustomItem.title = value.isEmpty ? "Custom" : value
                hiddenCustomItem.isHidden = false
                popup.select(hiddenCustomItem)
            }
        }
    }

    private func compactPromptPreview(_ value: String) -> String {
        let flattened = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return flattened.isEmpty ? "No prompt assigned" : flattened
    }

    // MARK: - Command Combos

    private var comboStylePopup: NSPopUpButton!
    private var comboTableContainer: FlippedView!

    private func buildCombosTab() -> NSView {
        let page = FlippedView(frame: contentContainer.bounds)
        page.autoresizingMask = [.width, .height]

        var y: CGFloat = pageInset

        // Header
        let header = NSTextField(labelWithString: "Command Combos")
        header.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        header.textColor = .white
        header.frame = NSRect(x: pageInset, y: y, width: 400, height: 28)
        page.addSubview(header)
        y += 28

        let cl = mapping.labels
        let subtitle = NSTextField(labelWithString: "Hold \(cl.lt)+\(cl.rt) to activate Command Mode. Input combos with D-pad (+ face buttons for Fighting style).")
        subtitle.font = NSFont.systemFont(ofSize: 12)
        subtitle.textColor = NSColor.white.withAlphaComponent(0.5)
        subtitle.frame = NSRect(x: pageInset, y: y, width: 600, height: 18)
        page.addSubview(subtitle)
        y += 30

        // Style selector card
        let styleCard = SurfaceCardView(frame: NSRect(x: pageInset, y: y, width: page.bounds.width - pageInset * 2, height: 60))
        styleCard.autoresizingMask = [.width]
        page.addSubview(styleCard)

        let styleLabel = NSTextField(labelWithString: "Combo Style")
        styleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        styleLabel.textColor = .white
        styleLabel.frame = NSRect(x: cardInset, y: 18, width: 120, height: 20)
        styleCard.addSubview(styleLabel)

        comboStylePopup = NSPopUpButton(frame: NSRect(x: cardInset + 130, y: 15, width: 260, height: 28))
        for style in ComboStyle.allCases {
            comboStylePopup.addItem(withTitle: style.rawValue)
        }
        comboStylePopup.selectItem(withTitle: mapping.comboStyle.rawValue)
        comboStylePopup.target = self
        comboStylePopup.action = #selector(comboStyleChanged(_:))
        styleCard.addSubview(comboStylePopup)
        y += 60 + pageGap

        // Combo list card
        let listCard = SurfaceCardView(frame: NSRect(x: pageInset, y: y, width: page.bounds.width - pageInset * 2, height: page.bounds.height - y - pageGap - 40))
        listCard.autoresizingMask = [.width, .height]
        page.addSubview(listCard)

        // Table header
        let headers = [("Name", cardInset, 100), ("Inputs", cardInset + 110, 160), ("Prompt", cardInset + 280, 300)]
        for (text, hx, hw) in headers {
            let h = NSTextField(labelWithString: text)
            h.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
            h.textColor = NSColor.white.withAlphaComponent(0.35)
            h.frame = NSRect(x: CGFloat(hx), y: CGFloat(cardInset), width: CGFloat(hw), height: 16)
            listCard.addSubview(h)
        }

        let addButton = NSButton(title: "+ Add Combo", target: self, action: #selector(addCombo))
        addButton.bezelStyle = .recessed
        addButton.frame = NSRect(x: listCard.bounds.width - 130, y: CGFloat(cardInset) - 4, width: 110, height: 24)
        addButton.autoresizingMask = [.minXMargin]
        listCard.addSubview(addButton)

        comboTableContainer = FlippedView(frame: NSRect(x: 0, y: CGFloat(cardInset) + 20, width: listCard.bounds.width, height: listCard.bounds.height - CGFloat(cardInset) - 20))
        comboTableContainer.autoresizingMask = [.width, .height]
        listCard.addSubview(comboTableContainer)

        rebuildComboRows()

        return page
    }

    /// Indices into `mapping.combos` for the currently selected style.
    private func filteredComboIndices() -> [Int] {
        mapping.combos.enumerated().compactMap { $0.element.style == mapping.comboStyle ? $0.offset : nil }
    }

    /// Find combos whose inputs are a prefix of, or prefixed by, the combo at the given index.
    /// Returns the names of conflicting combos (within the same style).
    private func comboPrefixConflicts(for index: Int) -> [String] {
        let combo = mapping.combos[index]
        let sameStyle = mapping.combos.enumerated().filter { $0.offset != index && $0.element.style == combo.style }
        var conflicts: [String] = []
        for (_, other) in sameStyle {
            let shorter = min(combo.inputs.count, other.inputs.count)
            if shorter > 0 &&
               Array(combo.inputs.prefix(shorter)) == Array(other.inputs.prefix(shorter)) {
                conflicts.append(other.name)
            }
        }
        return conflicts
    }

    private func rebuildComboRows() {
        comboTableContainer.subviews.forEach { $0.removeFromSuperview() }
        let rh: CGFloat = 38
        let indices = filteredComboIndices()

        for (row, comboIndex) in indices.enumerated() {
            let combo = mapping.combos[comboIndex]
            let rowY = CGFloat(row) * rh

            // Stripe
            if row % 2 == 0 {
                let bg = NSView(frame: NSRect(x: 0, y: rowY, width: comboTableContainer.bounds.width, height: rh))
                bg.wantsLayer = true
                bg.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.03).cgColor
                bg.autoresizingMask = [.width]
                comboTableContainer.addSubview(bg)
            }

            // Check prefix conflicts
            let conflicts = comboPrefixConflicts(for: comboIndex)
            let hasConflict = !conflicts.isEmpty

            // Name (editable)
            let nameField = NSTextField(string: combo.name)
            nameField.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            nameField.textColor = hasConflict ? NSColor.systemYellow : NSColor.systemOrange
            nameField.isBordered = false
            nameField.drawsBackground = false
            nameField.isEditable = true
            nameField.frame = NSRect(x: cardInset, y: rowY + 6, width: 100, height: 24)
            nameField.tag = comboIndex
            nameField.target = self
            nameField.action = #selector(comboNameEdited(_:))
            comboTableContainer.addSubview(nameField)

            // Conflict warning icon
            if hasConflict {
                let warnLabel = NSTextField(labelWithString: "⚠️")
                warnLabel.font = NSFont.systemFont(ofSize: 11)
                warnLabel.frame = NSRect(x: cardInset + 94, y: rowY + 6, width: 20, height: 24)
                warnLabel.toolTip = "Prefix conflict: \(conflicts.joined(separator: ", "))\nShorter combo fires first, longer combo can never be reached"
                comboTableContainer.addSubview(warnLabel)
            }

            // Input sequence display
            let seqDisplay = combo.inputs.map { $0.displayLabel(mapping.labels) }.joined(separator: " ")
            let seqField = NSTextField(labelWithString: seqDisplay)
            seqField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            seqField.textColor = hasConflict ? NSColor.systemYellow.withAlphaComponent(0.7) : NSColor.white.withAlphaComponent(0.7)
            seqField.frame = NSRect(x: cardInset + 110, y: rowY + 6, width: 160, height: 24)
            comboTableContainer.addSubview(seqField)

            // Edit inputs button
            let editBtn = NSButton(title: "Edit", target: self, action: #selector(editComboInputs(_:)))
            editBtn.bezelStyle = .recessed
            editBtn.tag = comboIndex
            editBtn.frame = NSRect(x: cardInset + 240, y: rowY + 7, width: 36, height: 22)
            editBtn.font = NSFont.systemFont(ofSize: 10)
            comboTableContainer.addSubview(editBtn)

            // Prompt (editable)
            let promptField = NSTextField(string: combo.prompt)
            promptField.font = NSFont.systemFont(ofSize: 12)
            promptField.textColor = .white
            promptField.isBordered = false
            promptField.drawsBackground = false
            promptField.isEditable = true
            promptField.lineBreakMode = .byTruncatingTail
            promptField.frame = NSRect(x: cardInset + 290, y: rowY + 6, width: comboTableContainer.bounds.width - cardInset - 290 - 50, height: 24)
            promptField.tag = comboIndex
            promptField.target = self
            promptField.action = #selector(comboPromptEdited(_:))
            comboTableContainer.addSubview(promptField)

            // Delete button
            let delBtn = NSButton(title: "✕", target: self, action: #selector(deleteCombo(_:)))
            delBtn.bezelStyle = .recessed
            delBtn.tag = comboIndex
            delBtn.frame = NSRect(x: comboTableContainer.bounds.width - 40, y: rowY + 7, width: 24, height: 22)
            delBtn.font = NSFont.systemFont(ofSize: 11)
            comboTableContainer.addSubview(delBtn)
        }
    }

    @objc private func comboStyleChanged(_ sender: NSPopUpButton) {
        if let title = sender.selectedItem?.title,
           let style = ComboStyle.allCases.first(where: { $0.rawValue == title }) {
            mapping.comboStyle = style
            rebuildComboRows()
        }
    }

    @objc private func comboNameEdited(_ sender: NSTextField) {
        let i = sender.tag
        guard i >= 0, i < mapping.combos.count else { return }
        mapping.combos[i].name = sender.stringValue
    }

    @objc private func comboPromptEdited(_ sender: NSTextField) {
        let i = sender.tag
        guard i >= 0, i < mapping.combos.count else { return }
        mapping.combos[i].prompt = sender.stringValue
    }

    @objc private func addCombo() {
        let style = mapping.comboStyle
        let defaultInputs: [ComboInput] = style == .helldivers ? [.up, .down, .up] : [.down, .right, .a]
        mapping.combos.append(ComboEntry(name: "New Combo", inputs: defaultInputs, prompt: "your prompt here", style: style))
        rebuildComboRows()
    }

    @objc private func deleteCombo(_ sender: NSButton) {
        let i = sender.tag
        guard i >= 0, i < mapping.combos.count else { return }
        mapping.combos.remove(at: i)
        rebuildComboRows()
    }

    @objc private func editComboInputs(_ sender: NSButton) {
        let i = sender.tag
        guard i >= 0, i < mapping.combos.count else { return }

        let editor = ComboInputEditor(
            inputs: mapping.combos[i].inputs,
            name: mapping.combos[i].name,
            isFighting: mapping.comboStyle == .fighting,
            labels: mapping.labels
        )
        guard let window = sender.window else { return }
        window.beginSheet(editor.window!) { response in
            if response == .OK, !editor.inputs.isEmpty {
                self.mapping.combos[i].inputs = editor.inputs
                self.rebuildComboRows()
            }
        }
    }

    // MARK: - Speech

    private func buildSpeechTab() -> NSView {
        let page = FlippedView(frame: contentContainer.bounds)
        page.autoresizingMask = [.width, .height]
        speechSummaryLabels.removeAll()
        whisperManagedControls.removeAll()
        llmManagedControls.removeAll()

        let bodyY = addPageHeader(
            to: page,
            title: SettingsSection.speech.title,
            subtitle: SettingsSection.speech.subtitle
        )

        let fullWidth = page.bounds.width - 2 * pageInset

        let summaryCard = SurfaceCardView(frame: NSRect(x: pageInset, y: bodyY, width: fullWidth, height: 112))
        summaryCard.autoresizingMask = [.width]
        page.addSubview(summaryCard)

        let summaryTitle = NSTextField(labelWithString: "Voice Pipeline")
        summaryTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        summaryTitle.frame = NSRect(x: cardInset, y: 16, width: 180, height: 18)
        summaryCard.addSubview(summaryTitle)

        let summarySubtitle = NSTextField(labelWithString: "Current runtime status")
        summarySubtitle.font = NSFont.systemFont(ofSize: 11)
        summarySubtitle.textColor = .secondaryLabelColor
        summarySubtitle.frame = NSRect(x: cardInset, y: 36, width: 160, height: 14)
        summaryCard.addSubview(summarySubtitle)

        let metricTitles = [
            ("engine", "Engine"),
            ("binary", "Binary"),
            ("model", "Model"),
            ("llm", "LLM Cleanup"),
        ]
        let metricWidth = (summaryCard.bounds.width - 2 * cardInset) / CGFloat(metricTitles.count)
        for (index, metric) in metricTitles.enumerated() {
            let x = cardInset + CGFloat(index) * metricWidth
            let caption = NSTextField(labelWithString: metric.1)
            caption.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            caption.textColor = .secondaryLabelColor
            caption.frame = NSRect(x: x, y: 62, width: metricWidth - 12, height: 14)
            caption.autoresizingMask = [.maxXMargin]
            summaryCard.addSubview(caption)

            let valueLabel = NSTextField(labelWithString: "")
            valueLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
            valueLabel.frame = NSRect(x: x, y: 80, width: metricWidth - 12, height: 20)
            valueLabel.autoresizingMask = [.maxXMargin]
            summaryCard.addSubview(valueLabel)
            speechSummaryLabels[metric.0] = valueLabel
        }

        let engineCardY = summaryCard.frame.maxY + 14
        let engineCard = SurfaceCardView(frame: NSRect(x: pageInset, y: engineCardY, width: fullWidth, height: 88))
        engineCard.autoresizingMask = [.width]
        page.addSubview(engineCard)

        addCardTitle("Speech Engine", to: engineCard)

        let engineLabel = makeLabel("Active Engine")
        engineLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        engineLabel.frame = NSRect(x: cardInset, y: 38, width: labelWidth, height: 18)
        engineCard.addSubview(engineLabel)

        enginePopup = NSPopUpButton(frame: NSRect(x: labelWidth + cardInset, y: 34, width: 280, height: 28), pullsDown: false)
        enginePopup.font = NSFont.systemFont(ofSize: 12)
        for type in SpeechEngineType.allCases {
            enginePopup.addItem(withTitle: type.rawValue)
        }
        enginePopup.selectItem(withTitle: speechSettings.engineType.rawValue)
        enginePopup.target = self
        enginePopup.action = #selector(engineSelectionChanged)
        engineCard.addSubview(enginePopup)

        let lowerY = engineCard.frame.maxY + 14
        let lowerGap: CGFloat = 14
        let columnWidth = (fullWidth - lowerGap) / 2
        let lowerHeight = max(238, page.bounds.height - lowerY - pageInset)
        whisperCard = SurfaceCardView(frame: NSRect(x: pageInset, y: lowerY, width: columnWidth, height: lowerHeight))
        whisperCard.autoresizingMask = [.width, .height]
        page.addSubview(whisperCard)

        addCardTitle("Whisper Local", to: whisperCard)

        var whisperY: CGFloat = 40

        let modelLabel = makeLabel("Model")
        modelLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        modelLabel.frame = NSRect(x: cardInset, y: whisperY + 3, width: labelWidth, height: 18)
        whisperCard.addSubview(modelLabel)

        whisperModelPopup = NSPopUpButton(frame: NSRect(x: labelWidth + cardInset, y: whisperY, width: whisperCard.bounds.width - labelWidth - 2 * cardInset, height: 28), pullsDown: false)
        whisperModelPopup.autoresizingMask = [.width]
        whisperModelPopup.font = NSFont.systemFont(ofSize: 11)
        whisperModelPopup.target = self
        whisperModelPopup.action = #selector(modelSelectionChanged)
        let models: [(String, String)] = [
            ("ggml-tiny.bin", "75 MB · fastest"),
            ("ggml-base.bin", "142 MB · good default"),
            ("ggml-small.bin", "466 MB · balanced"),
            ("ggml-medium.bin", "1.5 GB · high quality"),
            ("ggml-large-v3.bin", "3.1 GB · best quality"),
        ]
        for (file, desc) in models {
            whisperModelPopup.addItem(withTitle: "\(file)  (\(desc))")
            whisperModelPopup.lastItem?.representedObject = file
        }
        if let index = models.firstIndex(where: { $0.0 == speechSettings.whisperModel }) {
            whisperModelPopup.selectItem(at: index)
        }
        whisperCard.addSubview(whisperModelPopup)
        whisperManagedControls.append(whisperModelPopup)
        whisperY += rowHeight + 6

        let binaryLabel = makeLabel("Binary")
        binaryLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        binaryLabel.frame = NSRect(x: cardInset, y: whisperY + 3, width: labelWidth, height: 18)
        whisperCard.addSubview(binaryLabel)

        whisperInstallButton = NSButton(title: "Install whisper-cpp", target: self, action: #selector(installWhisperCpp))
        whisperInstallButton.frame = NSRect(x: labelWidth + cardInset, y: whisperY, width: 180, height: 28)
        whisperInstallButton.bezelStyle = .rounded
        whisperCard.addSubview(whisperInstallButton)
        whisperManagedControls.append(whisperInstallButton)
        whisperY += rowHeight + 4

        let modelFileLabel = makeLabel("Model File")
        modelFileLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        modelFileLabel.frame = NSRect(x: cardInset, y: whisperY + 3, width: labelWidth, height: 18)
        whisperCard.addSubview(modelFileLabel)

        whisperDownloadButton = NSButton(title: "Download Model", target: self, action: #selector(downloadWhisperModel))
        whisperDownloadButton.frame = NSRect(x: labelWidth + cardInset, y: whisperY, width: 132, height: 28)
        whisperDownloadButton.bezelStyle = .rounded
        whisperCard.addSubview(whisperDownloadButton)
        whisperManagedControls.append(whisperDownloadButton)

        whisperProgressBar = NSProgressIndicator(frame: NSRect(x: labelWidth + cardInset + 144, y: whisperY + 6, width: 250, height: 16))
        whisperProgressBar.style = .bar
        whisperProgressBar.minValue = 0
        whisperProgressBar.maxValue = 1
        whisperProgressBar.isHidden = true
        whisperCard.addSubview(whisperProgressBar)
        whisperY += rowHeight + 6

        whisperStatusLabel = NSTextField(labelWithString: "")
        whisperStatusLabel.font = NSFont.systemFont(ofSize: 11)
        whisperStatusLabel.textColor = .secondaryLabelColor
        whisperStatusLabel.frame = NSRect(x: cardInset, y: whisperCard.bounds.height - 38, width: whisperCard.bounds.width - 2 * cardInset, height: 28)
        whisperStatusLabel.autoresizingMask = [.width]
        whisperCard.addSubview(whisperStatusLabel)

        llmCard = SurfaceCardView(frame: NSRect(x: pageInset + columnWidth + lowerGap, y: lowerY, width: columnWidth, height: lowerHeight))
        llmCard.autoresizingMask = [.minXMargin, .width, .height]
        page.addSubview(llmCard)

        addCardTitle("LLM Refinement", to: llmCard)

        var llmY: CGFloat = 40
        let enabledLabel = makeLabel("Enabled")
        enabledLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        enabledLabel.frame = NSRect(x: cardInset, y: llmY + 3, width: labelWidth, height: 18)
        llmCard.addSubview(enabledLabel)

        llmCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(llmCheckboxChanged))
        llmCheckbox.frame = NSRect(x: labelWidth + cardInset, y: llmY + 2, width: 24, height: 24)
        llmCheckbox.state = speechSettings.llmEnabled ? .on : .off
        llmCard.addSubview(llmCheckbox)
        llmY += rowHeight + 2

        addFormLabel("API URL", y: llmY, card: llmCard)
        llmURLField = NSTextField(string: speechSettings.llmAPIURL)
        llmURLField.frame = NSRect(x: labelWidth + cardInset, y: llmY, width: llmCard.bounds.width - labelWidth - 2 * cardInset, height: 26)
        llmURLField.autoresizingMask = [.width]
        llmURLField.placeholderString = "http://localhost:11434/v1"
        llmCard.addSubview(llmURLField)
        llmManagedControls.append(llmURLField)
        llmY += rowHeight + 2

        addFormLabel("API Key", y: llmY, card: llmCard)
        llmKeyField = NSSecureTextField(string: speechSettings.llmAPIKey)
        llmKeyField.frame = NSRect(x: labelWidth + cardInset, y: llmY, width: llmCard.bounds.width - labelWidth - 2 * cardInset, height: 26)
        llmKeyField.autoresizingMask = [.width]
        llmKeyField.placeholderString = "Leave empty for Ollama"
        llmCard.addSubview(llmKeyField)
        llmManagedControls.append(llmKeyField)
        llmY += rowHeight + 2

        addFormLabel("Model", y: llmY, card: llmCard)
        llmModelField = NSTextField(string: speechSettings.llmModel)
        let llmFieldWidth = llmCard.bounds.width - labelWidth - 2 * cardInset
        llmModelField.frame = NSRect(x: labelWidth + cardInset, y: llmY, width: min(200, llmFieldWidth), height: 26)
        llmModelField.placeholderString = "qwen2.5:7b"
        llmModelField.autoresizingMask = [.maxXMargin]
        llmCard.addSubview(llmModelField)
        llmManagedControls.append(llmModelField)

        let llmHint = NSTextField(wrappingLabelWithString: "Works with Ollama, LM Studio, or any OpenAI-compatible endpoint.")
        llmHint.font = NSFont.systemFont(ofSize: 11)
        llmHint.textColor = .secondaryLabelColor
        llmHint.frame = NSRect(x: labelWidth + cardInset, y: llmY + 30, width: llmFieldWidth, height: 28)
        llmHint.autoresizingMask = [.width]
        llmCard.addSubview(llmHint)

        updateWhisperStatus()
        updateSpeechUIState()
        return page
    }

    private func addCardTitle(_ title: String, subtitle: String? = nil, to card: NSView) {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.frame = NSRect(x: cardInset, y: 16, width: 180, height: 18)
        card.addSubview(titleLabel)

        guard let subtitle, !subtitle.isEmpty else { return }

        let subtitleLabel = NSTextField(wrappingLabelWithString: subtitle)
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: cardInset, y: 34, width: card.bounds.width - 2 * cardInset, height: 16)
        subtitleLabel.autoresizingMask = [.width]
        card.addSubview(subtitleLabel)
    }

    private func addFormLabel(_ text: String, y: CGFloat, card: NSView) {
        let label = makeLabel(text)
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.frame = NSRect(x: cardInset, y: y + 3, width: labelWidth, height: 18)
        card.addSubview(label)
    }

    @objc private func engineSelectionChanged() {
        updateSpeechUIState()
    }

    @objc private func llmCheckboxChanged() {
        updateSpeechUIState()
    }

    private var selectedEngineType: SpeechEngineType {
        guard let title = enginePopup?.titleOfSelectedItem,
              let engine = SpeechEngineType.allCases.first(where: { $0.rawValue == title }) else {
            return speechSettings.engineType
        }
        return engine
    }

    private var selectedModelName: String {
        whisperModelPopup?.selectedItem?.representedObject as? String ?? speechSettings.whisperModel
    }

    private var currentLLMEnabled: Bool {
        if let llmCheckbox {
            return llmCheckbox.state == .on
        }
        return speechSettings.llmEnabled
    }

    private var currentLLMAPIURL: String {
        llmURLField?.stringValue ?? speechSettings.llmAPIURL
    }

    private var currentLLMAPIKey: String {
        llmKeyField?.stringValue ?? speechSettings.llmAPIKey
    }

    private var currentLLMModel: String {
        llmModelField?.stringValue ?? speechSettings.llmModel
    }

    @objc private func modelSelectionChanged() {
        updateWhisperStatus()
        updateSpeechUIState()
    }

    private func updateSpeechUIState() {
        let usingWhisper = selectedEngineType == .whisperLocal
        for control in whisperManagedControls {
            control.isEnabled = usingWhisper
        }
        whisperCard.alphaValue = usingWhisper ? 1.0 : 0.58

        let llmEnabled = currentLLMEnabled
        for control in llmManagedControls {
            control.isEnabled = llmEnabled
        }
        llmCard.alphaValue = llmEnabled ? 1.0 : 0.66

        updateSpeechSummary()
    }

    private func updateSpeechSummary() {
        let whisper = WhisperEngine.shared
        whisper.modelName = selectedModelName

        speechSummaryLabels["engine"]?.stringValue = selectedEngineType == .system ? "System" : "Whisper"
        speechSummaryLabels["binary"]?.stringValue = whisper.hasBinary ? "Installed" : "Missing"
        speechSummaryLabels["binary"]?.textColor = whisper.hasBinary ? .systemGreen : .systemOrange
        speechSummaryLabels["model"]?.stringValue = whisper.hasModel ? "Ready" : "Not downloaded"
        speechSummaryLabels["model"]?.textColor = whisper.hasModel ? .systemGreen : .systemOrange
        speechSummaryLabels["llm"]?.stringValue = currentLLMEnabled ? (currentLLMModel.isEmpty ? "Enabled" : currentLLMModel) : "Off"
        speechSummaryLabels["llm"]?.textColor = currentLLMEnabled ? .controlAccentColor : .secondaryLabelColor

    }

    private func updateWhisperStatus() {
        let whisper = WhisperEngine.shared
        whisper.modelName = selectedModelName

        var parts: [String] = []
        if whisper.hasBinary {
            parts.append("binary installed")
            whisperInstallButton.isEnabled = false
            whisperInstallButton.title = "Installed"
        } else {
            parts.append("binary missing")
            whisperInstallButton.isEnabled = true
            whisperInstallButton.title = "Install whisper-cpp"
        }

        if whisper.hasModel {
            parts.append("model ready")
            whisperDownloadButton.isEnabled = false
            whisperDownloadButton.title = "Ready"
        } else {
            parts.append("model missing")
            whisperDownloadButton.isEnabled = true
            whisperDownloadButton.title = "Download Model"
        }

        let allGood = whisper.hasBinary && whisper.hasModel
        whisperStatusLabel.stringValue = (allGood ? "Ready" : "Attention needed") + "  •  " + parts.joined(separator: "  •  ")
        whisperStatusLabel.textColor = allGood ? .systemGreen : .secondaryLabelColor
    }

    @objc private func installWhisperCpp() {
        whisperInstallButton.isEnabled = false
        whisperInstallButton.title = "Installing..."
        whisperStatusLabel.stringValue = "Installing whisper.cpp via Homebrew..."
        whisperStatusLabel.textColor = .secondaryLabelColor

        WhisperEngine.shared.installBinary { [weak self] ok, message in
            self?.whisperStatusLabel.stringValue = ok ? "Ready  •  \(message)" : "Error  •  \(message)"
            self?.whisperStatusLabel.textColor = ok ? .systemGreen : .systemRed
            self?.updateWhisperStatus()
            self?.updateSpeechUIState()
        }
    }

    @objc private func downloadWhisperModel() {
        let whisper = WhisperEngine.shared
        whisper.modelName = selectedModelName
        whisperDownloadButton.isEnabled = false
        whisperDownloadButton.title = "Downloading..."
        whisperProgressBar.isHidden = false
        whisperProgressBar.doubleValue = 0

        whisper.downloadModel(
            onProgress: { [weak self] progress in
                self?.whisperProgressBar.doubleValue = progress
                self?.whisperStatusLabel.stringValue = "Downloading model... \(Int(progress * 100))%"
                self?.whisperStatusLabel.textColor = .secondaryLabelColor
            },
            onComplete: { [weak self] ok, message in
                self?.whisperProgressBar.isHidden = true
                self?.whisperStatusLabel.stringValue = ok ? "Ready  •  \(message)" : "Error  •  \(message)"
                self?.whisperStatusLabel.textColor = ok ? .systemGreen : .systemRed
                self?.updateWhisperStatus()
                self?.updateSpeechUIState()
            }
        )
    }

    // MARK: - Persistence

    @objc private func saveSettings() {
        mapping.buttonActions = ButtonMapping.ButtonActions(
            a: gamepadView.actionForSlot("a"),
            b: gamepadView.actionForSlot("b"),
            x: gamepadView.actionForSlot("x"),
            y: gamepadView.actionForSlot("y"),
            lb: gamepadView.actionForSlot("lb"),
            rb: gamepadView.actionForSlot("rb"),
            start: gamepadView.actionForSlot("start"),
            select: gamepadView.actionForSlot("select"),
            stickClick: gamepadView.actionForSlot("stickL"),
            dpadUp: gamepadView.actionForSlot("dpadUp"),
            dpadDown: gamepadView.actionForSlot("dpadDown"),
            dpadLeft: gamepadView.actionForSlot("dpadLeft"),
            dpadRight: gamepadView.actionForSlot("dpadRight")
        )
        mapping.guideKeyCombo = gamepadView.guideKeyCombo
        mapping.presetPrompts = mapping.allPrompts
        mapping.ltPrompts = ButtonMapping.QuickPrompts(
            a: promptValues["lt.a"] ?? mapping.ltPrompts.a,
            b: promptValues["lt.b"] ?? mapping.ltPrompts.b,
            x: promptValues["lt.x"] ?? mapping.ltPrompts.x,
            y: promptValues["lt.y"] ?? mapping.ltPrompts.y
        )
        mapping.rtPrompts = ButtonMapping.QuickPrompts(
            a: promptValues["rt.a"] ?? mapping.rtPrompts.a,
            b: promptValues["rt.b"] ?? mapping.rtPrompts.b,
            x: promptValues["rt.x"] ?? mapping.rtPrompts.x,
            y: promptValues["rt.y"] ?? mapping.rtPrompts.y
        )
        mapping.save()

        speechSettings.engineType = selectedEngineType
        speechSettings.whisperModel = selectedModelName
        speechSettings.llmEnabled = currentLLMEnabled
        speechSettings.llmAPIURL = currentLLMAPIURL
        speechSettings.llmAPIKey = currentLLMAPIKey
        speechSettings.llmModel = currentLLMModel
        speechSettings.save()

        GamepadManager.shared.reloadMapping()
        GamepadManager.shared.reloadSpeechSettings()
        window?.close()
    }

    @objc private func resetDefaults() {
        mapping = .default
        speechSettings = .default
        promptValues.removeAll()
        promptRows.removeAll()
        sectionViews.removeAll()
        sidebarButtons.removeAll()
        speechSummaryLabels.removeAll()
        whisperManagedControls.removeAll()
        llmManagedControls.removeAll()
        setupUI()
    }

    private func gamepadActionCount() -> Int {
        let actions = mapping.buttonActions
        return [
            actions.a, actions.b, actions.x, actions.y,
            actions.lb, actions.rb, actions.start, actions.select,
            actions.stickClick, actions.dpadUp, actions.dpadDown,
            actions.dpadLeft, actions.dpadRight,
        ].filter { $0 != .none }.count
    }

    @discardableResult
    private func addPageHeader(to parent: NSView, title: String, subtitle: String) -> CGFloat {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 28, weight: .semibold)
        titleLabel.frame = NSRect(x: pageInset, y: pageInset - 2, width: 360, height: 34)
        parent.addSubview(titleLabel)

        let subtitleLabel = NSTextField(wrappingLabelWithString: subtitle)
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.52)
        subtitleLabel.frame = NSRect(x: pageInset, y: pageInset + 36, width: min(640, parent.bounds.width - 2 * pageInset), height: 18)
        subtitleLabel.autoresizingMask = [.width]
        parent.addSubview(subtitleLabel)

        let separator = NSBox(frame: NSRect(x: pageInset, y: pageInset + 68, width: parent.bounds.width - 2 * pageInset, height: 1))
        separator.boxType = .separator
        separator.autoresizingMask = [.width]
        parent.addSubview(separator)

        return pageInset + 84
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13)
        label.textColor = .labelColor
        return label
    }
}

// MARK: - Shared Views

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Combo Input Editor (button-based)

private final class ComboInputEditor: NSObject {
    private(set) var inputs: [ComboInput]
    private let sheetWindow: NSWindow
    private let sequenceLabel: NSTextField
    private let isFighting: Bool
    private let labels: ControllerLabels

    var window: NSWindow? { sheetWindow }

    init(inputs: [ComboInput], name: String, isFighting: Bool, labels: ControllerLabels) {
        self.inputs = inputs
        self.isFighting = isFighting
        self.labels = labels

        // Layout constants
        let bs: CGFloat = 50       // button size
        let gap: CGFloat = 6       // gap between buttons
        let pad: CGFloat = 20      // outer padding
        let seqH: CGFloat = 40     // sequence display height
        let barH: CGFloat = 32     // bottom bar height
        let secGap: CGFloat = 14   // gap between sections

        // D-pad cross: 3 wide × 2 tall
        let dpadW = bs * 3 + gap * 2  // 162

        // Face buttons Xbox diamond: 3 tall × 3 wide (fighting only)
        // faceW = 3*bs + 2*gap = 162, faceH = 3*bs + 2*gap = 162
        let btnAreaH: CGFloat = isFighting
            ? bs * 3 + gap * 2   // 162 — diamond needs 3 rows
            : bs * 2 + gap       // 106 — D-pad only needs 2 rows

        // Window size — minimum width must fit the bottom bar (⌫ + Clear + Cancel + Save)
        let barMinW = pad + 40 + 6 + 50 + 20 + 70 + 6 + 64 + pad  // 296
        let w: CGFloat = isFighting
            ? pad + dpadW + pad + dpadW + pad    // 384
            : pad + dpadW + pad                  // 202
        let winW = max(w, barMinW)
        let winH = pad + seqH + secGap + btnAreaH + secGap + barH + pad

        sheetWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: winW, height: winH),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        sheetWindow.title = "Edit: \(name)"
        sheetWindow.backgroundColor = surgeWindowColor

        let content = NSView(frame: NSRect(x: 0, y: 0, width: winW, height: winH))
        content.wantsLayer = true
        sheetWindow.contentView = content

        // Current sequence display (top)
        sequenceLabel = NSTextField(labelWithString: "")
        sequenceLabel.font = NSFont.monospacedSystemFont(ofSize: 18, weight: .medium)
        sequenceLabel.textColor = .white
        sequenceLabel.alignment = .center
        sequenceLabel.lineBreakMode = .byTruncatingHead
        sequenceLabel.frame = NSRect(x: pad, y: winH - pad - seqH, width: winW - pad * 2, height: seqH)
        content.addSubview(sequenceLabel)

        super.init()
        updateDisplay()

        // Button area origin (bottom of button region)
        let btnAreaBottom = pad + barH + secGap
        let dpadH = bs * 2 + gap  // 106
        let dpadX = pad
        // Vertically center D-pad within button area
        let dpadY = btnAreaBottom + (btnAreaH - dpadH) / 2

        // D-pad cross layout:
        //      [↑]
        // [←] [↓] [→]
        let dpadButtons: [(ComboInput, CGFloat, CGFloat)] = [
            (.up,    dpadX + bs + gap,         dpadY + bs + gap),  // top center
            (.left,  dpadX,                    dpadY),             // bottom left
            (.down,  dpadX + bs + gap,         dpadY),             // bottom center
            (.right, dpadX + (bs + gap) * 2,   dpadY),             // bottom right
        ]

        for (input, bx, by) in dpadButtons {
            let btn = makeInputButton(input.rawValue, size: bs)
            btn.frame.origin = NSPoint(x: bx, y: by)
            btn.tag = ComboInput.allCases.firstIndex(of: input)!
            btn.target = self
            btn.action = #selector(inputTapped(_:))
            content.addSubview(btn)
        }

        // Face buttons (fighting style only) — Xbox diamond layout:
        //      [Y]
        //  [X]     [B]
        //      [A]
        if isFighting {
            let faceX = pad + dpadW + pad
            let faceY = btnAreaBottom

            let faceButtons: [(ComboInput, CGFloat, CGFloat)] = [
                (.y, faceX + bs + gap,         faceY + (bs + gap) * 2), // top
                (.x, faceX,                    faceY + bs + gap),       // left
                (.b, faceX + (bs + gap) * 2,   faceY + bs + gap),       // right
                (.a, faceX + bs + gap,         faceY),                  // bottom
            ]

            for (input, bx, by) in faceButtons {
                let btn = makeInputButton(input.displayLabel(labels), size: bs)
                btn.frame.origin = NSPoint(x: bx, y: by)
                btn.tag = ComboInput.allCases.firstIndex(of: input)!
                btn.target = self
                btn.action = #selector(inputTapped(_:))
                content.addSubview(btn)
            }
        }

        // Bottom bar: ⌫, Clear, Cancel, Save
        let barY: CGFloat = pad

        let backBtn = NSButton(title: "⌫", target: self, action: #selector(backspace))
        backBtn.bezelStyle = .recessed
        backBtn.font = NSFont.systemFont(ofSize: 14)
        backBtn.frame = NSRect(x: pad, y: barY, width: 40, height: barH)
        content.addSubview(backBtn)

        let clearBtn = NSButton(title: "Clear", target: self, action: #selector(clearAll))
        clearBtn.bezelStyle = .recessed
        clearBtn.font = NSFont.systemFont(ofSize: 11)
        clearBtn.frame = NSRect(x: pad + 46, y: barY, width: 50, height: barH)
        content.addSubview(clearBtn)

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.font = NSFont.systemFont(ofSize: 12)
        cancelBtn.frame = NSRect(x: winW - 160, y: barY, width: 70, height: barH)
        cancelBtn.keyEquivalent = "\u{1b}" // Escape
        content.addSubview(cancelBtn)

        let saveBtn = NSButton(title: "Save", target: self, action: #selector(save))
        saveBtn.bezelStyle = .rounded
        saveBtn.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        saveBtn.frame = NSRect(x: winW - 84, y: barY, width: 64, height: barH)
        saveBtn.keyEquivalent = "\r"
        saveBtn.contentTintColor = .white
        saveBtn.bezelColor = .systemBlue
        content.addSubview(saveBtn)
    }

    private func makeInputButton(_ title: String, size: CGFloat) -> NSButton {
        let btn = NSButton(frame: NSRect(x: 0, y: 0, width: size, height: size))
        btn.title = title
        btn.bezelStyle = .regularSquare
        btn.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        btn.isBordered = true
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 8
        return btn
    }

    private func updateDisplay() {
        if inputs.isEmpty {
            sequenceLabel.stringValue = "(empty)"
            sequenceLabel.textColor = NSColor.white.withAlphaComponent(0.3)
        } else {
            sequenceLabel.stringValue = inputs.map { $0.displayLabel(labels) }.joined(separator: "  ")
            sequenceLabel.textColor = .white
        }
    }

    @objc private func inputTapped(_ sender: NSButton) {
        let input = ComboInput.allCases[sender.tag]
        inputs.append(input)
        updateDisplay()
    }

    @objc private func backspace() {
        guard !inputs.isEmpty else { return }
        inputs.removeLast()
        updateDisplay()
    }

    @objc private func clearAll() {
        inputs = []
        updateDisplay()
    }

    @objc private func cancel() {
        sheetWindow.sheetParent?.endSheet(sheetWindow, returnCode: .cancel)
    }

    @objc private func save() {
        sheetWindow.sheetParent?.endSheet(sheetWindow, returnCode: .OK)
    }
}

private final class SurfaceCardView: FlippedView {
    init(frame: NSRect, emphasis: Bool = false) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = surgeCardColor.withAlphaComponent(emphasis ? 0.96 : 0.90).cgColor
        layer?.cornerRadius = emphasis ? 18 : 16
        layer?.borderWidth = 1
        layer?.borderColor = surgeDividerColor.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }
}

private final class SidebarSelectionButton: NSButton {
    private let iconView = NSImageView(frame: .zero)
    private let titleLabel = NSTextField(labelWithString: "")
    private let symbolName: String

    var isSelectedStyle = false {
        didSet { applyStyle() }
    }

    init(title: String, symbolName: String) {
        self.symbolName = symbolName
        super.init(frame: .zero)
        self.title = ""
        bezelStyle = .regularSquare
        isBordered = false
        setButtonType(.momentaryChange)
        imagePosition = .noImage
        wantsLayer = true
        layer?.cornerRadius = 12

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig)
        iconView.imageScaling = .scaleProportionallyDown
        addSubview(iconView)

        titleLabel.stringValue = title
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)

        applyStyle()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        let midY = bounds.height / 2
        iconView.frame = NSRect(x: 14, y: midY - 8, width: 16, height: 16)
        titleLabel.sizeToFit()
        titleLabel.frame = NSRect(x: 38, y: midY - titleLabel.frame.height / 2, width: bounds.width - 50, height: titleLabel.frame.height)
    }

    private func applyStyle() {
        layer?.backgroundColor = (isSelectedStyle ? NSColor.white.withAlphaComponent(0.12) : NSColor.clear).cgColor
        titleLabel.textColor = isSelectedStyle ? .white : NSColor.white.withAlphaComponent(0.78)
        iconView.contentTintColor = isSelectedStyle ? .white : NSColor.white.withAlphaComponent(0.72)
    }
}

private final class PromptSlotRowView: FlippedView {
    private let dotView = NSView(frame: .zero)
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    var onSelect: (() -> Void)?

    var isSelected = false {
        didSet { updateStyle() }
    }

    var subtitle: String {
        get { subtitleLabel.stringValue }
        set { subtitleLabel.stringValue = newValue }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = surgeDividerColor.cgColor

        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 4
        dotView.frame = NSRect(x: 14, y: 18, width: 8, height: 8)
        addSubview(dotView)

        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.frame = NSRect(x: 32, y: 11, width: frameRect.width - 46, height: 18)
        titleLabel.autoresizingMask = [.width]
        addSubview(titleLabel)

        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.frame = NSRect(x: 32, y: 29, width: frameRect.width - 46, height: 14)
        subtitleLabel.autoresizingMask = [.width]
        addSubview(subtitleLabel)

        updateStyle()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, subtitle: String, color: NSColor) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        dotView.layer?.backgroundColor = color.cgColor
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?()
    }

    private func updateStyle() {
        layer?.backgroundColor = (isSelected ? surgeSelectionColor : NSColor.white.withAlphaComponent(0.03)).cgColor
        layer?.borderColor = (isSelected ? NSColor.white.withAlphaComponent(0.10) : surgeDividerColor).cgColor
    }
}

private final class PreviewBoxView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        surgeWindowColor.withAlphaComponent(0.22).setFill()
        path.fill()
        surgeDividerColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

// MARK: - Controller Style Card

private let styleCardSelectedBorder = NSColor(red: 0.35, green: 0.55, blue: 1.0, alpha: 1.0)

private final class ControllerStyleCard: NSButton {
    private let imageView = NSImageView(frame: .zero)
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let checkmarkView = NSImageView(frame: .zero)

    var isSelectedStyle: Bool = false {
        didSet { applyStyle() }
    }

    init(frame: NSRect, title: String, subtitle: String, image: NSImage?, selected: Bool) {
        super.init(frame: frame)
        self.title = ""
        bezelStyle = .regularSquare
        isBordered = false
        setButtonType(.momentaryChange)
        imagePosition = .noImage
        wantsLayer = true
        layer?.cornerRadius = 16

        // Controller image
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyDown
        imageView.imageAlignment = .alignCenter
        addSubview(imageView)

        // Title
        titleLabel.stringValue = title
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.drawsBackground = false
        addSubview(titleLabel)

        // Subtitle (button labels preview)
        subtitleLabel.stringValue = subtitle
        subtitleLabel.font = NSFont.systemFont(ofSize: 10)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.45)
        subtitleLabel.alignment = .center
        subtitleLabel.isBezeled = false
        subtitleLabel.isEditable = false
        subtitleLabel.drawsBackground = false
        addSubview(subtitleLabel)

        // Checkmark indicator
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        checkmarkView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig)
        checkmarkView.contentTintColor = styleCardSelectedBorder
        addSubview(checkmarkView)

        isSelectedStyle = selected
        applyStyle()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height

        // Image area: top portion
        let imageTop: CGFloat = 16
        let imageHeight = h - 80
        imageView.frame = NSRect(x: 20, y: imageTop, width: w - 40, height: imageHeight)

        // Title below image
        let titleY = imageTop + imageHeight + 8
        titleLabel.frame = NSRect(x: 0, y: titleY, width: w, height: 22)

        // Subtitle below title
        subtitleLabel.frame = NSRect(x: 0, y: titleY + 22, width: w, height: 16)

        // Checkmark in top-right corner
        checkmarkView.frame = NSRect(x: w - 30, y: 10, width: 20, height: 20)
    }

    private func applyStyle() {
        if isSelectedStyle {
            layer?.backgroundColor = surgeCardColor.withAlphaComponent(0.96).cgColor
            layer?.borderWidth = 2
            layer?.borderColor = styleCardSelectedBorder.cgColor
            checkmarkView.isHidden = false
        } else {
            layer?.backgroundColor = surgeCardColor.withAlphaComponent(0.60).cgColor
            layer?.borderWidth = 1
            layer?.borderColor = surgeDividerColor.cgColor
            checkmarkView.isHidden = true
        }
    }

    override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        return super.sendAction(action, to: target)
    }
}

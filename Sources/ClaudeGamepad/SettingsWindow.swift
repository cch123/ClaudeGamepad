import AppKit

/// Settings window with three tabs, using consistent card-based form design.
final class SettingsWindow: NSWindowController {
    private var mapping = ButtonMapping.load()
    private var speechSettings = SpeechSettings.load()

    private var gamepadView: GamepadConfigView!
    private var presetFields: [NSTextField] = []
    private var ltFields: [String: NSTextField] = [:]
    private var rtFields: [String: NSTextField] = [:]

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

    // Layout constants
    private let cardInset: CGFloat = 16
    private let cardWidth: CGFloat = 808  // 840 - 2*16
    private let rowH: CGFloat = 32
    private let sectionGap: CGFloat = 16
    private let labelWidth: CGFloat = 160

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 660),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Claude Gamepad Settings"
        window.center()
        window.minSize = NSSize(width: 700, height: 500)
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let tabView = NSTabView(frame: contentView.bounds)
        tabView.autoresizingMask = [.width, .height]

        let tab1 = NSTabViewItem(identifier: "buttons")
        tab1.label = "Button Mapping"
        tab1.view = buildButtonMappingTab()
        tabView.addTabViewItem(tab1)

        let tab2 = NSTabViewItem(identifier: "prompts")
        tab2.label = "Preset Prompts"
        tab2.view = buildPromptsTab()
        tabView.addTabViewItem(tab2)

        let tab3 = NSTabViewItem(identifier: "speech")
        tab3.label = "Speech Recognition"
        tab3.view = buildSpeechTab()
        tabView.addTabViewItem(tab3)

        // Shrink tab view to leave room for bottom bar
        tabView.frame = NSRect(x: 0, y: 52, width: contentView.bounds.width, height: contentView.bounds.height - 52)
        contentView.addSubview(tabView)

        // Bottom bar with separator + buttons
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: 0, y: 48, width: contentView.bounds.width, height: 1)
        sep.autoresizingMask = [.width, .maxYMargin]
        contentView.addSubview(sep)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        saveButton.frame = NSRect(x: contentView.bounds.width - 110, y: 12, width: 86, height: 28)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.autoresizingMask = [.minXMargin, .maxYMargin]
        contentView.addSubview(saveButton)

        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetDefaults))
        resetButton.frame = NSRect(x: contentView.bounds.width - 270, y: 12, width: 145, height: 28)
        resetButton.bezelStyle = .rounded
        resetButton.autoresizingMask = [.minXMargin, .maxYMargin]
        contentView.addSubview(resetButton)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Tab 1: Button Mapping
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func buildButtonMappingTab() -> NSView {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 860, height: 560))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.autoresizingMask = [.width, .height]
        gamepadView = GamepadConfigView(mapping: mapping)
        scroll.documentView = gamepadView
        return scroll
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Tab 2: Preset Prompts
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func buildPromptsTab() -> NSView {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 860, height: 560))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.autoresizingMask = [.width, .height]

        let doc = FlippedView(frame: NSRect(x: 0, y: 0, width: 840, height: 900))
        scroll.documentView = doc

        var y: CGFloat = cardInset
        presetFields = []
        ltFields = [:]
        rtFields = [:]

        // ── Header ──
        y = addSectionHeader(to: doc, y: y,
                             icon: "text.bubble.fill",
                             title: "Preset Prompts",
                             subtitle: "Press Start to open menu, D-pad to cycle, A to send")

        // ── Preset list card ──
        let presetCardH = CGFloat(mapping.presetPrompts.count) * rowH + 20
        let presetCard = addCard(to: doc, y: y, height: presetCardH)
        var ry: CGFloat = 10
        for (i, prompt) in mapping.presetPrompts.enumerated() {
            let num = makeLabel("\(i + 1)")
            num.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            num.textColor = .tertiaryLabelColor
            num.alignment = .right
            num.frame = NSRect(x: 12, y: ry + 5, width: 24, height: 18)
            presetCard.addSubview(num)

            let field = NSTextField(string: prompt)
            field.frame = NSRect(x: 44, y: ry + 3, width: cardWidth - 60, height: 24)
            field.font = NSFont.systemFont(ofSize: 13)
            field.bezelStyle = .roundedBezel
            presetCard.addSubview(field)
            presetFields.append(field)
            ry += rowH
        }
        y += presetCardH + sectionGap

        // ── LT Quick Prompts ──
        y = addSectionHeader(to: doc, y: y,
                             icon: "l2.button.roundedtop.horizontal.fill",
                             title: "LT / L2 + Button",
                             subtitle: "Hold left trigger + face button for quick prompts")

        let ltItems: [(String, String, String)] = [
            ("A / ✕", "a", mapping.ltPrompts.a),
            ("B / ○", "b", mapping.ltPrompts.b),
            ("X / □", "x", mapping.ltPrompts.x),
            ("Y / △", "y", mapping.ltPrompts.y),
        ]
        let ltCardH = CGFloat(ltItems.count) * rowH + 20
        let ltCard = addCard(to: doc, y: y, height: ltCardH)
        ry = 10
        for (label, key, value) in ltItems {
            addFormRow(to: ltCard, y: ry, label: label, value: value, fieldWidth: cardWidth - labelWidth - 32, storeIn: &ltFields, key: key)
            ry += rowH
        }
        y += ltCardH + sectionGap

        // ── RT Quick Prompts ──
        y = addSectionHeader(to: doc, y: y,
                             icon: "r2.button.roundedtop.horizontal.fill",
                             title: "RT / R2 + Button",
                             subtitle: "Hold right trigger + face button for quick prompts")

        let rtItems: [(String, String, String)] = [
            ("A / ✕", "a", mapping.rtPrompts.a),
            ("B / ○", "b", mapping.rtPrompts.b),
            ("X / □", "x", mapping.rtPrompts.x),
            ("Y / △", "y", mapping.rtPrompts.y),
        ]
        let rtCardH = CGFloat(rtItems.count) * rowH + 20
        let rtCard = addCard(to: doc, y: y, height: rtCardH)
        ry = 10
        for (label, key, value) in rtItems {
            addFormRow(to: rtCard, y: ry, label: label, value: value, fieldWidth: cardWidth - labelWidth - 32, storeIn: &rtFields, key: key)
            ry += rowH
        }
        y += rtCardH + sectionGap + 16

        doc.frame = NSRect(x: 0, y: 0, width: 840, height: y)
        return scroll
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Tab 3: Speech Recognition
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func buildSpeechTab() -> NSView {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 860, height: 560))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.autoresizingMask = [.width, .height]

        let doc = FlippedView(frame: NSRect(x: 0, y: 0, width: 840, height: 700))
        scroll.documentView = doc

        var y: CGFloat = cardInset

        // ── Engine Selection ──
        y = addSectionHeader(to: doc, y: y,
                             icon: "mic.fill",
                             title: "Speech Engine",
                             subtitle: "Choose how voice input is processed")

        let engineCardH: CGFloat = rowH + 20
        let engineCard = addCard(to: doc, y: y, height: engineCardH)
        let eLabel = makeLabel("Engine")
        eLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        eLabel.frame = NSRect(x: 16, y: 14, width: labelWidth, height: 18)
        engineCard.addSubview(eLabel)
        enginePopup = NSPopUpButton(frame: NSRect(x: labelWidth + 16, y: 10, width: cardWidth - labelWidth - 32, height: 26), pullsDown: false)
        enginePopup.font = NSFont.systemFont(ofSize: 12)
        for t in SpeechEngineType.allCases { enginePopup.addItem(withTitle: t.rawValue) }
        enginePopup.selectItem(withTitle: speechSettings.engineType.rawValue)
        engineCard.addSubview(enginePopup)
        y += engineCardH + sectionGap

        // ── Whisper Settings ──
        y = addSectionHeader(to: doc, y: y,
                             icon: "waveform",
                             title: "Whisper (Local)",
                             subtitle: "Local speech recognition via whisper.cpp")

        let whisperCardH: CGFloat = rowH * 4 + 28
        let whisperCard = addCard(to: doc, y: y, height: whisperCardH)
        var wy: CGFloat = 10

        // Model selector
        let mLabel = makeLabel("Model")
        mLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        mLabel.frame = NSRect(x: 16, y: wy + 4, width: labelWidth, height: 18)
        whisperCard.addSubview(mLabel)
        whisperModelPopup = NSPopUpButton(frame: NSRect(x: labelWidth + 16, y: wy, width: 360, height: 26), pullsDown: false)
        whisperModelPopup.font = NSFont.systemFont(ofSize: 11)
        whisperModelPopup.target = self
        whisperModelPopup.action = #selector(modelSelectionChanged)
        let models: [(String, String)] = [
            ("ggml-tiny.bin",      "75 MB  ·  Fastest"),
            ("ggml-base.bin",      "142 MB  ·  Fast, good quality"),
            ("ggml-small.bin",     "466 MB  ·  Balanced"),
            ("ggml-medium.bin",    "1.5 GB  ·  High quality"),
            ("ggml-large-v3.bin",  "3.1 GB  ·  Best quality"),
        ]
        for (file, desc) in models {
            whisperModelPopup.addItem(withTitle: "\(file)  (\(desc))")
            whisperModelPopup.lastItem?.representedObject = file
        }
        if let idx = models.firstIndex(where: { $0.0 == speechSettings.whisperModel }) {
            whisperModelPopup.selectItem(at: idx)
        }
        whisperCard.addSubview(whisperModelPopup)
        wy += rowH + 4

        // Install button
        let installLabel = makeLabel("Binary")
        installLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        installLabel.frame = NSRect(x: 16, y: wy + 4, width: labelWidth, height: 18)
        whisperCard.addSubview(installLabel)
        whisperInstallButton = NSButton(title: "Install whisper-cpp", target: self, action: #selector(installWhisperCpp))
        whisperInstallButton.frame = NSRect(x: labelWidth + 16, y: wy, width: 180, height: 26)
        whisperInstallButton.bezelStyle = .rounded
        whisperInstallButton.controlSize = .small
        whisperCard.addSubview(whisperInstallButton)
        wy += rowH

        // Download button + progress
        let dlLabel = makeLabel("Model File")
        dlLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        dlLabel.frame = NSRect(x: 16, y: wy + 4, width: labelWidth, height: 18)
        whisperCard.addSubview(dlLabel)
        whisperDownloadButton = NSButton(title: "Download", target: self, action: #selector(downloadWhisperModel))
        whisperDownloadButton.frame = NSRect(x: labelWidth + 16, y: wy, width: 100, height: 26)
        whisperDownloadButton.bezelStyle = .rounded
        whisperDownloadButton.controlSize = .small
        whisperCard.addSubview(whisperDownloadButton)
        whisperProgressBar = NSProgressIndicator(frame: NSRect(x: labelWidth + 126, y: wy + 5, width: 280, height: 16))
        whisperProgressBar.style = .bar
        whisperProgressBar.minValue = 0
        whisperProgressBar.maxValue = 1
        whisperProgressBar.isHidden = true
        whisperCard.addSubview(whisperProgressBar)
        wy += rowH

        // Status
        whisperStatusLabel = makeLabel("")
        whisperStatusLabel.font = NSFont.systemFont(ofSize: 11)
        whisperStatusLabel.textColor = .secondaryLabelColor
        whisperStatusLabel.frame = NSRect(x: 16, y: wy + 2, width: cardWidth - 32, height: 16)
        whisperCard.addSubview(whisperStatusLabel)

        y += whisperCardH + sectionGap
        updateWhisperStatus()

        // ── LLM Refinement ──
        y = addSectionHeader(to: doc, y: y,
                             icon: "sparkles",
                             title: "LLM Refinement",
                             subtitle: "Post-process speech with an LLM to fix recognition errors")

        let llmCardH: CGFloat = rowH * 4 + 20
        let llmCard = addCard(to: doc, y: y, height: llmCardH)
        var ly: CGFloat = 10

        // Enable checkbox
        let enLabel = makeLabel("Enabled")
        enLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        enLabel.frame = NSRect(x: 16, y: ly + 5, width: labelWidth, height: 18)
        llmCard.addSubview(enLabel)
        llmCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        llmCheckbox.frame = NSRect(x: labelWidth + 16, y: ly + 3, width: 22, height: 22)
        llmCheckbox.state = speechSettings.llmEnabled ? .on : .off
        llmCard.addSubview(llmCheckbox)
        ly += rowH

        // API URL
        addFormRowFixed(to: llmCard, y: ly, label: "API URL")
        llmURLField = NSTextField(string: speechSettings.llmAPIURL)
        llmURLField.frame = NSRect(x: labelWidth + 16, y: ly + 3, width: cardWidth - labelWidth - 32, height: 24)
        llmURLField.font = NSFont.systemFont(ofSize: 12)
        llmURLField.bezelStyle = .roundedBezel
        llmURLField.placeholderString = "http://localhost:11434/v1"
        llmCard.addSubview(llmURLField)
        ly += rowH

        // API Key
        addFormRowFixed(to: llmCard, y: ly, label: "API Key")
        llmKeyField = NSSecureTextField(string: speechSettings.llmAPIKey)
        llmKeyField.frame = NSRect(x: labelWidth + 16, y: ly + 3, width: cardWidth - labelWidth - 32, height: 24)
        llmKeyField.font = NSFont.systemFont(ofSize: 12)
        llmKeyField.bezelStyle = .roundedBezel
        llmKeyField.placeholderString = "Leave empty for Ollama"
        llmCard.addSubview(llmKeyField)
        ly += rowH

        // Model
        addFormRowFixed(to: llmCard, y: ly, label: "Model")
        llmModelField = NSTextField(string: speechSettings.llmModel)
        llmModelField.frame = NSRect(x: labelWidth + 16, y: ly + 3, width: 200, height: 24)
        llmModelField.font = NSFont.systemFont(ofSize: 12)
        llmModelField.bezelStyle = .roundedBezel
        llmModelField.placeholderString = "qwen2.5:7b"
        llmCard.addSubview(llmModelField)
        let llmHint = makeLabel("Ollama / LM Studio / OpenAI compatible")
        llmHint.font = NSFont.systemFont(ofSize: 10)
        llmHint.textColor = .tertiaryLabelColor
        llmHint.frame = NSRect(x: labelWidth + 224, y: ly + 6, width: 280, height: 14)
        llmCard.addSubview(llmHint)

        y += llmCardH + sectionGap + 16
        doc.frame = NSRect(x: 0, y: 0, width: 840, height: y)
        return scroll
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Reusable UI Builders
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Section header with SF Symbol icon + title + subtitle. Returns new y after header.
    private func addSectionHeader(to view: NSView, y: CGFloat, icon: String, title: String, subtitle: String) -> CGFloat {
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let iv = NSImageView(image: img.withSymbolConfiguration(config) ?? img)
            iv.contentTintColor = .secondaryLabelColor
            iv.frame = NSRect(x: cardInset, y: y + 2, width: 18, height: 18)
            view.addSubview(iv)
        }
        let t = makeLabel(title)
        t.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        t.frame = NSRect(x: cardInset + 24, y: y, width: 300, height: 18)
        view.addSubview(t)

        let s = makeLabel(subtitle)
        s.font = NSFont.systemFont(ofSize: 11)
        s.textColor = .tertiaryLabelColor
        s.frame = NSRect(x: cardInset + 24, y: y + 20, width: 500, height: 14)
        view.addSubview(s)

        return y + 42
    }

    /// Add a rounded card (flipped NSView) and return it.
    private func addCard(to parent: NSView, y: CGFloat, height: CGFloat) -> FlippedView {
        let card = FlippedView(frame: NSRect(x: cardInset, y: y, width: cardWidth, height: height))
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = 8
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        card.layer?.borderWidth = 0.5
        parent.addSubview(card)
        return card
    }

    /// Add a form row: label + text field, storing field reference.
    private func addFormRow(to card: NSView, y: CGFloat, label: String, value: String,
                            fieldWidth: CGFloat, storeIn fields: inout [String: NSTextField], key: String) {
        let lbl = makeLabel(label)
        lbl.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        lbl.frame = NSRect(x: 16, y: y + 5, width: labelWidth, height: 18)
        card.addSubview(lbl)

        let field = NSTextField(string: value)
        field.frame = NSRect(x: labelWidth + 16, y: y + 3, width: fieldWidth, height: 24)
        field.font = NSFont.systemFont(ofSize: 12)
        field.bezelStyle = .roundedBezel
        card.addSubview(field)
        fields[key] = field
    }

    /// Add just a label (no field storage).
    private func addFormRowFixed(to card: NSView, y: CGFloat, label: String) {
        let lbl = makeLabel(label)
        lbl.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        lbl.frame = NSRect(x: 16, y: y + 5, width: labelWidth, height: 18)
        card.addSubview(lbl)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Actions
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var selectedModelName: String {
        whisperModelPopup.selectedItem?.representedObject as? String ?? "ggml-base.bin"
    }

    @objc private func modelSelectionChanged() { updateWhisperStatus() }

    private func updateWhisperStatus() {
        let w = WhisperEngine.shared
        w.modelName = selectedModelName
        var parts: [String] = []
        if w.hasBinary {
            parts.append("whisper-cpp installed")
            whisperInstallButton.isEnabled = false
            whisperInstallButton.title = "Installed"
        } else {
            parts.append("whisper-cpp not found")
            whisperInstallButton.isEnabled = true
            whisperInstallButton.title = "Install (brew)"
        }
        if w.hasModel {
            parts.append("model ready")
            whisperDownloadButton.isEnabled = false
            whisperDownloadButton.title = "Ready"
        } else {
            parts.append("model not downloaded")
            whisperDownloadButton.isEnabled = true
            whisperDownloadButton.title = "Download"
        }
        let allGood = w.hasBinary && w.hasModel
        whisperStatusLabel.stringValue = (allGood ? "✓ " : "⚠ ") + parts.joined(separator: "  ·  ")
        whisperStatusLabel.textColor = allGood ? .systemGreen : .secondaryLabelColor
    }

    @objc private func installWhisperCpp() {
        whisperInstallButton.isEnabled = false
        whisperInstallButton.title = "Installing..."
        whisperStatusLabel.stringValue = "Installing via Homebrew..."
        whisperStatusLabel.textColor = .secondaryLabelColor
        WhisperEngine.shared.installBinary { [weak self] ok, msg in
            self?.whisperStatusLabel.stringValue = ok ? "✓ \(msg)" : "✗ \(msg)"
            self?.whisperStatusLabel.textColor = ok ? .systemGreen : .systemRed
            self?.updateWhisperStatus()
        }
    }

    @objc private func downloadWhisperModel() {
        let w = WhisperEngine.shared
        w.modelName = selectedModelName
        whisperDownloadButton.isEnabled = false
        whisperDownloadButton.title = "..."
        whisperProgressBar.isHidden = false
        whisperProgressBar.doubleValue = 0
        w.downloadModel(
            onProgress: { [weak self] p in
                self?.whisperProgressBar.doubleValue = p
                self?.whisperStatusLabel.stringValue = "Downloading... \(Int(p * 100))%"
            },
            onComplete: { [weak self] ok, msg in
                self?.whisperProgressBar.isHidden = true
                self?.whisperStatusLabel.stringValue = ok ? "✓ \(msg)" : "✗ \(msg)"
                self?.whisperStatusLabel.textColor = ok ? .systemGreen : .systemRed
                self?.updateWhisperStatus()
            }
        )
    }

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
        mapping.presetPrompts = presetFields.map { $0.stringValue }
        mapping.ltPrompts = ButtonMapping.QuickPrompts(
            a: ltFields["a"]!.stringValue, b: ltFields["b"]!.stringValue,
            x: ltFields["x"]!.stringValue, y: ltFields["y"]!.stringValue
        )
        mapping.rtPrompts = ButtonMapping.QuickPrompts(
            a: rtFields["a"]!.stringValue, b: rtFields["b"]!.stringValue,
            x: rtFields["x"]!.stringValue, y: rtFields["y"]!.stringValue
        )
        mapping.save()

        if let title = enginePopup.titleOfSelectedItem,
           let engine = SpeechEngineType.allCases.first(where: { $0.rawValue == title }) {
            speechSettings.engineType = engine
        }
        speechSettings.whisperModel = selectedModelName
        speechSettings.llmEnabled = llmCheckbox.state == .on
        speechSettings.llmAPIURL = llmURLField.stringValue
        speechSettings.llmAPIKey = llmKeyField.stringValue
        speechSettings.llmModel = llmModelField.stringValue
        speechSettings.save()

        GamepadManager.shared.reloadMapping()
        GamepadManager.shared.reloadSpeechSettings()
        window?.close()
    }

    @objc private func resetDefaults() {
        mapping = .default
        speechSettings = .default
        guard let contentView = window?.contentView else { return }
        contentView.subviews.forEach { $0.removeFromSuperview() }
        presetFields.removeAll()
        ltFields.removeAll()
        rtFields.removeAll()
        setupUI()
    }

    private func makeLabel(_ text: String, fontSize: CGFloat = 13, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        return label
    }
}

// MARK: - Flipped View (top-left origin)

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
